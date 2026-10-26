#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SwingLabCore

final class UnitsTests: XCTestCase {
    func testIndependentUnitsRoundTrip() {
        XCTAssertEqual(DistanceUnit.yards.toSI(100), 91.44, accuracy: 1e-10)
        for unit in DistanceUnit.allCases { XCTAssertEqual(unit.toSI(unit.fromSI(187.42)), 187.42, accuracy: 1e-10) }
        for unit in SpeedUnit.allCases { XCTAssertEqual(unit.toSI(unit.fromSI(72)), 72, accuracy: 1e-10) }
        XCTAssertEqual(SpeedUnit.mph.toSI(100), 44.704, accuracy: 1e-10)
        XCTAssertEqual(TemperatureUnit.fahrenheit.toSI(32), 273.15, accuracy: 1e-10)
        XCTAssertEqual(TemperatureUnit.celsius.fromSI(273.15), 0, accuracy: 1e-10)
        for unit in TemperatureUnit.allCases { XCTAssertEqual(unit.toSI(unit.fromSI(295)), 295, accuracy: 1e-10) }
    }
    func testLanguageFallbackAndRegionalMatching() {
        XCTAssertEqual(LanguageResolver.resolve(selection: "system", preferred: ["ko-KR"]), "ko")
        XCTAssertEqual(LanguageResolver.resolve(selection: "system", preferred: ["zh-TW"]), "zh-Hant")
        XCTAssertEqual(LanguageResolver.resolve(selection: "system", preferred: ["zh-Hans-CN"]), "zh-Hans")
        XCTAssertEqual(LanguageResolver.resolve(selection: "system", preferred: ["pt-PT"]), "pt-BR")
        XCTAssertEqual(LanguageResolver.resolve(selection: "system", preferred: ["ar", "fr-CA"]), "fr")
        XCTAssertEqual(LanguageResolver.resolve(selection: "system", preferred: ["ar"]), "en")
        XCTAssertEqual(LanguageResolver.resolve(selection: "ja", preferred: ["ko"]), "ja")
        XCTAssertEqual(LanguageResolver.resolve(selection: "unsupported", preferred: ["ko"]), "en")
    }
}
final class GeographyTests: XCTestCase {
    let origin = GeoCoordinate(latitude: 37.5, longitude: 127)
    func testIdentityAndKnownDistance() {
        XCTAssertEqual(Geo.distance(from: origin, to: origin), 0)
        XCTAssertEqual(Geo.distance(from: .init(latitude: 0, longitude: 0), to: .init(latitude: 0, longitude: 1)), 111195.08, accuracy: 0.02)
    }
    func testProjectionAndBearing() {
        for bearing in [0.0, 45, 90, 180, 270, 359] {
            let point = Geo.destination(from: origin, bearingDegrees: bearing, distanceMeters: 185)
            XCTAssertEqual(Geo.distance(from: origin, to: point), 185, accuracy: 1e-6)
            XCTAssertEqual(Geo.bearing(from: origin, to: point), bearing, accuracy: 1e-6)
        }
        let point = Geo.project(origin: origin, bearingDegrees: 0, forward: 0, right: 100)
        XCTAssertEqual(Geo.bearing(from: origin, to: point), 90, accuracy: 1e-6)
    }
    func testDateLineAndInvalidLocation() {
        let point = Geo.destination(from: .init(latitude: 0, longitude: 179.999), bearingDegrees: 90, distanceMeters: 1000)
        XCTAssertTrue(point.isValid)
        XCTAssertLessThan(point.longitude, 0)
        XCTAssertTrue(Geo.distance(from: origin, to: .init(latitude: 91, longitude: 0)).isNaN)
    }
}
final class DispersionTests: XCTestCase {
    func testProbabilityEllipseHasCorrectMassRadius() throws {
        let model = try GaussianDispersion(meanCarry: 150, meanLateral: -5, carrySD: 12, lateralSD: 8, correlation: 0.6)
        for mass in [0.5, 0.8, 0.95] {
            let points = model.ellipse(probability: mass)
            XCTAssertEqual(points.count, 73)
            for p in points { XCTAssertEqual(model.squaredMahalanobisDistance(p), -2 * log(1 - mass), accuracy: 1e-9) }
            let computed = try XCTUnwrap(model.probability(in: points))
            XCTAssertEqual(computed, mass, accuracy: 0.015)
        }
    }
    func testHazardHalfPlaneAndMissingGeometry() throws {
        let model = try GaussianDispersion(meanCarry: 150, meanLateral: 0, carrySD: 10, lateralSD: 10, correlation: 0)
        let hazard = [PlanePoint(forward: -1000, right: 0), .init(forward: 1000, right: 0), .init(forward: 1000, right: 1000), .init(forward: -1000, right: 1000)]
        XCTAssertEqual(try XCTUnwrap(model.probability(in: hazard)), 0.5, accuracy: 0.005)
        XCTAssertNil(model.probability(in: []))
    }
    func testInvalidDistributionRejected() {
        for correlation in [1.0, -1, .nan] {
            XCTAssertThrowsError(try GaussianDispersion(meanCarry: 150, meanLateral: 0, carrySD: 10, lateralSD: 10, correlation: correlation))
        }
        XCTAssertThrowsError(try GaussianDispersion(meanCarry: 150, meanLateral: 0, carrySD: 0, lateralSD: 10, correlation: 0))
        XCTAssertThrowsError(try GaussianDispersion(meanCarry: .infinity, meanLateral: 0, carrySD: 10, lateralSD: 10, correlation: 0))
    }
}
final class TimingAndGeometryTests: XCTestCase {
    func testInterruptedMediaDeletionRecovery() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let library = root.appendingPathComponent("SwingVideos")
        let staged = root.appendingPathComponent("SwingVideos.deleted-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("saved".utf8).write(to: staged.appendingPathComponent("kept.mov"))
        try Data("deleted".utf8).write(to: staged.appendingPathComponent("removed.mov"))
        try MediaDeletionRecovery.reconcile(library: library, referencedNames: ["kept.mov"])
        XCTAssertEqual(try Data(contentsOf: library.appendingPathComponent("kept.mov")), Data("saved".utf8))
        XCTAssertTrue(!FileManager.default.fileExists(atPath: staged.path))
        XCTAssertTrue(!FileManager.default.fileExists(atPath: library.appendingPathComponent("removed.mov").path))
        let singleStage = library.appendingPathComponent(".delete-" + UUID().uuidString + "-kept.mov")
        try FileManager.default.moveItem(at: library.appendingPathComponent("kept.mov"), to: singleStage)
        try MediaDeletionRecovery.reconcile(library: library, referencedNames: ["kept.mov"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: library.appendingPathComponent("kept.mov").path))
        let unrelated = root.appendingPathComponent("SwingVideos.deleted-unrelated")
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: true)
        try MediaDeletionRecovery.reconcile(library: library, referencedNames: [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: library.appendingPathComponent("kept.mov").path))
    }
    func testExplainableClubRankingChangesWithRiskPreference() {
        let precise = ClubProfile(id: UUID(), carry: 140, lateralMean: 0, carrySD: 3, lateralSD: 3)
        let longer = ClubProfile(id: UUID(), carry: 150, lateralMean: 0, carrySD: 7, lateralSD: 7)
        let conservative = RecommendationEngine.rank(profiles: [precise, longer], targetDistance: 150, varianceWeight: 2)
        let aggressive = RecommendationEngine.rank(profiles: [precise, longer], targetDistance: 150, varianceWeight: 0.5)
        XCTAssertEqual(conservative.first?.id, precise.id)
        XCTAssertEqual(aggressive.first?.id, longer.id)
        XCTAssertTrue(RecommendationEngine.rank(profiles: [precise], targetDistance: .nan, varianceWeight: 1).isEmpty)
        let missing = ClubProfile(id: UUID(), carry: 150, lateralMean: 0, carrySD: 0, lateralSD: 0)
        XCTAssertTrue(RecommendationEngine.rank(profiles: [missing], targetDistance: 150, varianceWeight: 1).isEmpty)
    }
    func testTempoUsesActualSeconds() throws {
        let timing = try SwingTiming(address: 1.25, top: 2.15, impact: 2.45)
        XCTAssertEqual(timing.backswing, 0.9, accuracy: 1e-10)
        XCTAssertEqual(timing.downswing, 0.3, accuracy: 1e-10)
        XCTAssertEqual(timing.tempo, 3, accuracy: 1e-10)
        XCTAssertEqual(timing.total, 1.2, accuracy: 1e-10)
    }
    func testInvalidTimingRejected() {
        for times in [(1.0, 1.0, 2.0), (-1.0, 2, 3), (0.0, 2, 1), (0.0, 1, Double.nan)] {
            XCTAssertThrowsError(try SwingTiming(address: times.0, top: times.1, impact: times.2))
        }
    }
    func testProjectedAngleMissingJointHandling() throws {
        let angle = Geometry.jointAngle(a: .init(forward: 1, right: 0), vertex: .init(forward: 0, right: 0), b: .init(forward: 0, right: 1))
        XCTAssertEqual(try XCTUnwrap(angle), 90, accuracy: 1e-10)
        XCTAssertNil(Geometry.jointAngle(a: .init(forward: 0, right: 0), vertex: .init(forward: 0, right: 0), b: .init(forward: 0, right: 1)))
    }
}
