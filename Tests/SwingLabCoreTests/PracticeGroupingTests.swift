#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SwingLabCore

final class PracticeGroupingTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let right = PracticeContext(clubID: nil, cameraAngle: .faceOn, handedness: .right)
    private func sample(_ index: Int, _ seconds: Double, context: PracticeContext? = nil) -> PracticeGroupingSample {
        .init(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!,
              date: start.addingTimeInterval(seconds), context: context ?? right)
    }

    func testRollingNinetyMinuteWindowAndBoundary() {
        let inputs = [sample(0, 0), sample(1, 5400), sample(2, 10800), sample(3, 16201)]
        let groups = PracticeGrouping.groups(for: inputs.reversed())
        XCTAssertEqual(groups.map { $0.recordingIDs.count }, [3, 1])
        XCTAssertEqual(groups[0].date, start)
        XCTAssertEqual(groups[0].lastRecordingDate, start.addingTimeInterval(10800))
    }

    func testUnknownClubAngleAndHandednessStaySeparate() {
        let club = UUID()
        let inputs = [sample(0, 0), sample(1, 1, context: .init(clubID: club, cameraAngle: .faceOn, handedness: .right)),
                      sample(2, 2, context: .init(clubID: nil, cameraAngle: .downTheLine, handedness: .right)),
                      sample(3, 3, context: .init(clubID: nil, cameraAngle: .faceOn, handedness: .left)),
                      sample(4, 4, context: .init(clubID: nil, cameraAngle: .faceOn, handedness: nil)), sample(5, 5)]
        let groups = PracticeGrouping.groups(for: inputs)
        XCTAssertEqual(groups.count, 5)
        XCTAssertEqual(groups[0].recordingIDs, [inputs[0].id, inputs[5].id])
        XCTAssertNil(groups[4].context.handedness)
    }

    func testEqualTimesAndDuplicateInputsAreDeterministic() {
        let inputs = [sample(2, 0), sample(0, 0), sample(1, 0), sample(0, 0)]
        let group = PracticeGrouping.groups(for: inputs)[0]
        XCTAssertEqual(group.id, inputs[1].id)
        XCTAssertEqual(group.recordingIDs, [inputs[1].id, inputs[2].id, inputs[0].id])
    }

    func testAssignChoosesMostRecentCompatiblePastSession() {
        let input = sample(10, 10800)
        let candidates = [sample(0, 5400), sample(1, 5399), sample(2, 10801),
                          sample(3, 10000, context: .init(clubID: nil, cameraAngle: .downTheLine, handedness: .right))]
            .map { PracticeSessionCandidate(id: $0.id, lastRecordingDate: $0.date, context: $0.context) }
        XCTAssertEqual(PracticeGrouping.matchingSession(for: input, candidates: candidates), candidates[0].id)
        XCTAssertNil(PracticeGrouping.matchingSession(for: sample(11, 10800.1), candidates: candidates))
    }
}
