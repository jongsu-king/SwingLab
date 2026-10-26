import XCTest
import SwiftData
import SwingLabCore
@testable import SwingLab

final class CatalogMigrationTests: XCTestCase {
    @MainActor func testV3ToV4PreservesCustomEquipmentAndAddsOptionalCatalogFields() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Equipment.store")
        let ids = try seedV3(at: url)
        let schema = Schema(versionedSchema: SwingLabCurrentSchema.self)
        let container = try ModelContainer(for: schema, migrationPlan: SwingLabMigrationPlan.self,
            configurations: ModelConfiguration("Equipment", schema: schema, url: url))
        let context = ModelContext(container)
        let club = try XCTUnwrap(context.fetch(FetchDescriptor<GolfClub>()).first)
        XCTAssertEqual(club.id, ids.club)
        XCTAssertEqual(club.name, "My custom iron")
        XCTAssertEqual(club.brand, "Personal brand")
        XCTAssertEqual(club.shaft, "Original shaft")
        XCTAssertEqual(club.flex, "R")
        XCTAssertEqual(club.carryMeters, 143.21)
        XCTAssertNil(club.catalogClubID)
        XCTAssertNil(club.catalogShaftID)
        XCTAssertNil(club.equipmentData)
        XCTAssertNil(club.equipment.lengthMeters)
        let recording = try XCTUnwrap(context.fetch(FetchDescriptor<SwingRecording>()).first)
        XCTAssertEqual(recording.id, ids.recording)
        XCTAssertEqual(recording.clubID, ids.club)
        XCTAssertEqual(recording.practiceSession?.id, ids.session)
        XCTAssertEqual(recording.practiceSession?.recordings.map(\.id), [ids.recording])

        var draft = ClubDraft(club: club, unit: .meters, locale: Locale(identifier: "en"))
        draft.catalogClubID = "titleist-2021-iron-t200"
        draft.catalogVariant = "7"
        draft.catalogShaftID = "nippon-n-s-pro-modus3-tour-120"
        draft.equipment.lengthMeters = ClubEquipmentConfiguration.meters(inches: 37.25)
        draft.equipment.shaftMode = "custom"
        draft.shaftWeight = "114"
        draft.shaftTorque = "1.7"
        draft.tipTrimming = "0.5"
        draft.lie = "62.5"
        draft.equipment.shaftKickPoint = "Mid/High"
        draft.equipment.swingWeight = "D2"
        draft.equipment.grip = "My grip"
        try draft.validated(unit: .meters, locale: Locale(identifier: "en")).apply(to: club)
        try context.save()
        let reader = ModelContext(container)
        let reopened = try XCTUnwrap(reader.fetch(FetchDescriptor<GolfClub>()).first)
        XCTAssertEqual(reopened.catalogClubID, draft.catalogClubID)
        XCTAssertEqual(reopened.catalogVariant, "7")
        XCTAssertEqual(try XCTUnwrap(reopened.equipment.lengthMeters), 0.94615, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(reopened.equipment.shaftWeightKilograms), 0.114, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(reopened.equipment.tipTrimmingMeters), 0.0127, accuracy: 1e-12)
        XCTAssertEqual(reopened.equipment.shaftTorqueDegrees, 1.7)
        XCTAssertEqual(reopened.equipment.swingWeight, "D2")
        XCTAssertEqual(reopened.equipment.grip, "My grip")
        XCTAssertEqual(reopened.carryMeters, 143.21)
    }

    @MainActor func testEquipmentDraftRejectsNonfiniteAndOffStepDimensions() throws {
        var draft = ClubDraft()
        draft.name = "Driver"
        draft.equipment.lengthMeters = ClubEquipmentConfiguration.meters(inches: 45.1)
        XCTAssertThrowsError(try draft.validated(unit: .yards, locale: Locale(identifier: "en")))
        draft.equipment.lengthMeters = ClubEquipmentConfiguration.meters(inches: 45.25)
        draft.shaftWeight = "nan"
        XCTAssertThrowsError(try draft.validated(unit: .yards, locale: Locale(identifier: "en")))
        draft.shaftWeight = "65"
        draft.shaftTorque = "-1"
        XCTAssertThrowsError(try draft.validated(unit: .yards, locale: Locale(identifier: "en")))
        draft.shaftTorque = "3.5"
        draft.lie = "91"
        XCTAssertThrowsError(try draft.validated(unit: .yards, locale: Locale(identifier: "en")))
        draft.lie = "60"
        XCTAssertNoThrow(try draft.validated(unit: .yards, locale: Locale(identifier: "en")))
    }

    @MainActor func testBundledCatalogIsAvailableToTheEditor() {
        XCTAssertEqual(CatalogStore.catalog.brands.count, 23)
        XCTAssertGreaterThan(CatalogStore.catalog.clubs.count, 1000)
        XCTAssertFalse(CatalogStore.catalog.search("QÍ10").isEmpty)
    }

    @MainActor private func seedV3(at url: URL) throws -> (club: UUID, recording: UUID, session: UUID) {
        let schema = Schema(versionedSchema: SwingLabSchemaV3.self)
        let container = try ModelContainer(for: schema,
            configurations: ModelConfiguration("Equipment", schema: schema, url: url))
        let context = ModelContext(container)
        let club = SwingLabSchemaV3.GolfClub(name: "My custom iron", category: "Iron")
        club.brand = "Personal brand"; club.shaft = "Original shaft"; club.flex = "R"; club.carryMeters = 143.21
        let recording = SwingLabSchemaV3.SwingRecording(title: "Practice", videoFileName: "preserved.mov",
            durationSeconds: 2, nominalFrameRate: 120, videoWidth: 1920, videoHeight: 1080)
        recording.clubID = club.id
        let session = SwingLabSchemaV3.PracticeSession(date: recording.createdAt, clubID: club.id)
        context.insert(club); context.insert(session); context.insert(recording)
        recording.practiceSession = session
        try context.save()
        return (club.id, recording.id, session.id)
    }
}
