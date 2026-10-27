import Foundation
import CoreGraphics
import SwingLabCore
import Observation
@preconcurrency import AVFoundation

struct CameraFormatChoice: Identifiable, Hashable, Sendable {
    var id: String
    var width: Int32
    var height: Int32
    var fps: Int
    var label: String { "\(width) × \(height) · \(fps) fps" }
}

enum CameraEvent: Sendable {
    case ready([CameraFormatChoice], String, Bool)
    case recording(Bool)
    case saved(URL)
    case failure(LocalizationKey)
    case interrupted(Bool)
    case audio(Bool)
    case launchMode(LaunchModeState)
    case liveLaunch(LiveLaunchAvailability)
}

/// Whether the real-time launch readout is streaming frames and sound.
enum LiveLaunchAvailability: Sendable, Equatable {
    case off
    /// Needs launch mode, the rear camera, sound, and a session that can stream while recording.
    case unsupported
    case on
}

/// Launch mode (`Docs/Specs/LaunchMonitor.md`): ≥ 200 fps and a fixed short shutter.
enum LaunchModeState: Sendable, Equatable {
    case off
    case unsupported
    /// Active, but even the maximum ISO cannot keep the image bright at 1/2000 s.
    case tooDark(shutter: Double, fps: Int)
    case active(shutter: Double, fps: Int)
}

/// All session, device, and movie-output mutations are serialized on `queue`.
/// The unchecked boundary is necessary for AVFoundation's delegate-based capture API.
final class CameraEngine: NSObject, @unchecked Sendable, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    var onEvent: (@Sendable (CameraEvent) -> Void)?
    private let queue = DispatchQueue(label: "com.swinglab.camera", qos: .userInitiated)
    private let movieOutput = AVCaptureMovieFileOutput()
    private var input: AVCaptureDeviceInput?
    /// Added only when microphone access is granted; the movie output then records an AAC track.
    private var audioInput: AVCaptureDeviceInput?
    private var formats: [CameraFormatChoice] = []
    private var selectedID = ""
    private var observers: [NSObjectProtocol] = []
    private var wantsRunning = false
    private var launchModeEnabled = false
    private var launchFrameRate = 240
    /// Frame and sound streams for the real-time launch readout.
    let live = LiveLaunchCapture()

    override init() {
        super.init()
        observers.append(NotificationCenter.default.addObserver(forName: .AVCaptureSessionWasInterrupted,
                                                                 object: session, queue: nil) { [weak self] _ in
            self?.onEvent?(.interrupted(true))
        })
        observers.append(NotificationCenter.default.addObserver(forName: .AVCaptureSessionInterruptionEnded,
                                                                 object: session, queue: nil) { [weak self] _ in
            self?.onEvent?(.interrupted(false))
            self?.resume()
        })
        observers.append(NotificationCenter.default.addObserver(forName: .AVCaptureSessionRuntimeError,
                                                                 object: session, queue: nil) { [weak self] _ in
            self?.onEvent?(.failure("The camera stopped. Close the camera and try again."))
        })
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func configure(front: Bool = false) {
        queue.async { [self] in
            guard !movieOutput.isRecording else { return }
            wantsRunning = true
            do {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video,
                                                          position: front ? .front : .back) else {
                    onEvent?(.failure("This camera is not available on this device.")); return
                }
                let newInput = try AVCaptureDeviceInput(device: device)
                session.beginConfiguration()
                removeLiveOutputs()
                if let input { session.removeInput(input) }
                guard session.canAddInput(newInput) else {
                    if let input, session.canAddInput(input) { session.addInput(input) }
                    session.commitConfiguration()
                    onEvent?(.failure("This camera configuration is not supported.")); return
                }
                session.addInput(newInput)
                input = newInput
                if !session.outputs.contains(movieOutput), session.canAddOutput(movieOutput) {
                    session.addOutput(movieOutput)
                }
                // Impact sound is optional evidence. Without microphone access, capture stays video-only.
                if audioInput == nil, AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
                   let microphone = AVCaptureDevice.default(for: .audio),
                   let microphoneInput = try? AVCaptureDeviceInput(device: microphone), session.canAddInput(microphoneInput) {
                    session.addInput(microphoneInput)
                    audioInput = microphoneInput
                }
                session.sessionPreset = .inputPriority
                session.commitConfiguration()
                onEvent?(.audio(audioInput != nil))
                formats = Self.availableFormats(device)
                let preferred = formats.first { $0.width == 1920 && $0.fps == 60 }
                    ?? formats.first { $0.width == 1920 && $0.fps == 30 } ?? formats.first
                if let preferred { try applyFormat(preferred.id) }
                if !session.isRunning { session.startRunning() }
                onEvent?(.ready(formats, selectedID, front))
            } catch { onEvent?(.failure("The camera could not be configured. Please try again.")) }
        }
    }

    private static func availableFormats(_ device: AVCaptureDevice) -> [CameraFormatChoice] {
        var choices: [CameraFormatChoice] = []
        var seen = Set<String>()
        for (index, format) in device.formats.enumerated() {
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            // Keep practical movie sizes; expose only frame rates reported by the hardware.
            guard size.width >= 640, size.width <= 3840 else { continue }
            for fps in [30, 60, 120, 240] where format.videoSupportedFrameRateRanges.contains(where: {
                $0.minFrameRate <= Double(fps) && $0.maxFrameRate >= Double(fps)
            }) {
                let key = "\(size.width)x\(size.height):\(fps)"
                if seen.insert(key).inserted {
                    choices.append(CameraFormatChoice(id: "\(index):\(fps)", width: size.width, height: size.height, fps: fps))
                }
            }
        }
        return choices.sorted { ($0.width, $0.height, $0.fps) < ($1.width, $1.height, $1.fps) }
    }

    func selectFormat(_ id: String) {
        queue.async { [self] in
            guard !movieOutput.isRecording else { return }
            do {
                try applyFormat(id)
                onEvent?(.ready(formats, selectedID, input?.device.position == .front))
            } catch { onEvent?(.failure("This frame rate could not be enabled.")) }
        }
    }

    private func applyFormat(_ id: String) throws {
        guard let device = input?.device, let choice = formats.first(where: { $0.id == id }),
              let index = Int(id.split(separator: ":")[0]), device.formats.indices.contains(index) else { return }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        device.activeFormat = device.formats[index]
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(choice.fps))
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Int32(choice.fps))
        selectedID = id
    }

    func focus(at point: CGPoint) {
        queue.async { [self] in
            guard let device = input?.device else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                // Launch mode keeps its fixed shutter; a focus tap must not return exposure to auto.
                if !launchModeEnabled, device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .continuousAutoExposure
                }
            } catch { onEvent?(.failure("Focus could not be adjusted.")) }
        }
    }

    /// Selects the fastest supported format (≥ 200 fps) and a custom 1/2000 s shutter, raising ISO by
    /// the shutter reduction within the format's range. Turning it off restores automatic exposure.
    func setLaunchMode(_ enabled: Bool) {
        queue.async { [self] in
            guard let device = input?.device, !movieOutput.isRecording else { return }
            do {
                guard enabled else {
                    launchModeEnabled = false
                    session.beginConfiguration()
                    removeLiveOutputs()
                    session.commitConfiguration()
                    try device.lockForConfiguration()
                    defer { device.unlockForConfiguration() }
                    if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
                    onEvent?(.launchMode(.off))
                    return
                }
                guard device.isExposureModeSupported(.custom),
                      let fast = formats.filter({ $0.fps >= 200 }).max(by: { ($0.fps, $0.width) < ($1.fps, $1.width) }) else {
                    onEvent?(.launchMode(.unsupported)); return
                }
                let previousDuration = device.exposureDuration.seconds, previousISO = device.iso
                try applyFormat(fast.id)
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                let format = device.activeFormat
                let duration = CMTimeMaximum(format.minExposureDuration,
                                             CMTimeMinimum(CMTime(value: 1, timescale: 2000), format.maxExposureDuration))
                let wanted = previousISO * Float(max(1, previousDuration / duration.seconds))
                device.setExposureModeCustom(duration: duration, iso: min(format.maxISO, max(format.minISO, wanted)),
                                             completionHandler: nil)
                launchModeEnabled = true
                launchFrameRate = fast.fps
                onEvent?(.ready(formats, selectedID, device.position == .front))
                onEvent?(.launchMode(wanted > format.maxISO ? .tooDark(shutter: duration.seconds, fps: fast.fps)
                                                           : .active(shutter: duration.seconds, fps: fast.fps)))
            } catch { onEvent?(.failure("Launch mode could not be set.")) }
        }
    }

    /// Adds the frame and sound streams that feed `LiveLaunchCapture`. Launch mode must be active.
    func setLiveLaunch(_ enabled: Bool) {
        queue.async { [self] in
            guard enabled else {
                session.beginConfiguration()
                removeLiveOutputs()
                session.commitConfiguration()
                return
            }
            guard launchModeEnabled, input?.device.position == .back, audioInput != nil else {
                onEvent?(.liveLaunch(.unsupported)); return
            }
            session.beginConfiguration()
            for output in [live.videoOutput, live.audioOutput] as [AVCaptureOutput]
            where !session.outputs.contains(output) && session.canAddOutput(output) {
                session.addOutput(output)
            }
            let streaming = session.outputs.contains(live.videoOutput) && session.outputs.contains(live.audioOutput)
            if streaming, let connection = live.videoOutput.connection(with: .video) {
                // Sensor orientation, unmirrored: the clockwise turn happens only on the few analysed crops.
                if connection.isVideoRotationAngleSupported(0) { connection.videoRotationAngle = 0 }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = false
                }
                if connection.isVideoStabilizationSupported { connection.preferredVideoStabilizationMode = .off }
            }
            if !streaming { removeLiveOutputs() }
            session.commitConfiguration()
            guard streaming else { onEvent?(.liveLaunch(.unsupported)); return }
            live.start(frameRate: Double(launchFrameRate))
            onEvent?(.liveLaunch(.on))
        }
    }

    /// Call between `beginConfiguration` and `commitConfiguration`.
    private func removeLiveOutputs() {
        let streaming = session.outputs.contains(live.videoOutput) || session.outputs.contains(live.audioOutput)
        for output in [live.videoOutput, live.audioOutput] as [AVCaptureOutput] where session.outputs.contains(output) {
            session.removeOutput(output)
        }
        live.stop()
        if streaming { onEvent?(.liveLaunch(.off)) }
    }

    func exposure(bias: Float) {
        queue.async { [self] in
            guard let device = input?.device else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.setExposureTargetBias(min(device.maxExposureTargetBias, max(device.minExposureTargetBias, bias)))
            } catch { onEvent?(.failure("Exposure could not be adjusted.")) }
        }
    }

    func startRecording() {
        queue.async { [self] in
            guard session.isRunning, !movieOutput.isRecording else { return }
            do {
                let url = try VideoLibrary.newURL()
                let resources = try url.deletingLastPathComponent().resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                if let capacity = resources.volumeAvailableCapacityForImportantUsage, capacity < 150_000_000 {
                    throw VideoLibraryError.insufficientStorage
                }
                if let connection = movieOutput.connection(with: .video) {
                    if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = false
                    }
                    if connection.isVideoStabilizationSupported { connection.preferredVideoStabilizationMode = .off }
                }
                movieOutput.maxRecordedDuration = CMTime(seconds: 60, preferredTimescale: 600)
                movieOutput.minFreeDiskSpaceLimit = 100_000_000
                movieOutput.startRecording(to: url, recordingDelegate: self)
            } catch { onEvent?(.failure("Not enough storage, or the video could not be created.")) }
        }
    }

    func stopRecording() { queue.async { [self] in if movieOutput.isRecording { movieOutput.stopRecording() } } }
    func stop() {
        queue.async { [self] in
            wantsRunning = false
            if movieOutput.isRecording { movieOutput.stopRecording() }
            if session.isRunning { session.stopRunning() }
        }
    }
    private func resume() { queue.async { [self] in if wantsRunning && !session.isRunning { session.startRunning() } } }

    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) { onEvent?(.recording(true)) }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        onEvent?(.recording(false))
        if let error = error as NSError?, !(error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false) {
            try? FileManager.default.removeItem(at: outputFileURL)
            onEvent?(.failure("Recording could not be saved. Check available storage and try again."))
        } else { onEvent?(.saved(outputFileURL)) }
    }
}

@Observable @MainActor
final class CameraController {
    let engine: CameraEngine
    var authorized = false
    var denied = false
    var ready = false
    var front = false
    var interrupted = false
    var isRecording = false
    var recordedAt: Date?
    var formats: [CameraFormatChoice] = []
    var selectedFormat = ""
    var savedURL: URL?
    var error: LocalizationKey?
    var recordsAudio = false
    var launchMode = LaunchModeState.off
    var live = LiveLaunchAvailability.off
    var liveListening = false
    var liveMeasuring = false
    var liveOutcome: LaunchPipeline.Outcome?
    var liveMessage: LocalizationKey?
    var liveSnapshot: CGImage?
    private var wantsCamera = false
    init() {
        engine = CameraEngine()
        engine.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in self?.receive(event) }
        }
        engine.live.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in self?.receive(event) }
        }
    }
    func start() async {
        wantsCamera = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authorized = true
        case .notDetermined: authorized = await AVCaptureDevice.requestAccess(for: .video)
        default: authorized = false
        }
        denied = !authorized
        // Asked once, after camera access. Declining keeps recording available without sound.
        if authorized, AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        if authorized && wantsCamera && !Task.isCancelled { engine.configure(front: front) }
    }
    func stop() { wantsCamera = false; ready = false; engine.stop() }
    func switchCamera() { ready = false; engine.configure(front: !front) }
    private func receive(_ event: CameraEvent) {
        switch event {
        case let .ready(formats, selected, front):
            self.formats = formats; selectedFormat = selected; self.front = front; ready = true; error = nil
        case let .recording(value): isRecording = value; recordedAt = value ? .now : nil
        case let .saved(url): savedURL = url
        case let .failure(message): error = message
        case let .interrupted(value): interrupted = value
        case let .audio(value): recordsAudio = value
        case let .launchMode(state): launchMode = state
        case let .liveLaunch(state):
            // Turning the stream on or off always starts over from "set the ball position".
            live = state
            liveListening = false; liveMeasuring = false; liveOutcome = nil; liveMessage = nil
        }
    }

    private func receive(_ event: LiveLaunchEvent) {
        switch event {
        case let .snapshot(image): liveSnapshot = image
        case .listening: liveListening = true; liveMessage = nil
        case .impact: liveMeasuring = true; liveMessage = nil
        case let .measured(outcome): liveMeasuring = false; liveOutcome = outcome
        case let .failure(key): liveMeasuring = false; liveMessage = key
        case let .reset(key): liveMeasuring = false; liveListening = false; liveMessage = key
        }
    }
}
