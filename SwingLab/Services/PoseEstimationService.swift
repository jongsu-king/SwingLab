import Foundation
import SwingLabCore
import ImageIO
// AVFoundation's SDK sendability annotations are incomplete for asset loading.
// The asset, tracks, reader, and sample buffers remain confined to this actor.
@preconcurrency import AVFoundation
import Vision

enum PoseAnalysisError: LocalizedError {
    case unreadable, noPose, interrupted
    var errorDescription: String? {
        switch self {
        case .unreadable: "This video could not be decoded for analysis."
        case .noPose: "No reliable body pose was found. Keep one golfer fully visible in good light."
        case .interrupted: "Analysis paused because the device is too warm. Let it cool and try again."
        }
    }
}

/// Offline analysis has no connection to the capture session. Only one decoded sample is retained at a time.
actor PoseEstimationService {
    func analyze(url: URL, handedness: Handedness = .right,
                 progress: @Sendable (Double) -> Void) async throws -> PoseAnalysisReport {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw PoseAnalysisError.unreadable }
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw PoseAnalysisError.unreadable }
        let nominalRate = Double(try await track.load(.nominalFrameRate))
        let transform = try await track.load(.preferredTransform)
        let orientation = try Self.imageOrientation(transform)
        let coarse = try readPoseFrames(asset: asset, track: track, orientation: orientation,
                                        range: 0...duration, maximumRate: 30) { progress($0 * 0.5) }
        guard let coarseInterval = PoseProcessing.sampleInterval(frames: coarse),
              coarse.filter({ !$0.joints.isEmpty }).count >= 5 else { throw PoseAnalysisError.noPose }
        let processedCoarse = PoseProcessing.process(frames: coarse, sampleInterval: coarseInterval)
        let coarseMarkers = SwingPhaseDetector.detect(frames: processedCoarse, handedness: handedness)
        var frames = processedCoarse
        var observedFrames = coarse
        var actualRate = 1 / coarseInterval
        var rateLimit = 30.0
        if let top = coarseMarkers.first(where: { $0.phase == .top }),
           let impact = coarseMarkers.first(where: { $0.phase == .impact }), impact.time > top.time {
            let window = max(0, top.time - 0.35)...min(duration, impact.time + 0.35)
            // Native source samples are retained up to 240 Hz. No video frames are cached.
            let dense = try readPoseFrames(asset: asset, track: track, orientation: orientation,
                                           range: window, maximumRate: nominalRate > 0 ? min(nominalRate, 240) : 240) {
                progress(0.5 + $0 * 0.45)
            }
            if let denseInterval = PoseProcessing.sampleInterval(frames: dense), dense.count >= 5 {
                let processedDense = PoseProcessing.process(frames: dense, sampleInterval: denseInterval)
                frames = (processedCoarse.filter { !window.contains($0.time) } + processedDense).sorted { $0.time < $1.time }
                observedFrames = (coarse.filter { !window.contains($0.time) } + dense).sorted { $0.time < $1.time }
                actualRate = 1 / denseInterval
                rateLimit = 240
            }
        }
        let detectedCount = observedFrames.filter { !$0.joints.isEmpty }.count
        var markers = SwingPhaseDetector.detect(frames: frames, handedness: handedness)
        let audioImpact = try await audioImpact(asset: asset, duration: duration, markers: markers)
        if let audioImpact { markers = ImpactOnsetDetector.apply(audioImpact, to: markers) }
        progress(1)
        return PoseAnalysisReport(frames: frames,
                                  markers: markers, analyzedAt: .now,
                                  sampledFrameCount: frames.count, poseFrameCount: detectedCount,
                                  sampleRateLimit: rateLimit, notes: [
                                    "Pose is vision-derived 2D image geometry, not a 3D body measurement.",
                                    "Phase markers are estimates. Review and correct them before using tempo.",
                                    "Use one golfer, a steady camera, and one swing per clip."
                                  ], analysisVersion: 2, poseFrameRate: actualRate, analyzedHandedness: handedness,
                                  audioImpact: audioImpact)
    }

    /// Searches for the impact sound from the top to 0.6 s after it. The read starts 0.2 s earlier
    /// so the noise floor includes sound before the transient. Nil when no top was estimated.
    private func audioImpact(asset: AVAsset, duration: Double, markers: [SwingPhaseMarker]) async throws -> AudioImpactOutcome? {
        guard let top = markers.first(where: { $0.phase == .top })?.time else { return nil }
        let poseImpact = markers.first { $0.phase == .impact }?.time
        guard let audio = try await AudioImpactReader.read(asset: asset, range: max(0, top - 0.2)...min(duration, top + 0.8)) else {
            return AudioImpactOutcome(estimate: nil, rejection: .noAudio, poseImpactTime: poseImpact)
        }
        switch ImpactOnsetDetector.detect(samples: audio.samples, sampleRate: audio.sampleRate, startTime: audio.startTime,
                                          window: top...min(duration, top + 0.6), poseImpact: poseImpact) {
        case let .success(estimate): return AudioImpactOutcome(estimate: estimate, rejection: nil, poseImpactTime: poseImpact)
        case let .failure(rejection): return AudioImpactOutcome(estimate: nil, rejection: rejection, poseImpactTime: poseImpact)
        }
    }

    /// A pass stores only joints and presentation timestamps; no decoded buffers are retained in its result.
    private func readPoseFrames(asset: AVAsset, track: AVAssetTrack, orientation: CGImagePropertyOrientation,
                                range: ClosedRange<Double>, maximumRate: Double?,
                                progress: (Double) -> Void) throws -> [PoseFrame] {
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: range.lowerBound, preferredTimescale: 60_000),
                                      end: CMTime(seconds: range.upperBound, preferredTimescale: 60_000))
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw PoseAnalysisError.unreadable }
        reader.add(output)
        guard reader.startReading() else { throw PoseAnalysisError.unreadable }
        defer { reader.cancelReading() }
        let request = VNDetectHumanBodyPoseRequest()
        var frames: [PoseFrame] = []
        var lastSampleTime = -Double.infinity
        var lastCenter: CGPoint?
        var lastDetectedTime = -Double.infinity
        var sampledCount = 0
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            if ProcessInfo.processInfo.thermalState == .critical { throw PoseAnalysisError.interrupted }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            guard timestamp.isFinite, range.contains(timestamp),
                  maximumRate.map({ timestamp - lastSampleTime >= (1 / $0) - 0.0000001 }) ?? true,
                  let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
            lastSampleTime = timestamp
            sampledCount += 1
            // AVFoundation's display transform uses video coordinates. Map it to EXIF orientation
            // rather than applying it in Core Image's opposite Y-axis coordinate system.
            let joints: [PoseJoint] = try autoreleasepool {
                try VNImageRequestHandler(cvPixelBuffer: buffer, orientation: orientation, options: [:]).perform([request])
                let candidates = try (request.results ?? []).map { try Self.joints(in: $0) }.filter { $0.count >= 6 }
                if timestamp - lastDetectedTime > 1 { lastCenter = nil }
                let selected: [PoseJoint]?
                if let center = lastCenter {
                    selected = candidates.min { Self.centerDistance($0, center) < Self.centerDistance($1, center) }
                        .flatMap { Self.centerDistance($0, center) < 0.25 ? $0 : nil }
                } else { selected = candidates.max { $0.count < $1.count } }
                guard let selected, let center = Self.center(selected) else { return [] }
                lastCenter = center
                lastDetectedTime = timestamp
                return selected
            }
            // Empty frames preserve missing observations and prevent drawing across tracking gaps.
            frames.append(PoseFrame(time: timestamp, joints: joints))
            if sampledCount % 10 == 0 {
                progress(min(1, max(0, (timestamp - range.lowerBound) / max(range.upperBound - range.lowerBound, 0.001))))
            }
        }
        guard reader.status == .completed else { throw PoseAnalysisError.unreadable }
        progress(1)
        return frames
    }

    private static func imageOrientation(_ transform: CGAffineTransform) throws -> CGImagePropertyOrientation {
        let a = Int(transform.a.rounded()), b = Int(transform.b.rounded())
        let c = Int(transform.c.rounded()), d = Int(transform.d.rounded())
        guard abs(transform.a - Double(a)) < 0.01, abs(transform.b - Double(b)) < 0.01,
              abs(transform.c - Double(c)) < 0.01, abs(transform.d - Double(d)) < 0.01 else {
            throw PoseAnalysisError.unreadable
        }
        switch (a, b, c, d) {
        case (1, 0, 0, 1): return .up
        case (0, 1, -1, 0): return .right
        case (-1, 0, 0, -1): return .down
        case (0, -1, 1, 0): return .left
        case (-1, 0, 0, 1): return .upMirrored
        case (1, 0, 0, -1): return .downMirrored
        case (0, 1, 1, 0): return .leftMirrored
        case (0, -1, -1, 0): return .rightMirrored
        default: throw PoseAnalysisError.unreadable
        }
    }

    private static let jointNames: [(VNHumanBodyPoseObservation.JointName, String)] = [
        (.nose, "nose"), (.leftEye, "leftEye"), (.rightEye, "rightEye"), (.leftEar, "leftEar"), (.rightEar, "rightEar"),
        (.neck, "neck"), (.root, "root"), (.leftShoulder, "leftShoulder"), (.rightShoulder, "rightShoulder"),
        (.leftElbow, "leftElbow"), (.rightElbow, "rightElbow"), (.leftWrist, "leftWrist"), (.rightWrist, "rightWrist"),
        (.leftHip, "leftHip"), (.rightHip, "rightHip"), (.leftKnee, "leftKnee"), (.rightKnee, "rightKnee"),
        (.leftAnkle, "leftAnkle"), (.rightAnkle, "rightAnkle")
    ]

    private static func joints(in observation: VNHumanBodyPoseObservation) throws -> [PoseJoint] {
        let points = try observation.recognizedPoints(.all)
        return jointNames.compactMap { name, label in
            guard let point = points[name], point.confidence >= 0.35,
                  (0...1).contains(point.location.x), (0...1).contains(point.location.y) else { return nil }
            return PoseJoint(name: label, x: point.location.x, y: point.location.y, confidence: Double(point.confidence))
        }
    }
    private static func center(_ joints: [PoseJoint]) -> CGPoint? {
        let torso = joints.filter { ["leftHip", "rightHip", "leftShoulder", "rightShoulder"].contains($0.name) }
        guard torso.count >= 2 else { return nil }
        return CGPoint(x: torso.map(\.x).reduce(0, +) / Double(torso.count),
                       y: torso.map(\.y).reduce(0, +) / Double(torso.count))
    }
    private static func centerDistance(_ joints: [PoseJoint], _ previous: CGPoint) -> Double {
        guard let center = center(joints) else { return .infinity }
        return hypot(center.x - previous.x, center.y - previous.y)
    }

}
