import Foundation

/// Sample statistics for one metric. Statements about consistency need `minimumForStatement` values.
public struct MetricSummary: Codable, Sendable, Equatable {
    public let count: Int
    public let mean: Double
    /// Sample standard deviation (n − 1).
    public let standardDeviation: Double
    /// SD / |mean|; nil when the mean is too close to zero for a ratio to mean anything.
    public let coefficientOfVariation: Double?

    public static let minimumForStatement = 5

    public init?(_ values: [Double]) {
        let finite = values.filter(\.isFinite)
        guard finite.count >= 2 else { return nil }
        let mean = finite.reduce(0, +) / Double(finite.count)
        let variance = finite.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(finite.count - 1)
        count = finite.count
        self.mean = mean
        standardDeviation = variance.squareRoot()
        coefficientOfVariation = abs(mean) > 1e-9 ? standardDeviation / abs(mean) : nil
    }
}

public enum CoachedMetric: String, Codable, CaseIterable, Sendable {
    case tempo, backswing, downswing, headDisplacement
}

/// One analysed swing as the coaching engine sees it: typed metrics with their origins.
public struct CoachingSample: Sendable {
    public let id: UUID
    public let date: Date
    public let club: String?
    public let cameraAngle: CameraAngle
    public let metrics: [CoachedMetric: ProvenancedValue]
    public init(id: UUID, date: Date, club: String?, cameraAngle: CameraAngle, metrics: [CoachedMetric: ProvenancedValue]) {
        self.id = id; self.date = date; self.club = club; self.cameraAngle = cameraAngle; self.metrics = metrics
    }
    func value(_ metric: CoachedMetric) -> Double? {
        guard let value = metrics[metric], value.provenance != .unavailable, let number = value.value, number.isFinite else { return nil }
        return number
    }
}

/// A localizable observation: a stable template ID plus the numbers it quotes. The engine never
/// produces free text, judgements ("good", "bad"), or fault diagnoses.
public struct CoachingFeedback: Codable, Sendable, Equatable {
    public let templateID: String
    public let metric: CoachedMetric?
    public let current: Double?
    public let baselineMean: Double?
    public let baselineCount: Int
    public let drillID: String?
}

/// Compares one swing with the golfer's own recent swings from the same camera angle and club.
/// Thresholds are documented in `Docs/Coaching.md` and are not calibrated against coaching outcomes.
public enum CoachingEngine {
    public static let baselineSize = 20
    public static let zThreshold = 1.5
    public static let ruleVersion = "coach.baselineZ.v1"

    public static func feedback(for current: CoachingSample, history: [CoachingSample]) -> [CoachingFeedback] {
        // Same angle and club only; different views or clubs are different measurements.
        let comparable = history
            .filter { $0.id != current.id && $0.cameraAngle == current.cameraAngle && $0.club == current.club && $0.date < current.date }
            .sorted { $0.date > $1.date }
            .prefix(baselineSize)
        var result: [CoachingFeedback] = []
        for metric in CoachedMetric.allCases {
            guard let value = current.value(metric) else { continue }
            let baseline = comparable.compactMap { $0.value(metric) }
            guard baseline.count >= MetricSummary.minimumForStatement, let summary = MetricSummary(baseline) else {
                if metric == .tempo {
                    result.append(.init(templateID: "coach.needMoreSwings", metric: nil, current: nil, baselineMean: nil,
                                        baselineCount: baseline.count, drillID: nil))
                }
                continue
            }
            // A perfectly repeated baseline (SD 0) cannot define an unusual swing.
            guard summary.standardDeviation > 1e-9 else { continue }
            let z = (value - summary.mean) / summary.standardDeviation
            guard abs(z) > zThreshold else { continue }
            result.append(.init(templateID: "coach.\(metric.rawValue).\(z > 0 ? "higher" : "lower")", metric: metric,
                                current: value, baselineMean: summary.mean, baselineCount: summary.count,
                                drillID: drill(for: metric)))
        }
        return result
    }

    /// Consistency of one metric across a session or history; nil below the statement minimum.
    public static func consistency(_ metric: CoachedMetric, in samples: [CoachingSample]) -> MetricSummary? {
        let values = samples.compactMap { $0.value(metric) }
        guard values.count >= MetricSummary.minimumForStatement else { return nil }
        return MetricSummary(values)
    }

    static func drill(for metric: CoachedMetric) -> String? {
        switch metric {
        case .tempo, .backswing, .downswing: "drill.countedTempo"
        case .headDisplacement: "drill.steadyHeadMirror"
        }
    }
}
