import XCTest
@testable import SwingLabCore

final class CourseGeometryTests: XCTestCase {
    func testSphericalProjectionRoundTripIncludingDateline() {
        for origin in [GeoCoordinate(latitude: 37.5, longitude: 127), .init(latitude: 20, longitude: 179.999)] {
            for bearing in [0.0, 37, 180, 290] {
                let point = Geo.project(origin: origin, bearingDegrees: bearing, forward: 210, right: -28)
                let restored = Geo.unproject(point, origin: origin, bearingDegrees: bearing)
                XCTAssertEqual(restored.forward, 210, accuracy: 1e-6)
                XCTAssertEqual(restored.right, -28, accuracy: 1e-6)
            }
        }
    }
    func testRectangleProbabilityAgainstAnalyticGaussian() throws {
        let distribution = try GaussianDispersion(meanCarry: 150, meanLateral: 0, carrySD: 10, lateralSD: 5, correlation: 0)
        let rectangle = [PlanePoint(forward: 140, right: -5), .init(forward: 160, right: -5), .init(forward: 160, right: 5), .init(forward: 140, right: 5)]
        let probability = try XCTUnwrap(distribution.probability(in: rectangle, sampleCount: 65536))
        XCTAssertEqual(probability, pow(erf(1 / sqrt(2)), 2), accuracy: 0.002)
    }
    func testOSMFixtureReadsEverySupportedTagAndRejectsOpenPolygon() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/overpass-golf.json")
        let parsed = try OSMCourseParser.parse(Data(contentsOf: file))
        XCTAssertEqual(parsed.areas.count, 8)
        XCTAssertEqual(parsed.holes.count, 1)
        XCTAssertEqual(parsed.holes[0].number, 1)
        XCTAssertEqual(parsed.holes[0].par, 4)
        XCTAssertEqual(parsed.skippedElements, 1)
        XCTAssertTrue(parsed.areas.allSatisfy { $0.isValid && $0.sourceURL != nil && $0.provenance == .estimated })
        XCTAssertEqual(parsed.areas.filter { $0.kind == .water }.count, 3)
    }
    func testInvalidAndExcludedPolygonGeometry() throws {
        let origin = GeoCoordinate(latitude: 0, longitude: 0)
        func ring(_ values: [(Double, Double)]) -> [GeoCoordinate] {
            values.map { Geo.project(origin: origin, bearingDegrees: 0, forward: $0.0, right: $0.1) }
        }
        let distribution = try GaussianDispersion(meanCarry: 150, meanLateral: 0, carrySD: 10, lateralSD: 5, correlation: 0)
        let outer = ring([(100, -40), (200, -40), (200, 40), (100, 40)])
        let inner = ring([(140, -5), (160, -5), (160, 5), (140, 5)])
        let area = CourseArea(kind: .water, vertices: outer, holes: [inner])
        XCTAssertTrue(area.isValid)
        XCTAssertEqual(try XCTUnwrap(area.probability(distribution: distribution, origin: origin, bearingDegrees: 0, sampleCount: 65536)),
                       1 - pow(erf(1 / sqrt(2)), 2), accuracy: 0.002)
        XCTAssertFalse(CourseArea(kind: .water, vertices: ring([(0, 0), (10, 10), (0, 10), (10, 0)])).isValid)
        XCTAssertFalse(CourseArea(kind: .water, vertices: outer, holes: [inner, inner]).isValid)
        XCTAssertFalse(CourseArea(kind: .water, vertices: outer, holes: [ring([(0, 0), (1, 0), (1, 1)])]).isValid)
    }
    func testAimMovesAwayFromExistingWaterAndMissingGeometryHasNoRiskClaim() throws {
        let origin = GeoCoordinate(latitude: 0, longitude: 0)
        let target = Geo.project(origin: origin, bearingDegrees: 0, forward: 150, right: 0)
        let water = CourseArea(kind: .water, vertices: [(120.0, 0.0), (180, 0), (180, 60), (120, 60)].map {
            Geo.project(origin: origin, bearingDegrees: 0, forward: $0.0, right: $0.1)
        })
        let club = AimClubProfile(id: UUID(), carry: 150, total: 165, forwardSD: 8, lateralSD: 8)
        let result = try XCTUnwrap(CaddieAimSearch.recommend(profiles: [club], origin: origin, target: target, areas: [water]))
        XCTAssertLessThan(result.recommended.aimOffsetMeters, -2)
        XCTAssertLessThan(result.recommended.hazards[0].probability, 0.2)
        let without = try XCTUnwrap(CaddieAimSearch.recommend(profiles: [club], origin: origin, target: target, areas: []))
        XCTAssertEqual(without.recommended.aimOffsetMeters, 0)
        XCTAssertTrue(without.recommended.hazards.isEmpty)
        XCTAssertNil(CaddieAimSearch.recommend(profiles: [.init(id: UUID(), carry: 150, total: nil, forwardSD: 8, lateralSD: 8)], origin: origin, target: target, areas: [], shot: .tee))
        let tee = try XCTUnwrap(CaddieAimSearch.recommend(profiles: [club], origin: origin, target: target, areas: [], shot: .tee))
        XCTAssertEqual(Geo.distance(from: origin, to: tee.recommended.expectedLanding), 165, accuracy: 0.001)
    }
}
