import Foundation

public enum AimStrategy: String, CaseIterable, Sendable {
    case conservative, balanced, aggressive
    public var localizationKey: LocalizationKey {
        switch self { case .conservative: "Conservative"; case .balanced: "Balanced"; case .aggressive: "Aggressive" }
    }
    var varianceWeight: Double { switch self { case .conservative: 2; case .balanced: 1; case .aggressive: 0.5 } }
    func penalty(_ kind: CourseAreaKind) -> Double {
        let base: Double
        switch kind { case .bunker: base = 900; case .water, .penalty: base = 3600; case .outOfBounds: base = 6400; default: base = 0 }
        switch self { case .conservative: return base * 2; case .balanced: return base; case .aggressive: return base * 0.5 }
    }
}
public enum CaddieShotKind: String, CaseIterable, Sendable { case approach, tee }
public struct AimClubProfile: Sendable {
    public let id: UUID
    public let carry: Double?
    public let total: Double?
    public let forwardSD: Double
    public let lateralSD: Double
    public let lateralMean: Double
    public let correlation: Double
    public init(id: UUID, carry: Double?, total: Double?, forwardSD: Double, lateralSD: Double, lateralMean: Double = 0, correlation: Double = 0) {
        self.id = id; self.carry = carry; self.total = total; self.forwardSD = forwardSD
        self.lateralSD = lateralSD; self.lateralMean = lateralMean; self.correlation = correlation
    }
}
public struct HazardRisk: Sendable, Equatable {
    public let areaID: String
    public let kind: CourseAreaKind
    public let probability: Double
    public var metric: ProvenancedValue { .init(value: probability, unit: "1", provenance: .estimated, method: "caddie.gaussianPolygon.v2") }
}
public struct AimCandidate: Sendable {
    public let clubID: UUID
    public let aimOffsetMeters: Double
    public let aimPoint: GeoCoordinate
    public let expectedLanding: GeoCoordinate
    public let region80: [GeoCoordinate]
    public let expectedDistanceError: Double
    public let score: Double
    public let hazards: [HazardRisk]
}
public struct AimRecommendation: Sendable {
    public let recommended: AimCandidate
    public let safer: AimCandidate
    public let aggressive: AimCandidate
}
public enum CaddieAimSearch {
    /// Squared distance error + preference-weighted variance + supplied polygon risks.
    /// Hazard weights have m² units and are engineering preferences, not strokes gained.
    /// Adjustments are explicit user-entered landing shifts (metres), never inferred wind physics.
    public static func recommend(profiles: [AimClubProfile], origin: GeoCoordinate, target: GeoCoordinate,
                                 areas: [CourseArea], strategy: AimStrategy = .balanced,
                                 shot: CaddieShotKind = .approach, forwardAdjustment: Double = 0,
                                 rightAdjustment: Double = 0) -> AimRecommendation? {
        guard origin.isValid, target.isValid, [forwardAdjustment, rightAdjustment].allSatisfy(\.isFinite),
              abs(forwardAdjustment) <= 200, abs(rightAdjustment) <= 200 else { return nil }
        let distance = Geo.distance(from: origin, to: target), targetBearing = Geo.bearing(from: origin, to: target)
        guard distance > 1, distance < 1000 else { return nil }
        let hazards = areas.filter { $0.kind.isHazard && $0.isValid }
        var candidates: [(candidate: AimCandidate, variance: Double)] = []
        for profile in profiles {
            guard let mean = shot == .tee ? profile.total : profile.carry, mean.isFinite,
                  let distribution = try? GaussianDispersion(meanCarry: mean + forwardAdjustment,
                    meanLateral: profile.lateralMean + rightAdjustment, carrySD: profile.forwardSD,
                    lateralSD: profile.lateralSD, correlation: profile.correlation) else { continue }
            for offset in stride(from: -30.0, through: 30.0, by: 2.0) {
                if Task.isCancelled { return nil }
                let aim = Geo.project(origin: origin, bearingDegrees: targetBearing, forward: distance, right: offset)
                let bearing = Geo.bearing(from: origin, to: aim)
                let landing = Geo.project(origin: origin, bearingDegrees: bearing, forward: distribution.mean.forward, right: distribution.mean.right)
                let remaining = Geo.distance(from: landing, to: target)
                let risks = hazards.compactMap { area -> HazardRisk? in
                    guard let p = area.probabilityValidated(distribution: distribution, origin: origin, bearingDegrees: bearing) else { return nil }
                    return .init(areaID: area.id, kind: area.kind, probability: p)
                }
                let region = distribution.ellipse(probability: 0.8, segments: 48).map {
                    Geo.project(origin: origin, bearingDegrees: bearing, forward: $0.forward, right: $0.right)
                }
                candidates.append((.init(clubID: profile.id, aimOffsetMeters: offset, aimPoint: aim,
                    expectedLanding: landing, region80: region, expectedDistanceError: remaining,
                    score: remaining * remaining, hazards: risks), profile.forwardSD * profile.forwardSD + profile.lateralSD * profile.lateralSD))
            }
        }
        func best(_ preference: AimStrategy) -> AimCandidate? {
            candidates.map { item in
                let value = item.candidate
                return AimCandidate(clubID: value.clubID, aimOffsetMeters: value.aimOffsetMeters, aimPoint: value.aimPoint,
                    expectedLanding: value.expectedLanding, region80: value.region80, expectedDistanceError: value.expectedDistanceError,
                    score: value.score + preference.varianceWeight * item.variance + value.hazards.reduce(0) { $0 + preference.penalty($1.kind) * $1.probability }, hazards: value.hazards)
            }.min { a, b in
                if abs(a.score - b.score) > 1e-9 { return a.score < b.score }
                if abs(a.aimOffsetMeters) != abs(b.aimOffsetMeters) { return abs(a.aimOffsetMeters) < abs(b.aimOffsetMeters) }
                return a.clubID.uuidString < b.clubID.uuidString
            }
        }
        guard let selected = best(strategy), let safer = best(.conservative), let aggressive = best(.aggressive) else { return nil }
        return .init(recommended: selected, safer: safer, aggressive: aggressive)
    }
}
