import Foundation

/// One shot of a live session, kept only for the session summary. The measured values are the
/// shot's own; the carry bracket is the simulation shown with it.
public struct LaunchSessionShot: Sendable, Equatable {
    public let time: Date
    public let club: ReferenceClub
    public let ballSpeed: Double     // m/s, vision-derived
    public let launchAngle: Double   // rad, vision-derived
    public let carry: ClosedRange<Double>?  // m, simulated
    public init(time: Date, club: ReferenceClub, ballSpeed: Double, launchAngle: Double, carry: ClosedRange<Double>?) {
        self.time = time; self.club = club; self.ballSpeed = ballSpeed; self.launchAngle = launchAngle; self.carry = carry
    }
}

public struct LaunchSessionClubSummary: Sendable, Equatable {
    public let club: ReferenceClub
    public let count: Int
    public let ballSpeed: ProvenancedValue       // mean, m/s
    public let launchAngle: ProvenancedValue     // mean, rad
    /// One sample standard deviation of ball speed; from five shots, the coaching threshold.
    public let speedSpread: ProvenancedValue?
    /// Shortest and longest simulated carry seen for the club in this session.
    public let carry: ReadoutRange?
}

/// The change from the previous shot with the same club: a measured difference, not coaching.
public struct LaunchSessionChange: Sendable, Equatable {
    public let ballSpeed: ProvenancedValue   // m/s
    public let launchAngle: ProvenancedValue // rad
}

/// Session arithmetic for the live readout. Averages need two shots; the spread needs five.
public enum LaunchSession {
    public static let meanMethod = "session.mean.v1"
    public static let spreadMethod = "session.sampleStandardDeviation.v1"
    public static let changeMethod = "session.changeFromPrevious.v1"
    public static let spreadThreshold = 5

    public static func summaries(_ shots: [LaunchSessionShot]) -> [LaunchSessionClubSummary] {
        let grouped = Dictionary(grouping: shots, by: \.club)
        return ReferenceClub.allCases.compactMap { club in
            guard let group = grouped[club], !group.isEmpty else { return nil }
            let speeds = group.map(\.ballSpeed), angles = group.map(\.launchAngle)
            let meanSpeed = speeds.reduce(0, +) / Double(speeds.count)
            let spread: ProvenancedValue? = speeds.count >= spreadThreshold ? {
                let variance = speeds.map { ($0 - meanSpeed) * ($0 - meanSpeed) }.reduce(0, +) / Double(speeds.count - 1)
                return ProvenancedValue(value: variance.squareRoot(), unit: "m/s", provenance: .visionDerived,
                                        method: spreadMethod, sampleCount: speeds.count)
            }() : nil
            let carries = group.compactMap(\.carry)
            let carry: ReadoutRange? = carries.isEmpty ? nil : ReadoutRange(
                low: ProvenancedValue(value: carries.map(\.lowerBound).min(), unit: "m", provenance: .simulated,
                                      method: CarryRangeEstimator.method, sampleCount: carries.count),
                high: ProvenancedValue(value: carries.map(\.upperBound).max(), unit: "m", provenance: .simulated,
                                       method: CarryRangeEstimator.method, sampleCount: carries.count))
            return LaunchSessionClubSummary(
                club: club, count: group.count,
                ballSpeed: ProvenancedValue(value: meanSpeed, unit: "m/s", provenance: .visionDerived, method: meanMethod, sampleCount: speeds.count),
                launchAngle: ProvenancedValue(value: angles.reduce(0, +) / Double(angles.count), unit: "rad", provenance: .visionDerived,
                                              method: meanMethod, sampleCount: angles.count),
                speedSpread: spread, carry: carry)
        }
    }

    /// Difference between the newest shot and the previous one with the same club, in time order.
    public static func change(in shots: [LaunchSessionShot]) -> LaunchSessionChange? {
        let ordered = shots.sorted { $0.time < $1.time }
        guard let latest = ordered.last,
              let previous = ordered.dropLast().last(where: { $0.club == latest.club }) else { return nil }
        return LaunchSessionChange(
            ballSpeed: ProvenancedValue(value: latest.ballSpeed - previous.ballSpeed, unit: "m/s", provenance: .visionDerived,
                                        method: changeMethod, sampleCount: 2),
            launchAngle: ProvenancedValue(value: latest.launchAngle - previous.launchAngle, unit: "rad", provenance: .visionDerived,
                                          method: changeMethod, sampleCount: 2))
    }
}
