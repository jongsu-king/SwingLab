import XCTest
@testable import SwingLabCore

final class ReferenceLaunchDataTests: XCTestCase {
    func testEveryPublishedValueHasAnAuditableSourceAndCompatibleUnit() throws {
        let rows = ReferenceLaunchData.rows, sources = ReferenceLaunchData.sources
        XCTAssertEqual(Set(rows.map(\.id)).count, rows.count)
        XCTAssertEqual(Set(sources.map(\.id)).count, sources.count)
        XCTAssertEqual(rows.count, 70)
        for row in rows {
            XCTAssertFalse(row.values.isEmpty)
            if let n = row.sampleCount { XCTAssertGreaterThan(n, 0) }
            for (metric, value) in row.values {
                let source = try XCTUnwrap(sources.first { $0.id == value.citation.sourceID })
                XCTAssertEqual(source.url.scheme, "https")
                XCTAssertFalse(try XCTUnwrap(source.url.host).isEmpty)
                XCTAssertFalse(value.citation.locator.isEmpty)
                XCTAssertEqual(value.citation.publicationYear, source.publicationYear)
                XCTAssertEqual(value.citation.dataYear, source.dataYear)
                XCTAssertTrue(value.publishedValue.isFinite)
                if let sd = value.publishedStandardDeviation { XCTAssertTrue(sd.isFinite && sd >= 0) }
                switch metric {
                case .clubSpeed, .ballSpeed:
                    XCTAssertEqual(value.publishedUnit, .mph)
                    XCTAssertTrue((1...100).contains(value.siValue))
                case .smashFactor:
                    XCTAssertEqual(value.publishedUnit, .ratio)
                    XCTAssertTrue((1...1.6).contains(value.siValue))
                case .launch:
                    XCTAssertEqual(value.publishedUnit, .degrees)
                    XCTAssertTrue((0...(.pi / 2)).contains(value.siValue))
                case .spin:
                    XCTAssertEqual(value.publishedUnit, .rpm)
                    XCTAssertTrue((0...1600).contains(value.siValue))
                case .carry, .apex:
                    XCTAssertEqual(value.publishedUnit, .yards)
                    XCTAssertTrue((0...350).contains(value.siValue))
                }
            }
        }
    }

    func testTranscriptionAnchorsAndOriginalRoundingRemainSeparateFromConversions() throws {
        let current = try row("trackman.pga.2023.driver")
        XCTAssertEqual(current.values[.ballSpeed]?.publishedValue, 171)
        XCTAssertEqual(try XCTUnwrap(current.values[.ballSpeed]?.siValue), 76.44384, accuracy: 1e-9)
        XCTAssertEqual(current.values[.spin]?.publishedValue, 2545)
        XCTAssertEqual(try XCTUnwrap(current.values[.launch]?.siValue), 10.4 * .pi / 180, accuracy: 1e-10)
        XCTAssertEqual(try XCTUnwrap(current.values[.carry]?.siValue), 282 * 0.9144, accuracy: 1e-10)
        XCTAssertEqual(current.values[.carry]?.citation.dataYear, 2023)
        XCTAssertEqual(current.values[.carry]?.citation.publicationYear, 2024)
        let old = try row("trackman.pga.older.driver")
        XCTAssertEqual(old.values[.ballSpeed]?.publishedValue, 167)
        XCTAssertEqual(old.values[.carry]?.publishedValue, 275)
        XCTAssertNil(old.values[.carry]?.citation.dataYear)
        XCTAssertNil(old.values[.carry]?.citation.publicationYear)
        XCTAssertEqual(try row("trackman.lpga.older.wood7").values[.carry]?.publishedValue, 174)
        XCTAssertEqual(try row("trackman.lpga.older.iron7").values[.launch]?.publishedValue, 19.0)
        // Use the original printed LPGA value even when it differs sharply from older data.
        XCTAssertEqual(try row("trackman.lpga.2023.wood3").values[.spin]?.publishedValue, 2595)
        let missing = try row("usga.r22-01.usgaMale.driver.0")
        XCTAssertNil(missing.values[.apex])
        XCTAssertEqual(missing.values[.spin]?.publishedStandardDeviation, 1120)
        let surface = try row("usga.di.2023.recreationalGrass.iron7")
        XCTAssertEqual(surface.values[.smashFactor]?.publishedValue, 1.33)
        XCTAssertNil(surface.values[.carry]) // DI hitting distance is not carry.
    }

    func testLinearInterpolationRetainsBothCitationsAndDoesNotManufactureMissingValues() throws {
        let a = try row("usga.r22-01.usgaFemale.iron6.4")
        let b = try row("usga.r22-01.usgaFemale.iron6.3")
        let speed = (71.2 + (77.6 - 71.2) * 0.25) * 0.44704
        let result = try XCTUnwrap(ReferenceLaunchData.interpolate(rows: [b, a], ballSpeedMetersPerSecond: speed))
        XCTAssertTrue(result.isInterpolated)
        XCTAssertEqual(result.lowerRowID, a.id)
        XCTAssertEqual(result.upperRowID, b.id)
        let carry = try XCTUnwrap(result.values[.carry])
        XCTAssertEqual(carry.valueSI, (64.5 + (75.1 - 64.5) * 0.25) * 0.9144, accuracy: 1e-9)
        XCTAssertEqual(carry.bracket.lowerSI, 64.5 * 0.9144, accuracy: 1e-9)
        XCTAssertEqual(carry.bracket.upperSI, 75.1 * 0.9144, accuracy: 1e-9)
        XCTAssertEqual(carry.bracket.citations.count, 2)
        let male = ReferenceLaunchData.rows.filter { $0.population == .usgaMale && $0.club == .driver }
        let upperMatch = try XCTUnwrap(ReferenceLaunchData.interpolate(rows: male, ballSpeedMetersPerSecond: 160 * 0.44704))
        XCTAssertNil(upperMatch.values[.apex])
    }

    func testExactEndpointsDoNotClaimInterpolation() throws {
        let row = try row("trackman.pga.2023.iron7")
        let speed = try XCTUnwrap(row.values[.ballSpeed]?.siValue)
        let result = try XCTUnwrap(ReferenceLaunchData.interpolate(rows: [row], ballSpeedMetersPerSecond: speed))
        XCTAssertFalse(result.isInterpolated)
        XCTAssertEqual(result.values[.carry]?.valueSI, row.values[.carry]?.siValue)
        XCTAssertEqual(result.values[.carry]?.bracket.citations.count, 1)
    }

    func testNoExtrapolationCrossPopulationOrInvalidSpeed() throws {
        let a = try row("usga.r22-01.usgaFemale.iron6.4")
        let b = try row("usga.r22-01.usgaFemale.iron6.3")
        for speed in [Double.nan, .infinity, -1, 0, 1, 100] {
            XCTAssertNil(ReferenceLaunchData.interpolate(rows: [a,b], ballSpeedMetersPerSecond: speed))
        }
        XCTAssertNil(ReferenceLaunchData.interpolate(rows: [], ballSpeedMetersPerSecond: 40))
        XCTAssertNil(ReferenceLaunchData.interpolate(rows: [a, try row("trackman.lpga.2023.iron6")], ballSpeedMetersPerSecond: 40))
        XCTAssertNil(ReferenceLaunchData.interpolate(rows: [a, try row("usga.r22-01.usgaFemale.driver.3")], ballSpeedMetersPerSecond: 40))
    }

    func testPersonalMatchingRequiresActualBallSpeedEvidence() {
        for origin in [Provenance.estimated, .simulated, .userEntered, .audioDerived, .unavailable] {
            let value = ProvenancedValue(value: 50, unit: "m/s", provenance: origin, method: "test")
            XCTAssertNil(ReferenceLaunchData.match(club: .iron6, population: .usgaMale, ballSpeed: value))
        }
        for origin in [Provenance.measured, .visionDerived] {
            let value = ProvenancedValue(value: 50, unit: "m/s", provenance: origin, method: "test")
            XCTAssertNotNil(ReferenceLaunchData.match(club: .iron6, population: .usgaMale, ballSpeed: value))
        }
        let wrongUnit = ProvenancedValue(value: 50, unit: "mph", provenance: .measured, method: "test")
        XCTAssertNil(ReferenceLaunchData.match(club: .iron6, population: .usgaMale, ballSpeed: wrongUnit))
    }

    func testSpinAssumptionsAreOnlyEnvelopeOfPublishedMeans() throws {
        let driver = try XCTUnwrap(ReferenceLaunchData.spinAssumption(club: .driver))
        XCTAssertEqual(driver.revolutionsPerMinute.lowerBound, 2259, accuracy: 1e-8)
        XCTAssertEqual(driver.revolutionsPerMinute.upperBound, 3839, accuracy: 1e-8)
        XCTAssertEqual(driver.citations.count, driver.rowIDs.count)
        XCTAssertFalse(driver.rowIDs.isEmpty)
        for id in driver.rowIDs {
            let mean = try XCTUnwrap(try row(id).values[.spin]?.siValue)
            XCTAssertTrue(driver.radiansPerSecond.contains(mean))
        }
        let iron = try XCTUnwrap(ReferenceLaunchData.spinAssumption(club: .iron7))
        XCTAssertEqual(iron.revolutionsPerMinute.lowerBound, 6630, accuracy: 1e-8)
        XCTAssertEqual(iron.revolutionsPerMinute.upperBound, 7124, accuracy: 1e-8)
    }

    private func row(_ id: String) throws -> ReferenceLaunchRow {
        try XCTUnwrap(ReferenceLaunchData.rows.first { $0.id == id })
    }
}
