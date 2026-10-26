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
    public var templateKey: LocalizationKey {
        switch templateID {
        case "coach.needMoreSwings": "coach.needMoreSwings"
        case "coach.tempo.higher": "coach.tempo.higher"
        case "coach.tempo.lower": "coach.tempo.lower"
        case "coach.backswing.higher": "coach.backswing.higher"
        case "coach.backswing.lower": "coach.backswing.lower"
        case "coach.downswing.higher": "coach.downswing.higher"
        case "coach.downswing.lower": "coach.downswing.lower"
        case "coach.headDisplacement.higher": "coach.headDisplacement.higher"
        case "coach.headDisplacement.lower": "coach.headDisplacement.lower"
        default: "Unavailable"
        }
    }
    public var drillKey: LocalizationKey? {
        switch drillID {
        case "drill.countedTempo": "drill.countedTempo"
        case "drill.steadyHeadMirror": "drill.steadyHeadMirror"
        default: nil
        }
    }
}

/// Evidence for one actual comparison. No entry exists for a missing current value,
/// fewer than five baseline values, or a constant baseline with undefined z-score.
public struct CoachingComparison: Sendable {
    public let metric: CoachedMetric
    public let current: Double
    public let baseline: MetricSummary
    public var zScore: Double { (current - baseline.mean) / baseline.standardDeviation }
}

/// Compares one swing with the golfer's own recent swings from the same camera angle and club.
/// Thresholds are documented in `Docs/Coaching.md` and are not calibrated against coaching outcomes.
public enum CoachingEngine {
    public static let baselineSize = 20
    public static let zThreshold = 1.5
    public static let ruleVersion = "coach.baselineZ.v1"

    private static func comparable(to current: CoachingSample, in history: [CoachingSample]) -> [CoachingSample] {
        guard current.cameraAngle != .unspecified else { return [] }
        // Same angle and club only; different views or clubs are different measurements.
        return Array(history
            .filter { sample in
                sample.id != current.id && sample.cameraAngle == current.cameraAngle && sample.club == current.club
                    && sample.date < current.date && CoachedMetric.allCases.contains { sample.value($0) != nil }
            }
            .sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date }
            .prefix(baselineSize))
    }

    public static func comparisons(for current: CoachingSample, history: [CoachingSample]) -> [CoachingComparison] {
        let history = comparable(to: current, in: history)
        return CoachedMetric.allCases.compactMap { metric in
            guard let value = current.value(metric),
                  let baseline = MetricSummary(history.compactMap { $0.value(metric) }),
                  baseline.count >= MetricSummary.minimumForStatement, baseline.standardDeviation > 1e-9 else { return nil }
            return CoachingComparison(metric: metric, current: value, baseline: baseline)
        }
    }

    public static func feedback(for current: CoachingSample, history: [CoachingSample]) -> [CoachingFeedback] {
        guard current.cameraAngle != .unspecified else { return [] }
        let comparable = comparable(to: current, in: history)
        let comparisons = comparisons(for: current, history: history)
        var result: [CoachingFeedback] = []
        for metric in CoachedMetric.allCases {
            guard current.value(metric) != nil else { continue }
            let baseline = comparable.compactMap { $0.value(metric) }
            guard baseline.count >= MetricSummary.minimumForStatement else {
                if metric == .tempo {
                    result.append(.init(templateID: "coach.needMoreSwings", metric: nil, current: nil, baselineMean: nil,
                                        baselineCount: baseline.count, drillID: nil))
                }
                continue
            }
            // A perfectly repeated baseline (SD 0) cannot define an unusual swing.
            guard let comparison = comparisons.first(where: { $0.metric == metric }) else { continue }
            let summary = comparison.baseline, z = comparison.zScore
            guard abs(z) > zThreshold else { continue }
            result.append(.init(templateID: "coach.\(metric.rawValue).\(z > 0 ? "higher" : "lower")", metric: metric,
                                current: comparison.current, baselineMean: summary.mean, baselineCount: summary.count,
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
