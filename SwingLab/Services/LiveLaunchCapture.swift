import Foundation
import CoreGraphics
import SwingLabCore
@preconcurrency import AVFoundation

enum LiveLaunchEvent: Sendable {
    /// Upright still of the current view, for tapping the ball.
    case snapshot(CGImage)
    case listening
    case impact
    case measured(LaunchPipeline.Outcome)
    /// The shot was not measured; the readout keeps listening.
    case failure(LocalizationKey)
    /// The ball position is no longer valid and must be set again.
    case reset(LocalizationKey)
}

/// Real-time launch readout (`Docs/Specs/LaunchMonitor.md`). Luma crops around the ball and the
/// microphone stream feed `LiveLaunchSession`; when it hands back the frames around a strike, the
/// shared `LaunchPipeline` measures them off the capture queue. Back camera only: buffers arrive in
/// the sensor orientation and are turned upright with a clockwise quarter turn.
/// All state is confined to `queue`, which both data outputs deliver on.
final class LiveLaunchCapture: NSObject, @unchecked Sendable, AVCaptureVideoDataOutputSampleBufferDelegate,
                               AVCaptureAudioDataOutputSampleBufferDelegate {
    let videoOutput = AVCaptureVideoDataOutput()
    let audioOutput = AVCaptureAudioDataOutput()
    let queue = DispatchQueue(label: "com.swinglab.launch.live", qos: .userInitiated)
    var onEvent: (@Sendable (LiveLaunchEvent) -> Void)?

    private struct Aim: Sendable {
        let sourceRect: PixelRect
        let ball: PixelPoint
        let searchRadius: Int
        let direction: Double
    }

    private static let rotation = LumaRotation.clockwise
    private var frameRate = 240.0
    private var sampleRate: Double?
    private var sensorSize: (width: Int, height: Int)?
    private var wantsSnapshot = false
    private var pendingAim: (point: CGPoint, direction: Double)?
    private var aim: Aim?
    private var session: LiveLaunchSession?

    override init() {
        super.init()
        let formats = videoOutput.availableVideoPixelFormatTypes
        let format = formats.contains(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: format]
        // A late frame is dropped rather than queued; the tracker uses each frame's own timestamp.
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        audioOutput.setSampleBufferDelegate(self, queue: queue)
    }

    func start(frameRate: Double) {
        queue.async { [self] in
            self.frameRate = frameRate
            aim = nil; session = nil; pendingAim = nil
        }
    }

    func stop() { queue.async { [self] in aim = nil; session = nil; pendingAim = nil; wantsSnapshot = false } }

    func requestSnapshot() { queue.async { [self] in wantsSnapshot = true } }

    /// `point` is normalized in the upright snapshot, origin top-left; `direction` +1 flies right.
    func setBall(at point: CGPoint, direction: Double) {
        queue.async { [self] in
            pendingAim = (point, direction)
            armIfReady()
        }
    }

    private func armIfReady() {
        guard let request = pendingAim, let sensorSize, let sampleRate else { return }
        let upright = Self.rotation.rotatedSize(width: sensorSize.width, height: sensorSize.height)
        let ball = PixelPoint(x: request.point.x * Double(upright.width), y: request.point.y * Double(upright.height))
        pendingAim = nil
        guard let region = LaunchRegion.around(ball: ball, frameWidth: upright.width, frameHeight: upright.height,
                                               targetDirection: request.direction) else {
            onEvent?(.reset("The ball was not found at the point you tapped. Tap the centre of the ball at address.")); return
        }
        aim = Aim(sourceRect: Self.rotation.sourceRect(for: region, sourceWidth: sensorSize.width, sourceHeight: sensorSize.height),
                  ball: PixelPoint(x: ball.x - Double(region.x), y: ball.y - Double(region.y)),
                  searchRadius: LaunchRegion.searchRadius(frameWidth: upright.width), direction: request.direction)
        session = LiveLaunchSession(frameRate: frameRate, sampleRate: sampleRate)
        onEvent?(.listening)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output === videoOutput { video(sampleBuffer) } else { audio(sampleBuffer) }
    }

    private func video(_ sampleBuffer: CMSampleBuffer) {
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer), CVPixelBufferGetPlaneCount(pixels) > 0 else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixels, 0)?.assumingMemoryBound(to: UInt8.self) else { return }
        let width = CVPixelBufferGetWidthOfPlane(pixels, 0), height = CVPixelBufferGetHeightOfPlane(pixels, 0)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(pixels, 0)
        if sensorSize.map({ $0 != (width, height) }) ?? true {
            sensorSize = (width, height)
            if aim != nil { aim = nil; session = nil; onEvent?(.reset("The camera format changed. Set the ball position again.")) }
        }
        if wantsSnapshot {
            wantsSnapshot = false
            let full = Self.copy(base, stride: stride, rect: PixelRect(x: 0, y: 0, width: width, height: height))
            if let image = Self.image(LumaFrame(time: time, width: width, height: height, bytes: full).rotated(Self.rotation)) {
                onEvent?(.snapshot(image))
            }
        }
        armIfReady()
        guard let aim, session != nil else { return }
        let rect = aim.sourceRect
        guard rect.x >= 0, rect.y >= 0, rect.x + rect.width <= width, rect.y + rect.height <= height else { return }
        let frame = LumaFrame(time: time, width: rect.width, height: rect.height, bytes: Self.copy(base, stride: stride, rect: rect))
        handle(session?.appendVideo(frame) ?? [])
    }

    private func audio(_ sampleBuffer: CMSampleBuffer) {
        guard let description = CMSampleBufferGetFormatDescription(sampleBuffer),
              let stream = CMAudioFormatDescriptionGetStreamBasicDescription(description),
              let format = AVAudioFormat(streamDescription: stream) else { return }
        let count = CMSampleBufferGetNumSamples(sampleBuffer)
        guard count > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { return }
        buffer.frameLength = AVAudioFrameCount(count)
        guard CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, at: 0, frameCount: Int32(count),
                                                          into: buffer.mutableAudioBufferList) == noErr else { return }
        // First channel only; interleaved data is read with the buffer's stride.
        let samples: [Float]
        if let channels = buffer.floatChannelData {
            samples = (0..<count).map { channels[0][$0 * buffer.stride] }
        } else if let channels = buffer.int16ChannelData {
            samples = (0..<count).map { Float(channels[0][$0 * buffer.stride]) / 32_768 }
        } else { return }
        if sampleRate != format.sampleRate {
            sampleRate = format.sampleRate
            if aim != nil { session = LiveLaunchSession(frameRate: frameRate, sampleRate: format.sampleRate) }
        }
        armIfReady()
        handle(session?.appendAudio(samples, startTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds) ?? [])
    }

    private func handle(_ events: [LiveLaunchSession.Event]) {
        for event in events {
            switch event {
            case .impact: onEvent?(.impact)
            case .missedWindow:
                onEvent?(.failure("The strike was heard, but the frames around it were not all captured. Wait a moment after setting the ball, then hit."))
            case let .capture(capture):
                guard let aim else { continue }
                let onEvent = onEvent
                // Measuring takes tens of milliseconds; keep the capture queue free for the next frames.
                Task.detached(priority: .userInitiated) {
                    let rotation = Self.rotation
                    let result = LaunchPipeline.measure(address: capture.address.map { $0.gray(rotation) },
                                                        flight: capture.flight.map { (time: $0.time, image: $0.gray(rotation)) },
                                                        ball: aim.ball, searchRadius: aim.searchRadius, targetDirection: aim.direction)
                    switch result {
                    case let .success(outcome): onEvent?(.measured(outcome))
                    case let .failure(reason): onEvent?(.failure(LaunchVideoError(reason).key))
                    }
                }
            }
        }
    }

    private static func copy(_ base: UnsafePointer<UInt8>, stride: Int, rect: PixelRect) -> [UInt8] {
        [UInt8](unsafeUninitializedCapacity: rect.width * rect.height) { buffer, initialized in
            for row in 0..<rect.height {
                (buffer.baseAddress! + row * rect.width).update(from: base + (rect.y + row) * stride + rect.x, count: rect.width)
            }
            initialized = rect.width * rect.height
        }
    }

    private static func image(_ frame: LumaFrame) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(frame.bytes) as CFData) else { return nil }
        return CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: frame.width,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
