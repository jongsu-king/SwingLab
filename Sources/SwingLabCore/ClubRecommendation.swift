import Foundation

public struct ClubProfile: Sendable, Equatable {
    public let id: UUID
    public let carry: Double
    public let lateralMean: Double
    public let carrySD: Double
    public let lateralSD: Double
    public init(id: UUID, carry: Double, lateralMean: Double, carrySD: Double, lateralSD: Double) {
        self.id = id; self.carry = carry; self.lateralMean = lateralMean
        self.carrySD = carrySD; self.lateralSD = lateralSD
    }
}
public struct ClubRecommendation: Sendable, Equatable {
    public let id: UUID
    public let score: Double
    public let remaining: Double
}
public enum RecommendationEngine {
    /// Distance error plus a preference-weighted variance. Not a hazard probability.
    public static func rank(profiles: [ClubProfile], targetDistance: Double, varianceWeight: Double) -> [ClubRecommendation] {
        guard targetDistance.isFinite, targetDistance > 0, varianceWeight.isFinite, varianceWeight >= 0 else { return [] }
        return profiles.compactMap { profile in
            guard [profile.carry, profile.lateralMean, profile.carrySD, profile.lateralSD].allSatisfy(\.isFinite),
                  profile.carry > 0, profile.carrySD > 0, profile.lateralSD > 0 else { return nil }
            let delta = targetDistance - profile.carry
            let squaredError = delta * delta + profile.lateralMean * profile.lateralMean
            let variance = profile.carrySD * profile.carrySD + profile.lateralSD * profile.lateralSD
            let score = squaredError + varianceWeight * variance
            guard score.isFinite else { return nil }
            return ClubRecommendation(id: profile.id, score: score, remaining: sqrt(squaredError))
        }.sorted { $0.score == $1.score ? $0.id.uuidString < $1.id.uuidString : $0.score < $1.score }
    }
}
