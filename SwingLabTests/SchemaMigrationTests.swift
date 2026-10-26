import XCTest
import SwiftData
import SwingLabCore
@testable import SwingLab

/// Real disk-store coverage for the first full-Xcode run. Portable Core tests verify the
/// conversion math, but do not establish that SwiftData recognizes a Round 1 store checksum.
final class SchemaMigrationTests: XCTestCase {
    @MainActor func testRoundOneStoreMigratesWithoutLosingRecordsOrRelationships() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Migration.store")
        let ids = try seedV1Store(at: url)

        let schema = Schema(versionedSchema: SwingLabCurrentSchema.self)
        let configuration = ModelConfiguration("Migration", schema: schema, url: url)
        let container = try ModelContainer(for: schema, migrationPlan: SwingLabMigrationPlan.self, configurations: configuration)
        let context = ModelContext(container)
        let recordings = try context.fetch(FetchDescriptor<SwingRecording>())
        XCTAssertEqual(recordings.count, 3)
        let recording = try XCTUnwrap(recordings.first { $0.id == ids.recording })
        XCTAssertEqual(recording.title, "Legacy swing")
        XCTAssertEqual(recording.videoFileName, "legacy.mov")
        XCTAssertEqual(recording.analysisData, Self.legacyAnalysis)
        XCTAssertEqual(recording.sourceValue, .imported)
        XCTAssertEqual(recording.cameraAngleValue, .downTheLine)
        XCTAssertEqual(recording.analysisVersion, 1)
        XCTAssertNil(recording.poseFrameRate)
        XCTAssertNil(recording.handednessOverride)
        XCTAssertEqual(recording.effectiveHandedness(default: .left), .left)
        XCTAssertEqual(try XCTUnwrap(recording.tempoRatio), 3, accuracy: 1e-10)
        XCTAssertEqual(recording.tempoMetric.provenance, .estimated)
        XCTAssertEqual(recording.backswingMetric.provenance, .userEntered)
        XCTAssertEqual(try XCTUnwrap(recording.backswingMetric.value), 0.9, accuracy: 1e-10)
        XCTAssertEqual(try XCTUnwrap(recording.downswingMetric.value), 0.3, accuracy: 1e-10)
        XCTAssertEqual(try XCTUnwrap(recording.headDisplacementMetric.value), 0.04, accuracy: 1e-10)
        XCTAssertEqual(recording.headDisplacementMetric.sampleCount, 5)
        let corrupt = try XCTUnwrap(recordings.first { $0.id == ids.corrupt })
        XCTAssertEqual(corrupt.analysisData, Data("preserve-corrupt-payload".utf8))
        XCTAssertNil(corrupt.tempoRatio)
        XCTAssertEqual(corrupt.tempoMetric.provenance, .unavailable)
        let empty = try XCTUnwrap(recordings.first { $0.id == ids.empty })
        XCTAssertNil(empty.analysisData)
        XCTAssertNil(empty.tempoRatio)

        let club = try XCTUnwrap(context.fetch(FetchDescriptor<GolfClub>()).first)
        XCTAssertEqual(club.id, ids.club)
        XCTAssertEqual(club.carryMeters, 137.16)
        XCTAssertEqual(club.notes, "Preserved note")
        let course = try XCTUnwrap(context.fetch(FetchDescriptor<GolfCourse>()).first)
        XCTAssertEqual(course.holes.count, 1)
        XCTAssertEqual(course.holes.first?.course?.id, course.id)
        XCTAssertEqual(course.holes.first?.referenceData, Data("reference-bytes".utf8))
        let round = try XCTUnwrap(context.fetch(FetchDescriptor<RoundSession>()).first)
        XCTAssertEqual(round.id, ids.round)
        XCTAssertEqual(round.course?.id, course.id)
        XCTAssertEqual(round.holeScores.first?.strokes, 4)
        XCTAssertEqual(round.holeScores.first?.round?.id, round.id)
        XCTAssertEqual(round.shots.first?.clubID, club.id)
        XCTAssertEqual(round.shots.first?.round?.id, round.id)
        XCTAssertEqual(round.shots.first?.endLongitude, 0.001)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CourseHole>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HoleScore>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ShotRecord>()).count, 1)

        // An unsuccessful later save must restore both payload and summary columns together.
        var edited = try XCTUnwrap(recording.analysis)
        edited.markers = []
        try recording.applyAnalysis(edited)
        XCTAssertNil(recording.tempoRatio)
        context.rollback()
        XCTAssertEqual(recording.analysisData, Self.legacyAnalysis)
        XCTAssertEqual(try XCTUnwrap(recording.tempoRatio), 3, accuracy: 1e-10)

        recording.handednessOverride = .left
        try context.save()
        let reader = ModelContext(container)
        let reopened = try XCTUnwrap(reader.fetch(FetchDescriptor<SwingRecording>()).first { $0.id == ids.recording })
        XCTAssertEqual(reopened.handednessOverride, .left)
        XCTAssertEqual(reopened.tempoMetric, recording.tempoMetric)
    }

    private struct LegacyIDs {
        let recording: UUID
        let corrupt: UUID
        let empty: UUID
        let club: UUID
        let round: UUID
    }

    /// Scope the old container separately so it closes before opening the new schema.
    @MainActor private func seedV1Store(at url: URL) throws -> LegacyIDs {
        let schema = Schema(versionedSchema: SwingLabSchemaV1.self)
        let config = ModelConfiguration("Migration", schema: schema, url: url)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)
        let club = SwingLabSchemaV1.GolfClub(name: "7 iron", category: "Iron")
        club.carryMeters = 137.16
        club.notes = "Preserved note"
        let recording = SwingLabSchemaV1.SwingRecording(title: "Legacy swing", videoFileName: "legacy.mov",
            durationSeconds: 3, nominalFrameRate: 120, videoWidth: 1920, videoHeight: 1080,
            cameraAngle: "Down-the-line", source: "Imported")
        recording.analysisData = Self.legacyAnalysis
        let corrupt = SwingLabSchemaV1.SwingRecording(title: "Corrupt", videoFileName: "corrupt.mov",
            durationSeconds: 3, nominalFrameRate: 30, videoWidth: 1920, videoHeight: 1080)
        corrupt.analysisData = Data("preserve-corrupt-payload".utf8)
        let empty = SwingLabSchemaV1.SwingRecording(title: "Unanalyzed", videoFileName: "empty.mov",
            durationSeconds: 3, nominalFrameRate: 30, videoWidth: 1920, videoHeight: 1080)
        let course = SwingLabSchemaV1.GolfCourse(name: "Legacy course", latitude: 0, longitude: 0)
        let hole = SwingLabSchemaV1.CourseHole(number: 1, par: 4)
        hole.referenceData = Data("reference-bytes".utf8)
        course.holes.append(hole)
        let round = SwingLabSchemaV1.RoundSession(courseName: course.name, holeCount: 9, course: course)
        let score = SwingLabSchemaV1.HoleScore(number: 1, par: 4)
        score.strokes = 4
        round.holeScores.append(score)
        let shot = SwingLabSchemaV1.ShotRecord(holeNumber: 1, shotNumber: 1, clubID: club.id, clubName: club.name,
            startLatitude: 0, startLongitude: 0, startAccuracyMeters: 5, startedAt: .now)
        shot.endLatitude = 0
        shot.endLongitude = 0.001
        round.shots.append(shot)
        context.insert(club)
        context.insert(recording)
        context.insert(corrupt)
        context.insert(empty)
        context.insert(course)
        context.insert(round)
        try context.save()
        return LegacyIDs(recording: recording.id, corrupt: corrupt.id, empty: empty.id, club: club.id, round: round.id)
    }

    private static let legacyAnalysis = Data(#"""
    {"schemaVersion":1,"frames":[
      {"time":1.0,"joints":[{"name":"nose","x":0.4,"y":0.7,"confidence":0.9}]},
      {"time":1.2,"joints":[{"name":"nose","x":0.41,"y":0.7,"confidence":0.9}]},
      {"time":1.4,"joints":[{"name":"nose","x":0.42,"y":0.7,"confidence":0.9}]},
      {"time":1.6,"joints":[{"name":"nose","x":0.43,"y":0.7,"confidence":0.9}]},
      {"time":1.8,"joints":[{"name":"nose","x":0.44,"y":0.7,"confidence":0.9}]}],
     "markers":[{"phase":"Address","time":1,"provenance":"User-entered"},
                {"phase":"Top of backswing","time":1.9,"provenance":"User-entered"},
                {"phase":"Impact","time":2.2,"provenance":"Estimated"}],
     "analyzedAt":814665600,"sampledFrameCount":75,"poseFrameCount":70,"sampleRateLimit":30,"notes":[]}
    """#.utf8)
}
