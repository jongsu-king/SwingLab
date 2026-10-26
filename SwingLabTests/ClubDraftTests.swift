import XCTest
import SwingLabCore
@testable import SwingLab

final class ClubDraftTests: XCTestCase {
    @MainActor func testHostedAppCatalogUsesExplicitLanguageAndFallback() {
        let suite = "SwingLab.localization." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferences(defaults: defaults)
        preferences.distanceUnit = .meters
        preferences.languageCode = "ko"
        XCTAssertEqual(preferences.text("Settings"), "설정")
        preferences.languageCode = "ja"
        XCTAssertEqual(preferences.text("Settings"), "設定")
        preferences.languageCode = "unsupported"
        XCTAssertEqual(preferences.text("Settings"), "Settings")
        XCTAssertEqual(preferences.distanceUnit, .meters)
    }

    @MainActor func testCommaDecimalAndSignedOffsetConvertAtBoundary() throws {
        var draft = ClubDraft()
        draft.name = "7 iron"
        draft.carry = "150,5"
        draft.lateralMean = "-4,5"
        let saved = try draft.validated(unit: .yards, locale: Locale(identifier: "de"))
        XCTAssertEqual(try XCTUnwrap(saved.carry), 150.5 * 0.9144, accuracy: 1e-10)
        XCTAssertEqual(saved.lateralMean, -4.5 * 0.9144, accuracy: 1e-10)
        XCTAssertNil(saved.total)
        XCTAssertNil(saved.carryDeviation)
    }

    @MainActor func testInvalidDraftCannotPartiallyMutateTheClub() throws {
        let club = GolfClub(name: "Original", category: "Iron")
        club.carryMeters = 140
        var draft = ClubDraft(club: club, unit: .meters, locale: Locale(identifier: "en"))
        draft.name = "Edited"
        draft.carry = "-1"
        XCTAssertThrowsError(try draft.validated(unit: .meters, locale: Locale(identifier: "en")))
        XCTAssertEqual(club.name, "Original")
        XCTAssertEqual(club.carryMeters, 140)
        XCTAssertEqual(draft.name, "Edited")
        XCTAssertEqual(draft.carry, "-1")
    }

    @MainActor func testTotalBelowCarryAndSingularCorrelationAreRejected() {
        var draft = ClubDraft()
        draft.name = "Driver"
        draft.carry = "200"
        draft.total = "190"
        XCTAssertThrowsError(try draft.validated(unit: .meters, locale: Locale(identifier: "en")))
        draft.total = "210"
        for value in ["-1", "1", "inf", "nan", "1e999"] {
            draft.correlation = value
            XCTAssertThrowsError(try draft.validated(unit: .meters, locale: Locale(identifier: "en")))
        }
    }
}
