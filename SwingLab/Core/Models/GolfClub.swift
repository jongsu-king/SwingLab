import Foundation
import SwiftData

/// Distances are stored in meters. Values are entered by the golfer, not measured by a sensor.
@Model
final class GolfClub {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var brand: String
    var modelName: String
    var loftDegrees: Double?
    var shaft: String
    var flex: String
    var carryMeters: Double?
    var totalMeters: Double?
    var carryStdDevMeters: Double?
    var lateralStdDevMeters: Double?
    var lateralMeanMeters: Double
    var dispersionCorrelation: Double
    var notes: String
    var createdAt: Date

    init(name: String, category: String) {
        id = UUID()
        self.name = name
        self.category = category
        brand = ""
        modelName = ""
        loftDegrees = nil
        shaft = ""
        flex = ""
        carryMeters = nil
        totalMeters = nil
        carryStdDevMeters = nil
        lateralStdDevMeters = nil
        lateralMeanMeters = 0
        dispersionCorrelation = 0
        notes = ""
        createdAt = .now
    }
}

enum ClubCategory: String, CaseIterable, Identifiable {
    case driver = "Driver"
    case fairwayWood = "Fairway Wood"
    case hybrid = "Hybrid"
    case utilityIron = "Utility Iron"
    case iron = "Iron"
    case wedge = "Wedge"
    case putter = "Putter"

    var id: String { rawValue }
}
