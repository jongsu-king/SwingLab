import XCTest
import SwiftData
import SwingLabCore
@testable import SwingLab

final class CourseGeometryPersistenceTests: XCTestCase {
    @MainActor func testLegacyReferencesSurvivePolygonSaveAndReopen() throws {
        let schema = Schema(versionedSchema: SwingLabCurrentSchema.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let hole = CourseHole(number: 1, par: 4)
        let reference = CourseReferencePoint(kind: "Target", latitude: 37, longitude: 127)
        hole.referenceData = try JSONEncoder().encode([reference])
        context.insert(hole)
        try context.save()
        XCTAssertEqual(hole.references.first?.id, reference.id)
        XCTAssertTrue(hole.areas.isEmpty)
        let polygon = CourseArea(kind: .water, vertices: [.init(latitude: 37, longitude: 127),
            .init(latitude: 37.001, longitude: 127), .init(latitude: 37, longitude: 127.001)])
        hole.areas = [polygon]
        try context.save()
        let reader = ModelContext(container)
        let reopened = try XCTUnwrap(reader.fetch(FetchDescriptor<CourseHole>()).first)
        XCTAssertEqual(reopened.references.first?.id, reference.id)
        XCTAssertEqual(reopened.areas, [polygon])
        reopened.references = []
        try reader.save()
        XCTAssertEqual(reopened.areas, [polygon])
        reopened.areas = []
        reader.rollbackPendingChanges()
        XCTAssertEqual(reopened.areas, [polygon])
    }
}
