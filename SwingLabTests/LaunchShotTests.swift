import XCTest
import SwiftData
import SwingLabCore
@testable import SwingLab

final class LaunchShotTests: XCTestCase {
    private func measurement(speed: Double?, provenance: String = "visionDerived") throws -> LaunchMeasurement {
        let value = speed.map { "\($0)" } ?? "null"
        let json = """
        {"ballSpeed": {"value": \(value), "unit": "m/s", "provenance": "\(provenance)", "confidence": 0.8,
                       "method": "launch.faceOnTrack.v1", "sampleCount": 3},
         "launchAngle": {"value": 0.2793, "unit": "rad", "provenance": "\(provenance)", "confidence": 0.8,
                         "method": "launch.faceOnTrack.v1", "sampleCount": 3},
         "relativeSpeedUncertainty": 0.012, "residualPixels": 0.3,
         "observations": [{"time": 0.004, "center": {"x": 10, "y": 50}}, {"time": 0.008, "center": {"x": 60, "y": 36}},
                          {"time": 0.012, "center": {"x": 110, "y": 22}}]}
        """
        return try JSONDecoder().decode(LaunchMeasurement.self, from: Data(json.utf8))
    }

    @MainActor func testShotKeepsSIValuesAndProvenanceAndRefusesUnavailableLaunches() throws {
        let shot = try XCTUnwrap(LaunchShot(measurement: measurement(speed: 54.2), club: .iron7, source: .liveCamera))
        XCTAssertEqual(shot.ballSpeed.value, 54.2)
        XCTAssertEqual(shot.ballSpeed.unit, "m/s")
        XCTAssertEqual(shot.ballSpeed.provenance, .visionDerived)
        XCTAssertEqual(shot.ballSpeed.sampleCount, 3)
        XCTAssertEqual(try XCTUnwrap(shot.launchAngle.value), 0.2793, accuracy: 1e-12)
        XCTAssertEqual(shot.launchAngle.unit, "rad")
        XCTAssertEqual(shot.referenceClub, .iron7)
        XCTAssertEqual(shot.source, .liveCamera)
        XCTAssertNil(LaunchShot(measurement: try measurement(speed: nil), club: .driver, source: .liveCamera))
        XCTAssertNil(LaunchShot(measurement: try measurement(speed: 60, provenance: "unavailable"), club: .driver, source: .liveCamera))
    }

    /// A V4 store (catalog equipment) opens as V5 with every record intact and accepts launch shots.
    @MainActor func testV4StoreMigratesToV5AndAcceptsLaunchShots() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("V4.store")
        let clubID: UUID, roundID: UUID
        do {
            let schema = Schema(versionedSchema: SwingLabSchemaV4.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration("V4", schema: schema, url: url))
            let context = ModelContext(container)
            let club = SwingLabSchemaV4.GolfClub(name: "Qi10 Max", category: "Driver")
            club.catalogClubID = "taylormade-2024-driver-qi10"
            club.catalogVariant = "Max"
            club.carryMeters = 210
            let round = SwingLabSchemaV4.RoundSession(courseName: "Entered course", holeCount: 18)
            round.holeScores.append(SwingLabSchemaV4.HoleScore(number: 1, par: 4))
            context.insert(club); context.insert(round)
            try context.save()
            clubID = club.id; roundID = round.id
        }

        let schema = Schema(versionedSchema: SwingLabCurrentSchema.self)
        let container = try ModelContainer(for: schema, migrationPlan: SwingLabMigrationPlan.self,
                                           configurations: ModelConfiguration("V4", schema: schema, url: url))
        let context = ModelContext(container)
        let club = try XCTUnwrap(context.fetch(FetchDescriptor<GolfClub>()).first)
        XCTAssertEqual(club.id, clubID)
        XCTAssertEqual(club.catalogClubID, "taylormade-2024-driver-qi10")
        XCTAssertEqual(club.catalogVariant, "Max")
        XCTAssertEqual(club.carryMeters, 210)
        let round = try XCTUnwrap(context.fetch(FetchDescriptor<RoundSession>()).first)
        XCTAssertEqual(round.id, roundID)
        XCTAssertEqual(round.holeScores.first?.par, 4)
        XCTAssertTrue(try context.fetch(FetchDescriptor<LaunchShot>()).isEmpty)

        context.insert(try XCTUnwrap(LaunchShot(measurement: measurement(speed: 66), club: .driver, source: .recordedVideo)))
        try context.save()
        let saved = try ModelContext(container).fetch(FetchDescriptor<LaunchShot>())
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.ballSpeed.value, 66)
        XCTAssertEqual(saved.first?.source, .recordedVideo)
    }
}
