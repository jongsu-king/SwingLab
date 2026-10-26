import XCTest
@testable import SwingLabCore

final class EquipmentCatalogTests: XCTestCase {
    private func catalog() throws -> EquipmentCatalog {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(EquipmentCatalog.self,
            from: Data(contentsOf: root.appendingPathComponent("SwingLab/Resources/Catalog/equipment-catalog.json")))
    }
    func testCatalogSearchIgnoresCaseAndDiacriticsAndSortsNewestFirst() throws {
        let data = try catalog()
        XCTAssertEqual(data.search("QÍ10").map(\.id), data.search("qi10").map(\.id))
        XCTAssertFalse(data.search("qi10").isEmpty)
        let results = data.search("", brandID: "titleist", category: "Driver")
        XCTAssertEqual(results.map(\.releaseYear), results.map(\.releaseYear).sorted(by: >))
        XCTAssertTrue(data.search("qi10", brandID: "titleist").isEmpty)
    }
    func testEquipmentDimensionsAreSIAndLengthUsesQuarterInches() {
        XCTAssertEqual(ClubEquipmentConfiguration.meters(inches: 45.25), 1.14935, accuracy: 1e-12)
        XCTAssertEqual(ClubEquipmentConfiguration.inches(meters: 1.14935), 45.25, accuracy: 1e-10)
        XCTAssertTrue(ClubEquipmentConfiguration.isQuarterInch(37.25))
        XCTAssertFalse(ClubEquipmentConfiguration.isQuarterInch(37.2))
        XCTAssertFalse(ClubEquipmentConfiguration.isQuarterInch(.nan))
    }
    func testEffectiveLoftRequiresTheSelectedPublishedPosition() throws {
        let catalog = try catalog()
        let system = try XCTUnwrap(catalog.hoselSystems.first { $0.id == "titleist-surefit-driver-rh" })
        let position = try XCTUnwrap(system.positions.first { $0.label == "A3" })
        var config = ClubEquipmentConfiguration()
        config.hoselSystemID = system.id
        config.hoselPositionID = position.id
        XCTAssertEqual(try XCTUnwrap(config.effectiveLoft(baseDegrees: 9, position: position)), 10.5, accuracy: 1e-10)
        XCTAssertNil(config.effectiveLoft(baseDegrees: 9, position: nil))
        XCTAssertNil(config.effectiveLoft(baseDegrees: nil, position: position))
        XCTAssertNil(config.effectiveLoft(baseDegrees: .nan, position: position))
        config.hoselPositionID = "unrecognized"
        XCTAssertNil(config.effectiveLoft(baseDegrees: 9, position: position))
    }
    func testSourcedAdapterTablesHaveUniqueStablePositions() throws {
        let data = try catalog()
        for system in data.hoselSystems where system.verified {
            XCTAssertNotNil(system.source)
            XCTAssertEqual(Set(system.positions.map(\.id)).count, system.positions.count)
            for position in system.positions {
                XCTAssertTrue(position.verified)
                XCTAssertNotNil(position.source)
                XCTAssertNotNil(position.loftDeltaDegrees)
            }
        }
        XCTAssertEqual(data.hoselSystems.first { $0.id == "titleist-surefit-driver-rh" }?.positions.count, 16)
        XCTAssertEqual(data.hoselSystems.first { $0.id == "taylormade-m5-4-degree-rh" }?.positions.count, 12)
        XCTAssertEqual(data.hoselSystems.first { $0.id == "callaway-optifit2-rh" }?.positions.count, 8)
    }
}
