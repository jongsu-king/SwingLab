import Foundation
import SwiftData

@Model
final class SwingRecording {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var title: String
    var videoFileName: String
    var durationSeconds: Double
    var nominalFrameRate: Double
    var videoWidth: Double
    var videoHeight: Double
    var cameraAngle: String
    var source: String
    @Attribute(.externalStorage) var analysisData: Data?

    init(title: String, videoFileName: String, durationSeconds: Double,
         nominalFrameRate: Double, videoWidth: Double, videoHeight: Double,
         cameraAngle: String = "Face-on", source: String = "Recorded") {
        id = UUID()
        createdAt = .now
        self.title = title
        self.videoFileName = videoFileName
        self.durationSeconds = durationSeconds
        self.nominalFrameRate = nominalFrameRate
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.cameraAngle = cameraAngle
        self.source = source
    }

    var analysis: PoseAnalysisReport? {
        guard let analysisData else { return nil }
        return try? JSONDecoder().decode(PoseAnalysisReport.self, from: analysisData)
    }

    var tempoRatio: Double? { analysis?.tempoRatio }
    var tempoProvenance: String? { analysis?.timingProvenance }
}

struct PoseJoint: Codable, Sendable {
    var name: String
    /// Vision coordinates in the oriented video: origin at bottom left, normalized 0...1.
    var x: Double
    var y: Double
    var confidence: Double
}

struct PoseFrame: Codable, Sendable {
    /// Presentation timestamp from the source sample buffer, in seconds.
    var time: Double
    var joints: [PoseJoint]
    func joint(_ name: String) -> PoseJoint? { joints.first { $0.name == name } }
}

enum SwingPhaseName: String, CaseIterable, Codable, Sendable, Identifiable {
    case address = "Address"
    case takeaway = "Takeaway"
    case midBackswing = "Mid-backswing"
    case top = "Top of backswing"
    case downswing = "Downswing"
    case impact = "Impact"
    case followThrough = "Follow-through"
    case finish = "Finish"
    var id: String { rawValue }
}

struct SwingPhaseMarker: Codable, Sendable, Identifiable {
    var phase: SwingPhaseName
    var time: Double
    /// Estimated markers are heuristic candidates and need human review.
    var provenance: String
    var id: String { phase.rawValue }
}

struct PoseAnalysisReport: Codable, Sendable {
    var schemaVersion = 1
    var frames: [PoseFrame]
    var markers: [SwingPhaseMarker]
    var analyzedAt: Date
    var sampledFrameCount: Int
    var poseFrameCount: Int
    var sampleRateLimit: Double
    var notes: [String]

    func marker(_ phase: SwingPhaseName) -> SwingPhaseMarker? { markers.first { $0.phase == phase } }
    var backswingDuration: Double? {
        guard let address = marker(.address), let top = marker(.top), address.time.isFinite,
              top.time.isFinite, address.time >= 0, top.time > address.time else { return nil }
        return top.time - address.time
    }
    var downswingDuration: Double? {
        guard let top = marker(.top), let impact = marker(.impact), top.time.isFinite,
              impact.time.isFinite, top.time >= 0, impact.time > top.time else { return nil }
        return impact.time - top.time
    }
    var tempoRatio: Double? {
        guard let back = backswingDuration, let down = downswingDuration, down > 0.01 else { return nil }
        let ratio = back / down
        return ratio.isFinite ? ratio : nil
    }
    var timingProvenance: String? {
        guard tempoRatio != nil else { return nil }
        return [SwingPhaseName.address, .top, .impact].allSatisfy { marker($0)?.provenance == "User-entered" }
            ? "User-entered" : "Estimated"
    }
    var headMovementPercent: Double? {
        guard let start = marker(.address)?.time, let end = marker(.impact)?.time, end > start else { return nil }
        let points = frames.filter { $0.time >= start && $0.time <= end }.compactMap { $0.joint("nose") }
        guard points.count >= 5, let initial = points.first else { return nil }
        return points.map { hypot($0.x - initial.x, $0.y - initial.y) }.max().map { $0 * 100 }
    }
}
