import Foundation

/// Practice games scored on the **simulated** carry bracket of each measured launch. A hit means
/// the bracket overlaps the target band; nothing here measures where the ball actually landed.
public enum DrillKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case target, ladder
    public var id: String { rawValue }
    public var localizationKey: LocalizationKey {
        switch self {
        case .target: "Target drill"
        case .ladder: "Ladder drill"
        }
    }
}

public struct DrillTarget: Sendable, Equatable, Codable {
    public let distance: Double    // m
    public let tolerance: Double   // m, ± around the distance
    public init(distance: Double, tolerance: Double) { self.distance = distance; self.tolerance = max(0, tolerance) }
    public var band: ClosedRange<Double> { (distance - tolerance)...(distance + tolerance) }
}

public enum DrillOutcome: String, Codable, Sendable, CaseIterable {
    case hit, short, long
    public var localizationKey: LocalizationKey {
        switch self {
        case .hit: "Hit"
        case .short: "Short"
        case .long: "Long"
        }
    }
}

public struct DrillShotResult: Sendable, Equatable {
    public let target: DrillTarget
    /// The simulated carry bracket the shot was scored on (m).
    public let carry: ClosedRange<Double>
    public let outcome: DrillOutcome
    /// Distance between the bracket and the target band (m): negative when short, positive when long, 0 for a hit.
    public let gap: Double
    public var gapMetric: ProvenancedValue {
        ProvenancedValue(value: gap, unit: "m", provenance: .simulated, method: DrillScorer.method)
    }
}

public enum DrillScorer {
    public static let method = "drill.carryBracketVsTarget.v1"

    /// Hit when the bracket overlaps the band; otherwise the gap to the band's nearest edge.
    public static func score(carry: ClosedRange<Double>, target: DrillTarget) -> DrillShotResult {
        let band = target.band
        if carry.upperBound < band.lowerBound {
            return DrillShotResult(target: target, carry: carry, outcome: .short, gap: carry.upperBound - band.lowerBound)
        }
        if carry.lowerBound > band.upperBound {
            return DrillShotResult(target: target, carry: carry, outcome: .long, gap: carry.lowerBound - band.upperBound)
        }
        return DrillShotResult(target: target, carry: carry, outcome: .hit, gap: 0)
    }
}

/// Targets that climb by a fixed step; a hit moves up a rung, a miss stays.
public struct LadderDrill: Sendable, Equatable, Codable {
    public let start: Double      // m
    public let step: Double       // m
    public let rungs: Int
    public let tolerance: Double  // m
    public init?(start: Double, step: Double, rungs: Int, tolerance: Double) {
        guard start.isFinite, step.isFinite, tolerance.isFinite, start > 0, step > 0, rungs >= 1, rungs <= 20 else { return nil }
        self.start = start; self.step = step; self.rungs = rungs; self.tolerance = max(0, tolerance)
    }
    public func target(rung: Int) -> DrillTarget {
        DrillTarget(distance: start + Double(min(max(rung, 0), rungs - 1)) * step, tolerance: tolerance)
    }
}

/// One drill in progress: the current target, every result, the score, and the streak.
public struct DrillSession: Sendable, Equatable {
    public let kind: DrillKind
    public let ladder: LadderDrill?
    public private(set) var target: DrillTarget
    public private(set) var rung = 0
    public private(set) var results: [DrillShotResult] = []
    public private(set) var streak = 0
    public private(set) var bestStreak = 0

    public init(target: DrillTarget) { kind = .target; ladder = nil; self.target = target }
    public init(ladder: LadderDrill) { kind = .ladder; self.ladder = ladder; target = ladder.target(rung: 0) }

    public var shots: Int { results.count }
    public var hits: Int { results.filter { $0.outcome == .hit }.count }
    /// A ladder is complete once its top rung has been hit; a target drill never completes.
    public var isComplete: Bool { ladder.map { rung >= $0.rungs } ?? false }

    @discardableResult
    public mutating func record(carry: ClosedRange<Double>) -> DrillShotResult {
        let result = DrillScorer.score(carry: carry, target: target)
        results.append(result)
        if result.outcome == .hit {
            streak += 1; bestStreak = max(bestStreak, streak)
            if let ladder, rung < ladder.rungs {
                rung += 1
                if rung < ladder.rungs { target = ladder.target(rung: rung) }
            }
        } else { streak = 0 }
        return result
    }

    /// Forgets the last shot (a discarded mis-hit) and steps a ladder back if that shot had climbed it.
    public mutating func discardLast() {
        guard let last = results.popLast() else { return }
        if last.outcome == .hit, let ladder, rung > 0 {
            rung -= 1
            target = ladder.target(rung: rung)
        }
        streak = 0
        var run = 0
        for result in results.reversed() { if result.outcome == .hit { run += 1 } else { break } }
        streak = run
        bestStreak = results.reduce(into: (best: 0, run: 0)) { state, result in
            state.run = result.outcome == .hit ? state.run + 1 : 0
            state.best = max(state.best, state.run)
        }.best
    }
}
