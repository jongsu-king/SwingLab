import Foundation
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
    case failure(String)
    case interrupted(Bool)
}

/// All session, device, and movie-output mutations are serialized on `queue`.
/// The unchecked boundary is necessary for AVFoundation's delegate-based capture API.
final class CameraEngine: NSObject, @unchecked Sendable, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    var onEvent: (@Sendable (CameraEvent) -> Void)?
    private let queue = DispatchQueue(label: "com.swinglab.camera", qos: .userInitiated)
    private let movieOutput = AVCaptureMovieFileOutput()
    private var input: AVCaptureDeviceInput?
    private var formats: [CameraFormatChoice] = []
    private var selectedID = ""
    private var observers: [NSObjectProtocol] = []
    private var wantsRunning = false

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
                session.sessionPreset = .inputPriority
                session.commitConfiguration()
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
                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .continuousAutoExposure
                }
            } catch { onEvent?(.failure("Focus could not be adjusted.")) }
        }
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
    var error: String?
    private var wantsCamera = false
    init() {
        engine = CameraEngine()
        engine.onEvent = { [weak self] event in
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
        }
    }
}
