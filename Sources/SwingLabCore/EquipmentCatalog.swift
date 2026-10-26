import Foundation

/// Facts only. Empty optional specification arrays mean the publisher was not verified.
public struct EquipmentCatalog: Codable, Sendable {
    public var version: Int
    public var brands: [CatalogBrand]
    public var clubs: [CatalogClub]
    public var shafts: [CatalogShaft]
    public var hoselSystems: [CatalogHoselSystem]

    public init(version: Int = 1, brands: [CatalogBrand] = [], clubs: [CatalogClub] = [],
                shafts: [CatalogShaft] = [], hoselSystems: [CatalogHoselSystem] = []) {
        self.version = version; self.brands = brands; self.clubs = clubs
        self.shafts = shafts; self.hoselSystems = hoselSystems
    }

    public func search(_ query: String, brandID: String? = nil, category: String? = nil, year: Int? = nil) -> [CatalogClub] {
        let query = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return clubs.filter { club in
            (brandID == nil || club.brandID == brandID) && (category == nil || club.category == category) &&
            (year == nil || club.releaseYear == year) && (query.isEmpty ||
                ([club.brandID, brands.first { $0.id == club.brandID }?.name ?? "", club.model] + club.variants).joined(separator: " ")
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                    .contains(query))
        }.sorted { $0.releaseYear == $1.releaseYear ? $0.model < $1.model : $0.releaseYear > $1.releaseYear }
    }
}

public struct CatalogBrand: Codable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var source: String?
    public var verified: Bool
}

public struct CatalogClub: Codable, Identifiable, Sendable {
    public var id: String
    public var brandID: String
    public var model: String
    public var releaseYear: Int
    /// Same stable category values as the bag's existing persisted category column.
    public var category: String
    public var variants: [String]
    public var availableClubs: [String]
    public var stockLoftsDegrees: [Double]
    public var hoselSystemID: String?
    public var source: String?
    public var verified: Bool
}

public struct CatalogShaft: Codable, Identifiable, Sendable {
    public var id: String
    public var brand: String
    public var model: String
    public var material: String
    public var flexes: [String]
    /// Nominal weight classes, not a claim that every flex has this exact weight.
    public var weightClassesGrams: [Double]
    public var source: String?
    public var verified: Bool
}

public struct CatalogHoselSystem: Codable, Identifiable, Sendable {
    public var id: String
    public var brandID: String
    public var name: String
    public var handedness: String
    public var positions: [CatalogHoselPosition]
    public var source: String?
    public var verified: Bool
}

public struct CatalogHoselPosition: Codable, Identifiable, Sendable {
    public var id: String
    public var label: String
    /// Intermediate marks retain the printed dash and a separate ordinal to disambiguate.
    public var index: Int
    public var loftDeltaDegrees: Double?
    public var lieDeltaDegrees: Double?
    /// Positive = closed, negative = open. nil = not published; never inferred from loft.
    public var faceAngleDegrees: Double?
    public var source: String?
    public var verified: Bool
}

/// Personal configuration: dimensions are stored in SI. Angles explicitly named Degrees
/// are equipment specifications, converted to radians at any typed measurement boundary.
public struct ClubEquipmentConfiguration: Codable, Sendable, Equatable {
    public var shaftMode = "stock"
    public var shaftBrand = ""
    public var shaftWeightKilograms: Double?
    public var shaftTorqueDegrees: Double?
    public var shaftKickPoint = ""
    public var tipTrimmingMeters: Double?
    public var lengthMeters: Double?
    public var swingWeight = ""
    public var grip = ""
    public var lieDegrees: Double?
    public var hoselSystemID: String?
    public var hoselPositionID: String?
    public var baseLoftFromCatalog = false
    public init() {}

    public static func meters(inches: Double) -> Double { inches * 0.0254 }
    public static func inches(meters: Double) -> Double { meters / 0.0254 }
    public static func isQuarterInch(_ inches: Double) -> Bool {
        inches.isFinite && abs(inches * 4 - (inches * 4).rounded()) < 1e-8
    }
    public func effectiveLoft(baseDegrees: Double?, position: CatalogHoselPosition?) -> Double? {
        guard let baseDegrees, baseDegrees.isFinite else { return nil }
        guard hoselPositionID != nil else { return baseDegrees }
        guard let position, position.id == hoselPositionID,
              let delta = position.loftDeltaDegrees, delta.isFinite else { return nil }
        return baseDegrees + delta
    }
}
