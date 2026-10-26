import XCTest
import SwiftData
import SwingLabCore
@testable import SwingLab

final class PracticeSessionTests: XCTestCase {
    @MainActor private func container() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SwingLabCurrentSchema.self)
        return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func recording(_ date: Date, clubID: UUID? = nil) -> SwingRecording {
        let value = SwingRecording(title: "Practice", videoFileName: "practice.mov", durationSeconds: 3,
                                   nominalFrameRate: 120, videoWidth: 1920, videoHeight: 1080)
        value.createdAt = date
        value.clubID = clubID
        return value
    }

    @MainActor func testAssignGroupsByRollingWindowAndCapturesPreference() throws {
        let container = try container(), context = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let first = recording(start), second = recording(start.addingTimeInterval(5400)), third = recording(start.addingTimeInterval(10801))
        for item in [first, second, third] {
            context.insert(item)
            try PracticeSessionStore.assign(recording: item, context: context, defaultHandedness: .left)
            try context.save()
        }
        XCTAssertEqual(first.practiceSession?.id, second.practiceSession?.id)
        XCTAssertNotEqual(first.practiceSession?.id, third.practiceSession?.id)
        XCTAssertEqual(first.handednessOverride, .left)
        XCTAssertEqual(first.practiceSession?.handedness, .left)
        let club = UUID()
        let differentClub = recording(start.addingTimeInterval(10802), clubID: club)
        context.insert(differentClub)
        try PracticeSessionStore.assign(recording: differentClub, context: context, defaultHandedness: .left)
        try context.save()
        XCTAssertNotEqual(differentClub.practiceSession?.id, third.practiceSession?.id)
        XCTAssertEqual(differentClub.coachingSample.club, club.uuidString)
    }

    @MainActor func testRegroupPersistsAndRollbackRestoresMembership() throws {
        let container = try container(), context = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let first = recording(start), second = recording(start.addingTimeInterval(1))
        for item in [first, second] {
            context.insert(item)
            try PracticeSessionStore.assign(recording: item, context: context, defaultHandedness: .right)
            try context.save()
        }
        let original = try XCTUnwrap(first.practiceSession)
        let separated = try PracticeSessionStore.newSession(for: second, context: context, defaultHandedness: nil)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<PracticeSession>()).count, 2)
        XCTAssertEqual(original.recordings.map(\.id), [first.id])
        XCTAssertEqual(separated.recordings.map(\.id), [second.id])
        try PracticeSessionStore.regroup(recording: second, to: original, context: context)
        context.rollback()
        XCTAssertEqual(second.practiceSession?.id, separated.id)
        try PracticeSessionStore.regroup(recording: second, to: original, context: context)
        try context.save()
        let reader = ModelContext(container)
        XCTAssertEqual(try reader.fetch(FetchDescriptor<PracticeSession>()).count, 1)
        XCTAssertEqual(try reader.fetch(FetchDescriptor<SwingRecording>()).count, 2)
        XCTAssertEqual(Set(try reader.fetch(FetchDescriptor<SwingRecording>()).compactMap { $0.practiceSession?.id }), [original.id])
        XCTAssertEqual(second.videoFileName, "practice.mov")
    }
}
