import XCTest
import SwiftData
import SwingLabCore
@testable import SwingLab

final class PersistenceTests: XCTestCase {
    @MainActor func testClubPersistsInSIAndCanBeEdited() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema(SwingLabSchemaV1.models)
        let config = ModelConfiguration("UnitTests", schema: schema, url: directory.appendingPathComponent("test.store"))
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)
        let club = GolfClub(name: "7 iron", category: "Iron")
        club.carryMeters = DistanceUnit.yards.toSI(150)
        context.insert(club)
        try context.save()
        let reader = ModelContext(container)
        let saved = try XCTUnwrap(reader.fetch(FetchDescriptor<GolfClub>()).first)
        XCTAssertEqual(try XCTUnwrap(saved.carryMeters), 137.16, accuracy: 1e-8)
        saved.name = "My 7 iron"
        try reader.save()
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<GolfClub>()).first?.name, "My 7 iron")
    }

    @MainActor func testRoundCascadeAndGroundDistance() throws {
        let schema = Schema(SwingLabSchemaV1.models)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let round = RoundSession(courseName: "Manual course", holeCount: 9)
        let shot = ShotRecord(holeNumber: 1, shotNumber: 1, clubID: nil, clubName: "7 iron", startLatitude: 0, startLongitude: 0, startAccuracyMeters: 5, startedAt: .now)
        XCTAssertNil(shot.groundDisplacementMeters)
        shot.endLatitude = 0; shot.endLongitude = 0.001
        round.shots.append(shot)
        round.holeScores.append(HoleScore(number: 1))
        context.insert(round)
        try context.save()
        XCTAssertEqual(try XCTUnwrap(shot.groundDisplacementMeters), 111.195, accuracy: 0.01)
        context.delete(round)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<ShotRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<HoleScore>()).isEmpty)
    }

    @MainActor func testPreferencesPersistWithoutCouplingLanguageToUnits() {
        let name = "SwingLab.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = AppPreferences(defaults: defaults)
        preferences.distanceUnit = .meters
        preferences.speedUnit = .mph
        preferences.windUnit = .kilometersPerHour
        preferences.languageCode = "ko"
        let restored = AppPreferences(defaults: defaults)
        XCTAssertEqual(restored.languageCode, "ko")
        XCTAssertEqual(restored.distanceUnit, .meters)
        XCTAssertEqual(restored.speedUnit, .mph)
        XCTAssertEqual(restored.windUnit, .kilometersPerHour)
    }

    @MainActor func testClubDraftRejectsInvalidNumbersAndPreservesPrecision() throws {
        let club = GolfClub(name: "7 iron", category: "Iron")
        club.carryMeters = 137.162345
        let draft = ClubDraft(club: club, unit: .yards, locale: Locale(identifier: "de"))
        let validated = try draft.validated(unit: .yards, locale: Locale(identifier: "de"))
        XCTAssertEqual(try XCTUnwrap(validated.carry), 137.162345, accuracy: 1e-10)
        var invalid = draft
        invalid.carry = "nan"
        XCTAssertThrowsError(try invalid.validated(unit: .yards, locale: Locale(identifier: "de")))
    }
}
