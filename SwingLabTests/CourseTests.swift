import XCTest
import SwiftData
@testable import SwingLab

final class CourseTests: XCTestCase {
    func testGPSFreshnessAndAccuracyBoundaries() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func fix(age: Double = 0, accuracy: Double = 5) -> CourseLocationFix {
            CourseLocationFix(latitude: 37.5, longitude: 127, horizontalAccuracy: accuracy,
                              timestamp: now.addingTimeInterval(-age))
        }
        XCTAssertTrue(fix(age: 20, accuracy: 30).isUsableForShot(at: now))
        XCTAssertFalse(fix(age: 20.01).isUsableForShot(at: now))
        XCTAssertFalse(fix(accuracy: 30.01).isUsableForShot(at: now))
        XCTAssertFalse(fix(accuracy: -1).isUsableForShot(at: now))
        XCTAssertFalse(fix(accuracy: .nan).isUsableForShot(at: now))
        XCTAssertFalse(fix(age: -5.01).isUsableForShot(at: now))
        XCTAssertTrue(fix(age: -5).isUsableForShot(at: now))
        XCTAssertFalse(CourseLocationFix(latitude: 91, longitude: 0, horizontalAccuracy: 1,
                                        timestamp: now).isUsableForShot(at: now))
    }

    func testScoreInputPreservesMissingValuesAndIncludesPenalties() throws {
        let empty = try XCTUnwrap(ScorecardEntry.validated(par: "", strokes: "", putts: "", penalties: 0))
        XCTAssertNil(empty.par)
        XCTAssertNil(empty.strokes)
        XCTAssertNil(empty.putts)
        let score = try XCTUnwrap(ScorecardEntry.validated(par: " 4 ", strokes: "5", putts: "2", penalties: 1))
        XCTAssertEqual(score.strokes, 5)
        XCTAssertEqual(score.putts, 2)
        XCTAssertNil(ScorecardEntry.validated(par: "4", strokes: "2", putts: "2", penalties: 1))
        XCTAssertNil(ScorecardEntry.validated(par: "0", strokes: "4", putts: "1", penalties: 0))
        XCTAssertNil(ScorecardEntry.validated(par: "4", strokes: "0", putts: "0", penalties: 0))
        XCTAssertNil(ScorecardEntry.validated(par: "4", strokes: "four", putts: "1", penalties: 0))
        XCTAssertNil(ScorecardEntry.validated(par: "4", strokes: "4", putts: "-1", penalties: 0))
        XCTAssertNil(ScorecardEntry.validated(par: "4", strokes: "4", putts: "1", penalties: -1))
    }

    @MainActor func testManualReferencesPersistAndRemainHoleSpecific() throws {
        let schema = Schema(SwingLabCurrentSchema.models)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let writer = ModelContext(container)
        let course = GolfCourse(name: "Entered course", latitude: 37.5, longitude: 127)
        let first = CourseHole(number: 1)
        let second = CourseHole(number: 2)
        let target = CourseReferencePoint(kind: "Target", latitude: 37.501234, longitude: 127.001234)
        first.references = [target]
        course.holes = [first, second]
        writer.insert(course)
        try writer.save()
        let reader = ModelContext(container)
        let stored = try XCTUnwrap(reader.fetch(FetchDescriptor<GolfCourse>()).first)
        XCTAssertEqual(stored.source, "userEntered")
        let storedFirst = try XCTUnwrap(stored.holes.first { $0.number == 1 })
        let storedTarget = try XCTUnwrap(storedFirst.references.first)
        XCTAssertEqual(storedTarget.id, target.id)
        XCTAssertEqual(storedTarget.latitude, 37.501234, accuracy: 1e-10)
        XCTAssertEqual(storedTarget.longitude, 127.001234, accuracy: 1e-10)
        XCTAssertTrue(try XCTUnwrap(stored.holes.first { $0.number == 2 }).references.isEmpty)
        XCTAssertNil(storedFirst.par)
    }
}
