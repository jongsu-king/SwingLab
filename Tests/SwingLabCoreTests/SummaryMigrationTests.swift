#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SwingLabCore

final class SummaryMigrationTests: XCTestCase {
    /// Literal Round 1 payload: percentages were presentation only; pose coordinates remain fractions.
    private let legacy = #"""
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
    """#

    func testSchemaOneSummaryMigrationPreservesProvenanceAndSI() throws {
        let summary = AnalysisSummary.migrating(analysisData: Data(legacy.utf8))
        XCTAssertEqual(try XCTUnwrap(summary.tempo.value), 3, accuracy: 1e-10)
        XCTAssertEqual(summary.tempo.unit, "1")
        XCTAssertEqual(summary.tempo.provenance, .estimated)
        XCTAssertEqual(summary.backswing.provenance, .userEntered)
        XCTAssertEqual(summary.downswing.provenance, .estimated)
        XCTAssertEqual(try XCTUnwrap(summary.backswing.value), 0.9, accuracy: 1e-10)
        XCTAssertEqual(try XCTUnwrap(summary.downswing.value), 0.3, accuracy: 1e-10)
        XCTAssertEqual(summary.backswing.unit, "s")
        XCTAssertEqual(try XCTUnwrap(summary.headDisplacement.value), 0.04, accuracy: 1e-10)
        XCTAssertEqual(summary.headDisplacement.provenance, .visionDerived)
        XCTAssertEqual(summary.headDisplacement.sampleCount, 5)
        XCTAssertEqual(summary.analysisVersion, 1)
        // The old 30 Hz cap is not an observed sampling frequency.
        XCTAssertNil(summary.poseFrameRate)
        XCTAssertEqual(try JSONDecoder().decode(AnalysisSummary.self, from: JSONEncoder().encode(summary)), summary)
    }

    func testMissingAnalysisRemainsUnavailable() {
        for data in [Data?.none, Data("broken-json".utf8), Data("{}".utf8)] {
            let summary = AnalysisSummary.migrating(analysisData: data)
            for metric in [summary.tempo, summary.backswing, summary.downswing, summary.headDisplacement] {
                XCTAssertNil(metric.value)
                XCTAssertEqual(metric.provenance, .unavailable)
            }
            XCTAssertEqual(summary.analysisVersion, 0)
            XCTAssertNil(summary.poseFrameRate)
        }
    }

    func testCurrentSummaryPreservesVersionAndFrameRate() throws {
        var report = try JSONDecoder().decode(PoseAnalysisReport.self, from: Data(legacy.utf8))
        report.analysisVersion = 2
        report.poseFrameRate = 120
        let summary = AnalysisSummary(report: report)
        XCTAssertEqual(summary.analysisVersion, 2)
        XCTAssertEqual(summary.poseFrameRate, 120)
        XCTAssertEqual(summary.tempo.method, report.tempoMetric.method)
        XCTAssertEqual(summary.tempo.sampleCount, report.tempoMetric.sampleCount)
        XCTAssertEqual(AnalysisSummary.migrating(analysisData: try JSONEncoder().encode(report)), summary)
        for rate in [0.0, -30, .infinity, .nan] {
            report.poseFrameRate = rate
            XCTAssertNil(AnalysisSummary(report: report).poseFrameRate)
        }
    }
}
