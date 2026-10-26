import Foundation

public enum Handedness: String, Codable, CaseIterable, Sendable, Identifiable {
    case right, left
    public var id: String { rawValue }
    public var localizationKey: String { self == .right ? "Right-handed" : "Left-handed" }
    public var leadWristName: String { leadJointName("Wrist") }
    public var trailWristName: String { trailJointName("Wrist") }
    public func leadJointName(_ suffix: String) -> String { (self == .right ? "left" : "right") + suffix }
    public func trailJointName(_ suffix: String) -> String { (self == .right ? "right" : "left") + suffix }
}

public struct PoseJoint: Codable, Sendable {
    public var name: String
    /// Vision coordinates in the oriented video: origin at bottom left, normalized 0...1.
    public var x: Double
    public var y: Double
    public var confidence: Double
    public var interpolated: Bool
    public init(name: String, x: Double, y: Double, confidence: Double, interpolated: Bool = false) {
        self.name = name; self.x = x; self.y = y; self.confidence = confidence
        self.interpolated = interpolated
    }
    private enum CodingKeys: String, CodingKey { case name, x, y, confidence, interpolated }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: try values.decode(String.self, forKey: .name), x: try values.decode(Double.self, forKey: .x),
                  y: try values.decode(Double.self, forKey: .y), confidence: try values.decode(Double.self, forKey: .confidence),
                  interpolated: try values.decodeIfPresent(Bool.self, forKey: .interpolated) ?? false)
    }
}

public struct PoseFrame: Codable, Sendable {
    /// Presentation timestamp from the source sample buffer, in seconds.
    public var time: Double
    public var joints: [PoseJoint]
    public init(time: Double, joints: [PoseJoint]) { self.time = time; self.joints = joints }
    public func joint(_ name: String) -> PoseJoint? { joints.first { $0.name == name } }
}

public enum SwingPhaseName: String, CaseIterable, Codable, Sendable, Identifiable {
    case address, takeaway, midBackswing, top, downswing, impact, followThrough, finish
    public var id: String { rawValue }
    public var localizationKey: String {
        switch self {
        case .address: "Address"
        case .takeaway: "Takeaway"
        case .midBackswing: "Mid-backswing"
        case .top: "Top of backswing"
        case .downswing: "Downswing"
        case .impact: "Impact"
        case .followThrough: "Follow-through"
        case .finish: "Finish"
        }
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let phase = Self(rawValue: value) ?? Self.allCases.first(where: { $0.localizationKey == value }) {
            self = phase
        } else {
            // A phase cannot safely fall back to another physical event.
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown swing phase ID")
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct SwingPhaseMarker: Codable, Sendable, Identifiable {
    public var phase: SwingPhaseName
    public var time: Double
    /// Estimated markers are heuristic candidates and need human review.
    public var provenance: Provenance
    public var confidence: Double?
    public var rule: String
    public var id: String { phase.rawValue }
    public init(phase: SwingPhaseName, time: Double, provenance: Provenance,
                confidence: Double? = nil, rule: String = "legacy.unspecified") {
        self.phase = phase; self.time = time; self.provenance = provenance
        self.confidence = confidence.flatMap { $0.isFinite && (0...1).contains($0) ? $0 : nil }
        self.rule = rule
    }
    private enum CodingKeys: String, CodingKey { case phase, time, provenance, confidence, rule }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(phase: try values.decode(SwingPhaseName.self, forKey: .phase),
                  time: try values.decode(Double.self, forKey: .time),
                  provenance: try values.decode(Provenance.self, forKey: .provenance),
                  confidence: try values.decodeIfPresent(Double.self, forKey: .confidence),
                  rule: try values.decodeIfPresent(String.self, forKey: .rule) ?? "legacy.unspecified")
    }
    public var metric: ProvenancedValue {
        .init(value: time >= 0 ? time : nil, unit: "s", provenance: provenance,
              confidence: confidence, method: rule == "legacy.unspecified" ? "phase.\(phase.rawValue).v1" : rule, sampleCount: 1)
    }
}

public struct PoseAnalysisReport: Codable, Sendable {
    public var schemaVersion: Int
    public var frames: [PoseFrame]
    public var markers: [SwingPhaseMarker]
    public var analyzedAt: Date
    public var sampledFrameCount: Int
    public var poseFrameCount: Int
    public var sampleRateLimit: Double
    public var notes: [String]
    public var analysisVersion: Int
    public var poseFrameRate: Double?
    /// Legacy reports do not establish which lead/trail assumption was used.
    public var analyzedHandedness: Handedness?

    public init(schemaVersion: Int = 1, frames: [PoseFrame], markers: [SwingPhaseMarker], analyzedAt: Date,
                sampledFrameCount: Int, poseFrameCount: Int, sampleRateLimit: Double, notes: [String],
                analysisVersion: Int = 1, poseFrameRate: Double? = nil, analyzedHandedness: Handedness? = nil) {
        self.schemaVersion = schemaVersion; self.frames = frames; self.markers = markers; self.analyzedAt = analyzedAt
        self.sampledFrameCount = sampledFrameCount; self.poseFrameCount = poseFrameCount
        self.sampleRateLimit = sampleRateLimit; self.notes = notes
        self.analysisVersion = analysisVersion
        self.poseFrameRate = poseFrameRate.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        self.analyzedHandedness = analyzedHandedness
    }
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, frames, markers, analyzedAt, sampledFrameCount, poseFrameCount, sampleRateLimit, notes
        case analysisVersion, poseFrameRate, analyzedHandedness
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(schemaVersion: try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1,
                  frames: try values.decode([PoseFrame].self, forKey: .frames),
                  markers: try values.decode([SwingPhaseMarker].self, forKey: .markers),
                  analyzedAt: try values.decode(Date.self, forKey: .analyzedAt),
                  sampledFrameCount: try values.decode(Int.self, forKey: .sampledFrameCount),
                  poseFrameCount: try values.decode(Int.self, forKey: .poseFrameCount),
                  sampleRateLimit: try values.decode(Double.self, forKey: .sampleRateLimit),
                  notes: try values.decode([String].self, forKey: .notes),
                  analysisVersion: try values.decodeIfPresent(Int.self, forKey: .analysisVersion) ?? 1,
                  poseFrameRate: try values.decodeIfPresent(Double.self, forKey: .poseFrameRate),
                  analyzedHandedness: try values.decodeIfPresent(Handedness.self, forKey: .analyzedHandedness))
    }
    public func marker(_ phase: SwingPhaseName) -> SwingPhaseMarker? { markers.first { $0.phase == phase } }
    public var backswingDuration: Double? {
        guard let address = marker(.address), let top = marker(.top), address.time.isFinite,
              top.time.isFinite, address.time >= 0, top.time > address.time else { return nil }
        return top.time - address.time
    }
    public var downswingDuration: Double? {
        guard let top = marker(.top), let impact = marker(.impact), top.time.isFinite,
              impact.time.isFinite, top.time >= 0, impact.time > top.time else { return nil }
        return impact.time - top.time
    }
    public var tempoRatio: Double? {
        guard let back = backswingDuration, let down = downswingDuration, down > 0.01 else { return nil }
        let ratio = back / down
        return ratio.isFinite ? ratio : nil
    }
    public var timingProvenance: Provenance? {
        guard tempoRatio != nil else { return nil }
        return timingProvenance(for: [.address, .top, .impact])
    }
    /// Mixed timing remains estimated; one audio-derived impact cannot upgrade
    /// address/top or a resulting tempo to a direct sensor measurement.
    private func timingProvenance(for phases: [SwingPhaseName]) -> Provenance {
        let origins = phases.compactMap { marker($0)?.provenance }
        guard origins.count == phases.count, !origins.contains(.unavailable) else { return .unavailable }
        if origins.contains(.simulated) { return .simulated }
        return origins.allSatisfy { $0 == .userEntered } ? .userEntered : .estimated
    }
    public var backswingMetric: ProvenancedValue {
        .init(value: backswingDuration, unit: "s", provenance: timingProvenance(for: [.address, .top]),
              method: "phase.backswingDuration.v1", sampleCount: backswingDuration == nil ? nil : 1)
    }
    public var downswingMetric: ProvenancedValue {
        .init(value: downswingDuration, unit: "s", provenance: timingProvenance(for: [.top, .impact]),
              method: "phase.downswingDuration.v1", sampleCount: downswingDuration == nil ? nil : 1)
    }
    public var tempoMetric: ProvenancedValue {
        .init(value: tempoRatio, unit: "1", provenance: timingProvenance ?? .unavailable,
              method: "phase.tempoRatio.v1", sampleCount: tempoRatio == nil ? nil : 1)
    }
    public var headMovementPercent: Double? { headDisplacementMetric.value.map { $0 * 100 } }
    public var headDisplacementMetric: ProvenancedValue {
        guard let start = marker(.address)?.time, let end = marker(.impact)?.time,
              start.isFinite, end.isFinite, start >= 0, end > start else {
            return .init(value: nil, unit: "1", provenance: .unavailable, method: "pose.noseDisplacement.v1")
        }
        let interval = PoseProcessing.localSampleInterval(frames: frames, time: start) ?? 0
        let addressFrame = frames.min { abs($0.time - start) < abs($1.time - start) }
        let points = frames.filter { $0.time >= start && $0.time <= end }.compactMap { $0.joint("nose") }
        guard points.count >= 5, let addressFrame, abs(addressFrame.time - start) <= interval * 1.5 + 1e-9,
              let initial = addressFrame.joint("nose"), !initial.interpolated,
              points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
            return .init(value: nil, unit: "1", provenance: .unavailable, method: "pose.noseDisplacement.v1",
                         sampleCount: points.count)
        }
        return .init(value: points.map { hypot($0.x - initial.x, $0.y - initial.y) }.max(),
                     unit: "1", provenance: .visionDerived, method: "pose.noseDisplacement.v1", sampleCount: points.count)
    }
}
