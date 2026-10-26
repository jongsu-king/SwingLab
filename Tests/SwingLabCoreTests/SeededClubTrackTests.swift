import XCTest
@testable import SwingLabCore

final class SeededClubTrackTests: XCTestCase {
    func testConfidenceLossStopsPermanentlyAndNeverExtrapolates() {
        var track = SeededClubTrack(endTime: 2)
        for i in 0..<10 {
            XCTAssertTrue(track.append(.init(time: Double(i) / 120, x: 0.2 + Double(i) * 0.01, y: 0.3, confidence: 0.8)))
        }
        XCTAssertFalse(track.append(.init(time: 0.1, x: 0.3, y: 0.3, confidence: 0.49)))
        XCTAssertFalse(track.append(.init(time: 0.11, x: 0.31, y: 0.3, confidence: 0.99)))
        XCTAssertEqual(track.points.count, 10)
        XCTAssertEqual(track.lostAt, 0.1)
    }
    func testLongGapAndInvalidCoordinatesStopButTopNeverAddsPoint() {
        var track = SeededClubTrack(endTime: 1)
        XCTAssertTrue(track.append(.init(time: 0, x: 0.5, y: 0.5, confidence: 1)))
        XCTAssertFalse(track.append(.init(time: 0.2, x: 0.5, y: 0.5, confidence: 1)))
        XCTAssertEqual(track.lostAt, 0.2)
        var bounded = SeededClubTrack(endTime: 0.01)
        XCTAssertTrue(bounded.append(.init(time: 0, x: 0.5, y: 0.5, confidence: 1)))
        XCTAssertFalse(bounded.append(.init(time: 0.02, x: 0.5, y: 0.5, confidence: 1)))
        XCTAssertNil(bounded.lostAt)
        var invalid = SeededClubTrack(endTime: 1)
        XCTAssertFalse(invalid.append(.init(time: 0, x: .nan, y: 0.5, confidence: 1)))
        XCTAssertTrue(invalid.points.isEmpty)
    }
}
