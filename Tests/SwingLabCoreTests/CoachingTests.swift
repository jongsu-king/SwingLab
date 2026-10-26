#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SwingLabCore

final class CoachingTests: XCTestCase {
    private func sample(_ day: Int, tempo: Double?, head: Double? = nil, angle: CameraAngle = .faceOn,
                        club: String? = "7-iron", tempoOrigin: Provenance = .estimated) -> CoachingSample {
        var metrics: [CoachedMetric: ProvenancedValue] = [
            .tempo: .init(value: tempo, unit: "1", provenance: tempo == nil ? .unavailable : tempoOrigin, method: "phase.tempoRatio.v1")
        ]
        if let head { metrics[.headDisplacement] = .init(value: head, unit: "1", provenance: .visionDerived, method: "pose.noseDisplacement.v1") }
        return CoachingSample(id: UUID(), date: Date(timeIntervalSince1970: Double(day) * 86_400), club: club,
                              cameraAngle: angle, metrics: metrics)
    }
    private let steadyTempos = [3.0, 3.1, 2.9, 3.05, 2.95, 3.0, 3.1, 2.9]

    func testSummaryStatistics() throws {
        let summary = try XCTUnwrap(MetricSummary([2, 4, 4, 4, 5, 5, 7, 9]))
        XCTAssertEqual(summary.count, 8)
        XCTAssertEqual(summary.mean, 5, accuracy: 1e-12)
        XCTAssertEqual(summary.standardDeviation, (32.0 / 7).squareRoot(), accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(summary.coefficientOfVariation), (32.0 / 7).squareRoot() / 5, accuracy: 1e-12)
        XCTAssertNil(MetricSummary([1]))
        XCTAssertNil(MetricSummary([.nan, 2]))
        XCTAssertNil(try XCTUnwrap(MetricSummary([-1, 1])).coefficientOfVariation)
    }

    func testFewerThanFiveComparableSwingsGivesNoStatement() {
        let history = steadyTempos.prefix(4).enumerated().map { sample($0.offset, tempo: $0.element) }
        let feedback = CoachingEngine.feedback(for: sample(10, tempo: 4.0), history: Array(history))
        XCTAssertEqual(feedback.map(\.templateID), ["coach.needMoreSwings"])
        XCTAssertEqual(feedback.first?.baselineCount, 4)
        XCTAssertNil(CoachingEngine.consistency(.tempo, in: Array(history)))
    }

    func testShiftFromOwnBaselineUsesTheRightTemplate() throws {
        let history = steadyTempos.enumerated().map { sample($0.offset, tempo: $0.element, head: 0.02) }
        let slower = CoachingEngine.feedback(for: sample(10, tempo: 3.6, head: 0.021), history: history)
        let tempo = try XCTUnwrap(slower.first { $0.metric == .tempo })
        XCTAssertEqual(tempo.templateID, "coach.tempo.higher")
        XCTAssertEqual(tempo.baselineCount, 8)
        XCTAssertEqual(try XCTUnwrap(tempo.baselineMean), steadyTempos.reduce(0, +) / 8, accuracy: 1e-12)
        XCTAssertEqual(tempo.drillID, "drill.countedTempo")
        // A constant head baseline (SD 0) cannot make any swing unusual.
        XCTAssertTrue(!slower.contains { $0.metric == .headDisplacement })
        XCTAssertEqual(CoachingEngine.feedback(for: sample(10, tempo: 2.4), history: history).first?.templateID, "coach.tempo.lower")
        // Within the usual spread: nothing to say.
        XCTAssertTrue(CoachingEngine.feedback(for: sample(10, tempo: 3.05), history: history).isEmpty)
        XCTAssertEqual(try XCTUnwrap(CoachingEngine.consistency(.tempo, in: history)).count, 8)
    }

    func testOtherAnglesClubsFutureAndUnavailableValuesAreExcluded() {
        var history = steadyTempos.enumerated().map { sample($0.offset, tempo: $0.element, angle: .downTheLine) }
        history += steadyTempos.enumerated().map { sample($0.offset, tempo: $0.element, club: "Driver") }
        history += steadyTempos.enumerated().map { sample(20 + $0.offset, tempo: $0.element) }   // after the current swing
        history += (0..<8).map { sample($0, tempo: nil) }                                          // no tempo
        let feedback = CoachingEngine.feedback(for: sample(10, tempo: 4.0), history: history)
        XCTAssertEqual(feedback.map(\.templateID), ["coach.needMoreSwings"])
        XCTAssertEqual(feedback.first?.baselineCount, 0)
        // An unavailable current value produces no observation at all.
        let comparable = steadyTempos.enumerated().map { sample($0.offset, tempo: $0.element) }
        XCTAssertTrue(CoachingEngine.feedback(for: sample(10, tempo: nil), history: comparable).isEmpty)
    }

    func testBaselineIsLimitedToTheMostRecentTwenty() throws {
        // 30 old swings at 2.0 then 20 recent swings around 3.0: the old ones must not count.
        var history = (0..<30).map { sample($0, tempo: 2.0 + Double($0 % 3) * 0.01) }
        history += (0..<20).map { sample(100 + $0, tempo: steadyTempos[$0 % steadyTempos.count]) }
        let feedback = CoachingEngine.feedback(for: sample(200, tempo: 3.0), history: history)
        XCTAssertTrue(feedback.isEmpty)
    }

    func testUnanalyzedRecordingsDoNotEvictTheAnalyzedBaseline() throws {
        let analyzed = steadyTempos.enumerated().map { sample($0.offset, tempo: $0.element) }
        let waitingForAnalysis = (20..<45).map { sample($0, tempo: nil) }
        let feedback = CoachingEngine.feedback(for: sample(50, tempo: 4), history: analyzed + waitingForAnalysis)
        XCTAssertEqual(feedback.first?.templateID, "coach.tempo.higher")
        XCTAssertEqual(feedback.first?.baselineCount, 8)
    }

    func testUnknownCameraAnglesDoNotEstablishAComparableBaseline() {
        let history = steadyTempos.enumerated().map { sample($0.offset, tempo: $0.element, angle: .unspecified) }
        let current = sample(50, tempo: 4, angle: .unspecified)
        XCTAssertTrue(CoachingEngine.comparisons(for: current, history: history).isEmpty)
        XCTAssertTrue(CoachingEngine.feedback(for: current, history: history).isEmpty)
    }

    func testEmptyFeedbackDoesNotImplyAValidComparison() throws {
        let history = steadyTempos.enumerated().map { sample($0.offset, tempo: $0.element) }
        let missing = sample(10, tempo: nil)
        XCTAssertTrue(CoachingEngine.feedback(for: missing, history: history).isEmpty)
        XCTAssertTrue(CoachingEngine.comparisons(for: missing, history: history).isEmpty)
        let constant = (0..<8).map { sample($0, tempo: 3.0) }
        XCTAssertTrue(CoachingEngine.feedback(for: sample(10, tempo: 5), history: constant).isEmpty)
        XCTAssertTrue(CoachingEngine.comparisons(for: sample(10, tempo: 5), history: constant).isEmpty)
        // A within-threshold tempo comparison says nothing about unavailable head or duration measures.
        let valid = CoachingEngine.comparisons(for: sample(10, tempo: 3.05), history: history)
        XCTAssertEqual(valid.map(\.metric), [.tempo])
        XCTAssertEqual(valid.first?.baseline.count, 8)
        XCTAssertLessThan(abs(try XCTUnwrap(valid.first).zScore), CoachingEngine.zThreshold)
        XCTAssertTrue(CoachingEngine.comparisons(for: sample(10, tempo: 3.05), history: Array(history.prefix(4))).isEmpty)
    }
}
