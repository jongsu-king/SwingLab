import Foundation
import SwingLabCore
import ImageIO
@preconcurrency import AVFoundation
@preconcurrency import Vision

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
    func analyze(url: URL, progress: @Sendable (Double) -> Void) async throws -> PoseAnalysisReport {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw PoseAnalysisError.unreadable }
        let duration = try await asset.load(.duration).seconds
        let transform = try await track.load(.preferredTransform)
        let orientation = try Self.imageOrientation(transform)
        let reader = try AVAssetReader(asset: asset)
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
        let limit = 30.0
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            if ProcessInfo.processInfo.thermalState == .critical { throw PoseAnalysisError.interrupted }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            guard timestamp.isFinite, timestamp - lastSampleTime >= (1 / limit) - 0.001,
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
                guard var selected, let center = Self.center(selected) else { return [] }
                lastCenter = center
                lastDetectedTime = timestamp
                if let previous = frames.last, timestamp - previous.time <= 0.15 {
                    let alpha = 1 - exp(-(timestamp - previous.time) / 0.045)
                    for index in selected.indices {
                        if let old = previous.joint(selected[index].name) {
                            selected[index].x = old.x + alpha * (selected[index].x - old.x)
                            selected[index].y = old.y + alpha * (selected[index].y - old.y)
                        }
                    }
                }
                return selected
            }
            // Empty frames preserve missing observations and prevent drawing across tracking gaps.
            frames.append(PoseFrame(time: timestamp, joints: joints))
            if sampledCount % 10 == 0 { progress(min(1, max(0, timestamp / max(duration, 0.001)))) }
        }
        guard reader.status == .completed else { throw PoseAnalysisError.unreadable }
        let detectedCount = frames.filter { !$0.joints.isEmpty }.count
        guard detectedCount >= 5 else { throw PoseAnalysisError.noPose }
        progress(1)
        return PoseAnalysisReport(frames: frames, markers: Self.suggestMarkers(frames), analyzedAt: .now,
                                  sampledFrameCount: sampledCount, poseFrameCount: detectedCount,
                                  sampleRateLimit: limit, notes: [
                                    "Pose is vision-derived 2D image geometry, not a 3D body measurement.",
                                    "Phase markers are estimates. Review and correct them before using tempo.",
                                    "Use one golfer, a steady camera, and one swing per clip."
                                  ])
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

    /// Conservative, unvalidated candidates: wrist elevation peak followed by downward image velocity.
    /// No club or ball detection is used. Users must correct estimated impact and other phases.
    private static func suggestMarkers(_ frames: [PoseFrame]) -> [SwingPhaseMarker] {
        let wrists: [(time: Double, x: Double, y: Double)] = frames.compactMap { frame in
            guard let left = frame.joint("leftWrist"), let right = frame.joint("rightWrist") else { return nil }
            return (frame.time, (left.x + right.x) / 2, (left.y + right.y) / 2)
        }
        guard wrists.count >= 20, let first = wrists.first, let last = wrists.last,
              last.time - first.time >= 0.7 else { return [] }
        // Find the first substantial local elevation peak, avoiding a later high finish.
        guard let topIndex = wrists.indices.dropFirst(4).dropLast(4).first(where: { index in
            wrists[index].y - first.y > 0.12 &&
            wrists[index].y >= wrists[index - 3].y && wrists[index].y > wrists[index + 3].y + 0.015
        }) else { return [] }
        let top = wrists[topIndex]
        guard let onsetIndex = wrists.indices.prefix(topIndex).first(where: {
            hypot(wrists[$0].x - first.x, wrists[$0].y - first.y) > 0.035
        }), onsetIndex > 0 else { return [] }
        let address = wrists[onsetIndex - 1]
        let candidates = wrists.indices.dropFirst(topIndex + 1).filter {
            wrists[$0].time - top.time <= 1.0 && wrists[$0].time - wrists[$0 - 1].time <= 0.12
        }
        guard let impactIndex = candidates.max(by: { lhs, rhs in
            let lhsVelocity = (wrists[lhs - 1].y - wrists[lhs].y) / max(0.001, wrists[lhs].time - wrists[lhs - 1].time)
            let rhsVelocity = (wrists[rhs - 1].y - wrists[rhs].y) / max(0.001, wrists[rhs].time - wrists[rhs - 1].time)
            return lhsVelocity < rhsVelocity
        }), wrists[impactIndex].time - top.time > 0.08,
            top.y - wrists[impactIndex].y > 0.08 else { return [] }
        return [
            SwingPhaseMarker(phase: .address, time: address.time, provenance: .estimated),
            SwingPhaseMarker(phase: .top, time: top.time, provenance: .estimated),
            SwingPhaseMarker(phase: .impact, time: wrists[impactIndex].time, provenance: .estimated)
        ]
    }
}
