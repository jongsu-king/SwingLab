#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SwingLabCore

final class LaunchDrillTests: XCTestCase {
    func testScoringUsesTheWholeBracketAgainstTheBand() {
        let target = DrillTarget(distance: 150, tolerance: 5)   // band 145...155
        XCTAssertEqual(DrillScorer.score(carry: 148...152, target: target).outcome, .hit)
        XCTAssertEqual(DrillScorer.score(carry: 140...146, target: target).outcome, .hit)      // overlaps the low edge
        XCTAssertEqual(DrillScorer.score(carry: 155...160, target: target).outcome, .hit)      // touches the high edge
        let short = DrillScorer.score(carry: 130...138, target: target)
        XCTAssertEqual(short.outcome, .short)
        XCTAssertEqual(short.gap, -7, accuracy: 1e-9)
        let long = DrillScorer.score(carry: 160...164, target: target)
        XCTAssertEqual(long.outcome, .long)
        XCTAssertEqual(long.gap, 5, accuracy: 1e-9)
        XCTAssertEqual(long.gapMetric.provenance, .simulated)
        XCTAssertEqual(long.gapMetric.unit, "m")
        XCTAssertEqual(DrillTarget(distance: 100, tolerance: -3).tolerance, 0)
    }

    func testTargetDrillCountsHitsAndStreaks() {
        var drill = DrillSession(target: DrillTarget(distance: 150, tolerance: 5))
        XCTAssertEqual(drill.kind, .target)
        XCTAssertFalse(drill.isComplete)
        drill.record(carry: 149...151)
        drill.record(carry: 150...153)
        drill.record(carry: 170...172)
        drill.record(carry: 147...149)
        XCTAssertEqual(drill.shots, 4)
        XCTAssertEqual(drill.hits, 3)
        XCTAssertEqual(drill.streak, 1)
        XCTAssertEqual(drill.bestStreak, 2)
        XCTAssertFalse(drill.isComplete)
        XCTAssertEqual(drill.target.distance, 150)
        // Discarding the last hit recomputes the streak from what remains.
        drill.discardLast()
        XCTAssertEqual(drill.shots, 3)
        XCTAssertEqual(drill.streak, 0)
        XCTAssertEqual(drill.bestStreak, 2)
        drill.discardLast(); drill.discardLast()
        XCTAssertEqual(drill.streak, 1)
        XCTAssertEqual(drill.bestStreak, 1)
    }

    func testLadderClimbsOnHitsStaysOnMissesAndCompletes() throws {
        let ladder = try XCTUnwrap(LadderDrill(start: 60, step: 20, rungs: 3, tolerance: 5))
        var drill = DrillSession(ladder: ladder)
        XCTAssertEqual(drill.kind, .ladder)
        XCTAssertEqual(drill.target, DrillTarget(distance: 60, tolerance: 5))
        XCTAssertEqual(drill.record(carry: 70...75).outcome, .long)   // miss: stays on rung 0
        XCTAssertEqual(drill.rung, 0)
        XCTAssertEqual(drill.record(carry: 58...62).outcome, .hit)
        XCTAssertEqual(drill.rung, 1)
        XCTAssertEqual(drill.target.distance, 80)
        drill.record(carry: 79...81)
        XCTAssertEqual(drill.target.distance, 100)
        XCTAssertFalse(drill.isComplete)
        drill.record(carry: 98...103)
        XCTAssertTrue(drill.isComplete)
        XCTAssertEqual(drill.rung, 3)
        XCTAssertEqual(drill.target.distance, 100)   // the top rung stays shown
        XCTAssertEqual(drill.hits, 3)
        XCTAssertEqual(drill.streak, 3)
        // Discarding the completing hit reopens the top rung.
        drill.discardLast()
        XCTAssertFalse(drill.isComplete)
        XCTAssertEqual(drill.rung, 2)
        XCTAssertEqual(drill.target.distance, 100)
        XCTAssertEqual(ladder.target(rung: 99).distance, 100)   // clamped
        XCTAssertNil(LadderDrill(start: 0, step: 20, rungs: 3, tolerance: 5))
        XCTAssertNil(LadderDrill(start: 60, step: 20, rungs: 0, tolerance: 5))
        XCTAssertNil(LadderDrill(start: 60, step: .nan, rungs: 3, tolerance: 5))
        for kind in DrillKind.allCases { XCTAssertFalse(kind.localizationKey.rawValue.isEmpty) }
        for outcome in DrillOutcome.allCases { XCTAssertFalse(outcome.localizationKey.rawValue.isEmpty) }
    }

    func testCSVExportKeepsOnlyMeasuredValuesAndQuotesFields() throws {
        let rows = [
            LaunchLogRow(date: Date(timeIntervalSince1970: 1_700_000_000), club: "iron7", source: "liveCamera", ballSpeedMetersPerSecond: 54.2,
                         launchAngleRadians: 16 * .pi / 180, provenance: .visionDerived, confidence: 0.81, relativeSpeedUncertainty: 0.0123,
                         trackedPositions: 3, method: "launch.faceOnTrack.v1"),
            LaunchLogRow(date: Date(timeIntervalSince1970: 1_600_000_000), club: "custom, \"long\" iron", source: "recordedVideo",
                         ballSpeedMetersPerSecond: 60, launchAngleRadians: 0.2, provenance: .visionDerived, confidence: nil,
                         relativeSpeedUncertainty: 0.02, trackedPositions: 2, method: "launch.faceOnTrack.v1")
        ]
        let csv = LaunchLogExport.csv(rows)
        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0], LaunchLogExport.header)
        // Oldest first, quoted club name, empty confidence.
        XCTAssertTrue(lines[1].hasPrefix("2020-09-13T12:26:40Z,\"custom, \"\"long\"\" iron\",recordedVideo,60.000,11.46,visionDerived,,0.0200,2,"))
        XCTAssertEqual(lines[2], "2023-11-14T22:13:20Z,iron7,liveCamera,54.200,16.00,visionDerived,0.810,0.0123,3,launch.faceOnTrack.v1")
        for forbidden in ["carry", "total", "spin", "club_speed"] { XCTAssertFalse(LaunchLogExport.header.contains(forbidden)) }
        XCTAssertEqual(LaunchLogExport.csv([]), LaunchLogExport.header + "\n")
        XCTAssertEqual(LaunchLogExport.number(.nan, digits: 2), "")
    }
}
