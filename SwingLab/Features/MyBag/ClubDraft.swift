import Foundation
import SwingLabCore

/// A detached form value keeps incomplete input out of SwiftData until validation succeeds.
struct ClubDraft {
    var name = ""
    var category = ClubCategory.iron.rawValue
    var brand = ""
    var modelName = ""
    var loft = ""
    var shaft = ""
    var flex = ""
    var carry = ""
    var total = ""
    var carryDeviation = ""
    var lateralDeviation = ""
    var lateralMean = ""
    var correlation = ""
    var notes = ""
    var catalogClubID: String?
    var catalogVariant: String?
    var catalogShaftID: String?
    var equipment = ClubEquipmentConfiguration()
    var shaftWeight = ""
    var shaftTorque = ""
    var tipTrimming = ""
    var lie = ""
    private var originalInputs: [LocalizationKey: String] = [:]
    private var originalValues: [LocalizationKey: Double] = [:]

    init() {}

    init(club: GolfClub, unit: DistanceUnit, locale: Locale) {
        name = club.name
        category = club.category
        brand = club.brand
        modelName = club.modelName
        shaft = club.shaft
        flex = club.flex
        notes = club.notes
        catalogClubID = club.catalogClubID
        catalogVariant = club.catalogVariant
        catalogShaftID = club.catalogShaftID
        equipment = club.equipment
        func number(_ value: Double?) -> String {
            guard let value else { return "" }
            return value.formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...2)))
        }
        func distance(_ value: Double?) -> String {
            number(value.map { unit.fromSI($0) })
        }
        shaftWeight = number(equipment.shaftWeightKilograms.map { $0 * 1000 })
        shaftTorque = number(equipment.shaftTorqueDegrees)
        tipTrimming = number(equipment.tipTrimmingMeters.map(ClubEquipmentConfiguration.inches))
        lie = number(equipment.lieDegrees)
        loft = number(club.loftDegrees)
        carry = distance(club.carryMeters)
        total = distance(club.totalMeters)
        carryDeviation = distance(club.carryStdDevMeters)
        lateralDeviation = distance(club.lateralStdDevMeters)
        lateralMean = distance(club.lateralMeanMeters)
        correlation = number(club.dispersionCorrelation)
        originalInputs = ["Loft": loft, "Average carry": carry, "Average total distance": total,
                          "Carry standard deviation": carryDeviation, "Lateral standard deviation": lateralDeviation,
                          "Typical lateral offset": lateralMean, "Carry / lateral correlation": correlation]
        let values: [LocalizationKey: Double?] = ["Loft": club.loftDegrees, "Average carry": club.carryMeters,
            "Average total distance": club.totalMeters, "Carry standard deviation": club.carryStdDevMeters,
            "Lateral standard deviation": club.lateralStdDevMeters, "Typical lateral offset": club.lateralMeanMeters,
            "Carry / lateral correlation": club.dispersionCorrelation]
        originalValues = values.compactMapValues { $0 }
    }

    func validated(unit: DistanceUnit, locale: Locale) throws -> ValidatedClubDraft {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ClubInputError(field: "Club name", message: "Enter a name for this club.")
        }
        func number(_ input: String, field: LocalizationKey, signed: Bool = false) throws -> Double? {
            if originalInputs[field] == input { return originalValues[field] }
            let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !input.isEmpty else { return nil }
            // Decimal entry uses the selected language's separator; grouping is intentionally unsupported.
            let normalized = input.replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")
            guard let value = Double(normalized), value.isFinite, signed || value >= 0 else {
                throw ClubInputError(field: field, message: signed ? "Enter a valid finite number." : "Enter a valid number of zero or greater.")
            }
            return value
        }
        func meters(_ input: String, field: LocalizationKey, signed: Bool = false) throws -> Double? {
            if originalInputs[field] == input { return originalValues[field] }
            return try number(input, field: field, signed: signed).map { unit.toSI($0) }
        }
        let loftValue = try number(loft, field: "Loft")
        if let loftValue, loftValue > 90 {
            throw ClubInputError(field: "Loft", message: "Enter an angle between 0 and 90 degrees.")
        }
        let carryValue = try meters(carry, field: "Average carry")
        let totalValue = try meters(total, field: "Average total distance")
        if let carryValue, let totalValue, totalValue < carryValue {
            throw ClubInputError(field: "Average total distance", message: "Total distance must be at least the carry distance.")
        }
        let correlationValue = try number(correlation, field: "Carry / lateral correlation", signed: true) ?? 0
        guard abs(correlationValue) < 1 else {
            throw ClubInputError(field: "Carry / lateral correlation", message: "Correlation must be greater than −1 and less than 1.")
        }
        var configuration = equipment
        configuration.shaftWeightKilograms = try number(shaftWeight, field: "Shaft weight").map { $0 / 1000 }
        configuration.shaftTorqueDegrees = try number(shaftTorque, field: "Shaft torque")
        configuration.tipTrimmingMeters = try number(tipTrimming, field: "Tip trimming").map { ClubEquipmentConfiguration.meters(inches: $0) }
        configuration.lieDegrees = try number(lie, field: "Lie angle")
        if let length = configuration.lengthMeters,
           !(length.isFinite && length > 0 && ClubEquipmentConfiguration.isQuarterInch(ClubEquipmentConfiguration.inches(meters: length))) {
            throw ClubInputError(field: "Club length", message: "Use quarter-inch steps.")
        }
        if let lie = configuration.lieDegrees, lie > 90 {
            throw ClubInputError(field: "Lie angle", message: "Enter an angle between 0 and 90 degrees.")
        }
        return try ValidatedClubDraft(
            name: trimmedName, category: category, brand: brand, modelName: modelName,
            loft: loftValue, shaft: shaft, flex: flex, carry: carryValue, total: totalValue,
            carryDeviation: meters(carryDeviation, field: "Carry standard deviation"),
            lateralDeviation: meters(lateralDeviation, field: "Lateral standard deviation"),
            lateralMean: meters(lateralMean, field: "Typical lateral offset", signed: true) ?? 0,
            correlation: correlationValue, notes: notes, catalogClubID: catalogClubID,
            catalogVariant: catalogVariant, catalogShaftID: catalogShaftID, equipment: configuration
        )
    }
}

struct ClubInputError: Error {
    var field: LocalizationKey
    var message: LocalizationKey
}

struct ValidatedClubDraft {
    var name: String
    var category: String
    var brand: String
    var modelName: String
    var loft: Double?
    var shaft: String
    var flex: String
    var carry: Double?
    var total: Double?
    var carryDeviation: Double?
    var lateralDeviation: Double?
    var lateralMean: Double
    var correlation: Double
    var notes: String
    var catalogClubID: String?
    var catalogVariant: String?
    var catalogShaftID: String?
    var equipment: ClubEquipmentConfiguration

    func apply(to club: GolfClub) {
        club.catalogClubID = catalogClubID
        club.catalogVariant = catalogVariant
        club.catalogShaftID = catalogShaftID
        club.equipment = equipment
        club.name = name
        club.category = category
        club.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        club.modelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        club.loftDegrees = loft
        club.shaft = shaft.trimmingCharacters(in: .whitespacesAndNewlines)
        club.flex = flex.trimmingCharacters(in: .whitespacesAndNewlines)
        club.carryMeters = carry
        club.totalMeters = total
        club.carryStdDevMeters = carryDeviation
        club.lateralStdDevMeters = lateralDeviation
        club.lateralMeanMeters = lateralMean
        club.dispersionCorrelation = correlation
        club.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
