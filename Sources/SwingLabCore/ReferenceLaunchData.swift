import Foundation

/// Published population statistics are deliberately a different type from a user's measurement.
/// No reference value may be written to the user's measured/vision-derived launch record.
public enum ReferenceClub: String, CaseIterable, Codable, Sendable, Identifiable {
    case driver, wood3, wood5, wood7, hybrid, iron3, iron4, iron5, iron6, iron7, iron8, iron9, pitchingWedge
    public var id: String { rawValue }
    public var localizationKey: LocalizationKey {
        switch self {
        case .driver: "Driver"
        case .wood3: "3-wood"
        case .wood5: "5-wood"
        case .wood7: "7-wood"
        case .hybrid: "Hybrid"
        case .iron3: "3-iron"
        case .iron4: "4-iron"
        case .iron5: "5-iron"
        case .iron6: "6-iron"
        case .iron7: "7-iron"
        case .iron8: "8-iron"
        case .iron9: "9-iron"
        case .pitchingWedge: "Pitching wedge"
        }
    }
}

public enum ReferenceMetric: String, CaseIterable, Codable, Sendable, Identifiable {
    case clubSpeed, ballSpeed, smashFactor, launch, spin, carry, apex
    public var id: String { rawValue }
    public var localizationKey: LocalizationKey {
        switch self {
        case .clubSpeed: "Club speed"
        case .ballSpeed: "Ball speed"
        case .smashFactor: "Smash factor"
        case .launch: "Launch angle"
        case .spin: "Spin rate"
        case .carry: "Carry"
        case .apex: "Apex"
        }
    }
    public var siUnit: String {
        switch self {
        case .clubSpeed, .ballSpeed: "m/s"
        case .smashFactor: "1"
        case .launch: "rad"
        case .spin: "rad/s"
        case .carry, .apex: "m"
        }
    }
}

public enum ReferenceUnit: String, Codable, Sendable {
    case mph, yards, meters, degrees, rpm, ratio
    public var siMultiplier: Double {
        switch self {
        case .mph: 0.44704
        case .yards: 0.9144
        case .meters, .ratio: 1
        case .degrees: .pi / 180
        case .rpm: 2 * .pi / 60
        }
    }
}

public struct ReferenceCitation: Equatable, Codable, Sendable {
    public let sourceID: String
    public let locator: String
    /// Publication year, not a fabricated observation year. Nil explicitly means undated.
    public let publicationYear: Int?
    public let dataYear: Int?
}

public struct PublishedLaunchValue: Equatable, Codable, Sendable {
    public let publishedValue: Double
    public let publishedUnit: ReferenceUnit
    public let publishedStandardDeviation: Double?
    public let citation: ReferenceCitation
    public var siValue: Double { publishedValue * publishedUnit.siMultiplier }
    public var siStandardDeviation: Double? { publishedStandardDeviation.map { $0 * publishedUnit.siMultiplier } }
}

public struct ReferenceSource: Equatable, Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let url: URL
    public let publicationYear: Int?
    public let dataYear: Int?
}

public enum ReferencePopulation: String, Codable, Sendable, CaseIterable, Identifiable {
    case pga2023, lpga2023, pgaOlder, lpgaOlder, usgaFemale, usgaMale, recreationalGrass, recreationalMat
    public var id: String { rawValue }
    public var localizationKey: LocalizationKey {
        switch self {
        case .pga2023: "PGA Tour · 2023"
        case .lpga2023: "LPGA Tour · 2023"
        case .pgaOlder: "PGA Tour · older, undated"
        case .lpgaOlder: "LPGA Tour · older, undated"
        case .usgaFemale: "USGA · female golfers"
        case .usgaMale: "USGA · male golfers"
        case .recreationalGrass: "USGA · recreational golfers · grass"
        case .recreationalMat: "USGA · recreational golfers · mat"
        }
    }
}

public struct ReferenceLaunchRow: Sendable, Identifiable {
    public let id: String
    public let club: ReferenceClub
    public let population: ReferencePopulation
    /// R22-01's published CONGU group (0 = professional, 1...4 = amateur categories).
    /// Do not translate this into a modern handicap or infer it from a user's speed.
    public let skillGroup: Int?
    public let sampleCount: Int?
    public let values: [ReferenceMetric: PublishedLaunchValue]
}

/// A bracket of published averages, not a confidence interval or expected personal range.
public struct ReferenceValueBand: Equatable, Sendable {
    public let lowerSI: Double
    public let upperSI: Double
    public let citations: [ReferenceCitation]
}

public struct InterpolatedReferenceValue: Equatable, Sendable {
    public let valueSI: Double
    public let bracket: ReferenceValueBand
    public let isInterpolated: Bool
}

public struct ReferenceSpeedMatch: Sendable {
    public let lowerRowID: String
    public let upperRowID: String
    public let ballSpeedMetersPerSecond: Double
    public let values: [ReferenceMetric: InterpolatedReferenceValue]
    public var isInterpolated: Bool { lowerRowID != upperRowID }
}

/// Cited spin assumptions for a carry sensitivity calculation. They are NOT measured spin,
/// personal percentiles, or a guaranteed interval. Nil means no published basis is available.
public struct ReferenceSpinAssumption: Sendable {
    public let radiansPerSecond: ClosedRange<Double>
    public let citations: [ReferenceCitation]
    public let rowIDs: [String]
    public var revolutionsPerMinute: ClosedRange<Double> {
        (radiansPerSecond.lowerBound * 60 / (2 * .pi))...(radiansPerSecond.upperBound * 60 / (2 * .pi))
    }
}

public enum ReferenceLaunchData {
    public static let label: LocalizationKey = "Reference — published averages"

    /// Match only a measured or image-measured ball speed. An estimated wrist speed or
    /// user-entered carry must never turn into a measured ball speed through this API.
    public static func match(club: ReferenceClub, population: ReferencePopulation,
                             ballSpeed: ProvenancedValue) -> ReferenceSpeedMatch? {
        guard ballSpeed.unit == "m/s", [.measured, .visionDerived].contains(ballSpeed.provenance),
              let speed = ballSpeed.value, speed.isFinite, speed > 0 else { return nil }
        return interpolate(rows: rows.filter { $0.club == club && $0.population == population },
                           ballSpeedMetersPerSecond: speed)
    }

    /// Linear interpolation within one source/population/club series only; no extrapolation.
    /// Values missing at either endpoint stay missing. The endpoint envelope is retained.
    public static func interpolate(rows candidates: [ReferenceLaunchRow],
                                   ballSpeedMetersPerSecond speed: Double) -> ReferenceSpeedMatch? {
        guard speed.isFinite, speed > 0, let first = candidates.first,
              candidates.allSatisfy({ $0.club == first.club && $0.population == first.population }) else { return nil }
        let sorted = candidates.filter { $0.values[.ballSpeed] != nil }.sorted {
            $0.values[.ballSpeed]!.siValue < $1.values[.ballSpeed]!.siValue
        }
        guard let lowEnd = sorted.first, let highEnd = sorted.last,
              speed >= lowEnd.values[.ballSpeed]!.siValue,
              speed <= highEnd.values[.ballSpeed]!.siValue else { return nil }
        if let exact = sorted.first(where: { abs($0.values[.ballSpeed]!.siValue - speed) < 1e-9 }) {
            let values = exact.values.mapValues {
                InterpolatedReferenceValue(valueSI: $0.siValue,
                    bracket: ReferenceValueBand(lowerSI: $0.siValue, upperSI: $0.siValue, citations: [$0.citation]),
                    isInterpolated: false)
            }
            return ReferenceSpeedMatch(lowerRowID: exact.id, upperRowID: exact.id,
                ballSpeedMetersPerSecond: speed, values: values)
        }
        guard let upperIndex = sorted.firstIndex(where: { $0.values[.ballSpeed]!.siValue > speed }),
              upperIndex > 0 else { return nil }
        let lower = sorted[upperIndex - 1], upper = sorted[upperIndex]
        let x0 = lower.values[.ballSpeed]!.siValue, x1 = upper.values[.ballSpeed]!.siValue
        let fraction = (speed - x0) / (x1 - x0)
        var values: [ReferenceMetric: InterpolatedReferenceValue] = [:]
        for metric in ReferenceMetric.allCases {
            guard let a = lower.values[metric], let b = upper.values[metric],
                  a.citation.sourceID == b.citation.sourceID,
                  a.publishedUnit == b.publishedUnit else { continue }
            values[metric] = InterpolatedReferenceValue(valueSI: a.siValue + fraction * (b.siValue - a.siValue),
                bracket: ReferenceValueBand(lowerSI: min(a.siValue, b.siValue), upperSI: max(a.siValue, b.siValue),
                    citations: [a.citation, b.citation]), isInterpolated: true)
        }
        return ReferenceSpeedMatch(lowerRowID: lower.id, upperRowID: upper.id,
            ballSpeedMetersPerSecond: speed, values: values)
    }

    /// An explicit category lookup prevents a 7-iron row being silently applied to every iron.
    public static func spinAssumption(club: ReferenceClub) -> ReferenceSpinAssumption? {
        let cited = rows.filter { $0.club == club && $0.values[.spin] != nil }
        let values = cited.compactMap { $0.values[.spin] }
        guard let minimum = values.map(\.siValue).min(), let maximum = values.map(\.siValue).max() else { return nil }
        return ReferenceSpinAssumption(radiansPerSecond: minimum...maximum,
            citations: values.map(\.citation), rowIDs: cited.map(\.id))
    }

    /// No recommendations or personal distance predictions. This keeps both cited inputs
    /// together for the app's full-sentence, context-only gapping explanation.
    public static func gappingContext(row: ReferenceLaunchRow) -> (smash: PublishedLaunchValue, launch: PublishedLaunchValue)? {
        guard let smash = row.values[.smashFactor], let launch = row.values[.launch] else { return nil }
        return (smash, launch)
    }
}
