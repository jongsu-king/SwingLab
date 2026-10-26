#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SwingLabCore

final class ProvenanceTests: XCTestCase {
    func testStableProvenanceAndLegacyLabels() throws {
        let decoder = JSONDecoder(), encoder = JSONEncoder()
        for provenance in Provenance.allCases {
            let encoded = try encoder.encode(provenance)
            XCTAssertEqual(try decoder.decode(String.self, from: encoded), provenance.rawValue)
            XCTAssertEqual(try decoder.decode(Provenance.self, from: encoded), provenance)
            let oldLabel = try encoder.encode(provenance.localizationKey)
            XCTAssertEqual(try decoder.decode(Provenance.self, from: oldLabel), provenance)
        }
        XCTAssertEqual(Provenance.audioDerived.category, .measured)
        XCTAssertEqual(Provenance.visionDerived.category, .visionDerived)
        XCTAssertEqual(Provenance(legacyValue: "automatically measured"), .unavailable)
        XCTAssertEqual(Provenance(legacyValue: "User-Entered"), .userEntered)
    }

    func testTypedRecordingMetadataMigration() throws {
        XCTAssertEqual(RecordingSource(legacyValue: "Recorded"), .recorded)
        XCTAssertEqual(RecordingSource(legacyValue: "Imported"), .imported)
        XCTAssertEqual(RecordingSource(legacyValue: "remote"), .unspecified)
        XCTAssertEqual(CameraAngle(legacyValue: "Face-on"), .faceOn)
        XCTAssertEqual(CameraAngle(legacyValue: "Down the line"), .downTheLine)
        XCTAssertEqual(CameraAngle(legacyValue: "Down-the-line"), .downTheLine)
        XCTAssertEqual(CameraAngle(legacyValue: "Overhead"), .unspecified)
        let decoder = JSONDecoder(), encoder = JSONEncoder()
        for angle in CameraAngle.allCases {
            XCTAssertEqual(try decoder.decode(String.self, from: encoder.encode(angle)), angle.rawValue)
            XCTAssertEqual(try decoder.decode(CameraAngle.self, from: encoder.encode(angle.localizationKey)), angle)
        }
        for source in RecordingSource.allCases {
            XCTAssertEqual(try decoder.decode(String.self, from: encoder.encode(source)), source.rawValue)
            XCTAssertEqual(try decoder.decode(RecordingSource.self, from: encoder.encode(source.localizationKey)), source)
        }
    }

    func testMeasurementInvariants() throws {
        let valid = ProvenancedValue(value: -0.25, unit: "m", provenance: .userEntered,
                                    confidence: 0.9, method: "entry.lateral.v1", sampleCount: 12)
        XCTAssertEqual(try JSONDecoder().decode(ProvenancedValue.self, from: JSONEncoder().encode(valid)), valid)
        for value in [Double.nan, .infinity, -.infinity] {
            let invalid = ProvenancedValue(value: value, unit: "s", provenance: .measured,
                                          confidence: 0.9, method: "clock.v1", sampleCount: 1)
            XCTAssertNil(invalid.value)
            XCTAssertEqual(invalid.provenance, .unavailable)
            XCTAssertNil(invalid.confidence)
        }
        let unknown = ProvenancedValue(value: 42, unit: "m", provenance: .unavailable, method: "unknown.v1")
        XCTAssertNil(unknown.value)
        let missing = ProvenancedValue(value: nil, unit: "m", provenance: .measured, method: "gps.v1")
        XCTAssertEqual(missing.provenance, .unavailable)
        let noObservations = ProvenancedValue(value: nil, unit: "m", provenance: .unavailable,
                                             method: "gps.v1", sampleCount: 0)
        XCTAssertEqual(noObservations.sampleCount, 0)
        for confidence in [-0.01, 1.01, .nan, .infinity] {
            let invalid = ProvenancedValue(value: 1, unit: "s", provenance: .measured,
                                          confidence: confidence, method: "clock.v1", sampleCount: -1)
            XCTAssertEqual(invalid.value, 1)
            XCTAssertNil(invalid.confidence)
            XCTAssertNil(invalid.sampleCount)
        }
        for confidence in [0.0, 1.0] {
            XCTAssertEqual(ProvenancedValue(value: 1, unit: "s", provenance: .measured,
                                           confidence: confidence, method: "clock.v1").confidence, confidence)
        }
        XCTAssertNil(ProvenancedValue(value: 1, unit: "", provenance: .measured, method: "clock.v1").value)
        XCTAssertNil(ProvenancedValue(value: 1, unit: "s", provenance: .measured, method: " ").value)
    }

    func testDecodingCannotBypassMeasurementValidation() throws {
        let unknown = #"{"value":42,"unit":"m","provenance":"unreviewed","confidence":0.9,"method":"unknown.v1","sampleCount":12}"#
        let result = try JSONDecoder().decode(ProvenancedValue.self, from: Data(unknown.utf8))
        XCTAssertNil(result.value)
        XCTAssertEqual(result.provenance, .unavailable)
        XCTAssertNil(result.confidence)
        let invalidMetadata = #"{"value":0.3,"unit":"s","provenance":"measured","confidence":1.5,"method":"clock.v1","sampleCount":-2}"#
        let invalid = try JSONDecoder().decode(ProvenancedValue.self, from: Data(invalidMetadata.utf8))
        XCTAssertEqual(invalid.value, 0.3)
        XCTAssertNil(invalid.confidence)
        XCTAssertNil(invalid.sampleCount)
        let nonfinite = #"{"value":"NaN","unit":"s","provenance":"measured","method":"clock.v1"}"#
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        XCTAssertNil(try decoder.decode(ProvenancedValue.self, from: Data(nonfinite.utf8)).value)
    }

    /// Fixed Round 1 wire-format fixture, not JSON generated by the new encoder.
    private let schemaOneFixture = #"""
    {
      "schemaVersion": 1,
      "frames": [
        {"time":1.0,"joints":[{"name":"nose","x":0.4,"y":0.7,"confidence":0.9}]},
        {"time":1.2,"joints":[{"name":"nose","x":0.41,"y":0.7,"confidence":0.9}]},
        {"time":1.4,"joints":[{"name":"nose","x":0.42,"y":0.7,"confidence":0.9}]},
        {"time":1.6,"joints":[{"name":"nose","x":0.43,"y":0.7,"confidence":0.9}]},
        {"time":1.8,"joints":[{"name":"nose","x":0.44,"y":0.7,"confidence":0.9}]}
      ],
      "markers": [
        {"phase":"Address","time":1.0,"provenance":"User-entered"},
        {"phase":"Top of backswing","time":1.9,"provenance":"User-entered"},
        {"phase":"Impact","time":2.2,"provenance":"Estimated"}
      ],
      "analyzedAt": 814665600,
      "sampledFrameCount": 75,
      "poseFrameCount": 70,
      "sampleRateLimit": 30,
      "notes": ["Phase markers are estimates. Review and correct them before using tempo."]
    }
    """#

    func testSchemaOneAnalysisJSONStillDecodes() throws {
        let report = try JSONDecoder().decode(PoseAnalysisReport.self, from: Data(schemaOneFixture.utf8))
        XCTAssertEqual(report.schemaVersion, 1)
        XCTAssertEqual(report.frames.count, 5)
        XCTAssertEqual(report.marker(.address)?.provenance, .userEntered)
        XCTAssertEqual(report.marker(.impact)?.provenance, .estimated)
        XCTAssertEqual(try XCTUnwrap(report.tempoRatio), 3, accuracy: 1e-10)
        XCTAssertEqual(report.timingProvenance, .estimated)
        let migrated = try JSONEncoder().encode(report)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: migrated) as? [String: Any])
        let markers = try XCTUnwrap(object["markers"] as? [[String: Any]])
        XCTAssertEqual(markers[0]["phase"] as? String, "address")
        XCTAssertEqual(markers[0]["provenance"] as? String, "userEntered")
        let roundTrip = try JSONDecoder().decode(PoseAnalysisReport.self, from: migrated)
        XCTAssertEqual(roundTrip.tempoMetric, report.tempoMetric)
        for phase in SwingPhaseName.allCases {
            XCTAssertEqual(try JSONDecoder().decode(SwingPhaseName.self,
                           from: JSONEncoder().encode(phase.localizationKey)), phase)
        }
        XCTAssertThrowsError(try JSONDecoder().decode(SwingPhaseName.self, from: Data(#""unknownPhase""#.utf8)))
    }

    func testTypedMetricSIUnitsAndProvenance() throws {
        var report = try JSONDecoder().decode(PoseAnalysisReport.self, from: Data(schemaOneFixture.utf8))
        XCTAssertEqual(report.backswingMetric.provenance, .userEntered)
        XCTAssertEqual(report.downswingMetric.provenance, .estimated)
        XCTAssertEqual(report.tempoMetric.provenance, .estimated)
        XCTAssertEqual(report.backswingMetric.unit, "s")
        XCTAssertEqual(report.tempoMetric.unit, "1")
        XCTAssertEqual(report.tempoMetric.sampleCount, 1)
        XCTAssertEqual(report.headDisplacementMetric.unit, "1")
        XCTAssertEqual(report.headDisplacementMetric.provenance, .visionDerived)
        XCTAssertEqual(report.headDisplacementMetric.sampleCount, 5)
        XCTAssertEqual(try XCTUnwrap(report.headDisplacementMetric.value), 0.04, accuracy: 1e-10)
        XCTAssertEqual(try XCTUnwrap(report.headMovementPercent), 4, accuracy: 1e-10)
        report.markers[2].provenance = .audioDerived
        XCTAssertEqual(report.tempoMetric.provenance, .estimated)
        XCTAssertEqual(report.markers[2].metric.provenance, .audioDerived)
        report.markers[2].provenance = .userEntered
        XCTAssertEqual(report.tempoMetric.provenance, .userEntered)
        report.markers[2].provenance = .unavailable
        XCTAssertNil(report.tempoMetric.value)
        XCTAssertEqual(report.tempoMetric.provenance, .unavailable)
        report.markers[2].provenance = .simulated
        XCTAssertEqual(report.tempoMetric.provenance, .simulated)
    }

    func testInvalidOrMissingPoseMetricsRemainUnavailable() throws {
        var report = try JSONDecoder().decode(PoseAnalysisReport.self, from: Data(schemaOneFixture.utf8))
        report.markers[2].time = 1.8
        XCTAssertNil(report.downswingMetric.value)
        XCTAssertNil(report.tempoMetric.value)
        report.markers[0].time = .nan
        XCTAssertNil(report.backswingMetric.value)
        XCTAssertNil(report.headDisplacementMetric.value)
        report = try JSONDecoder().decode(PoseAnalysisReport.self, from: Data(schemaOneFixture.utf8))
        report.frames[2].joints = []
        XCTAssertNil(report.headDisplacementMetric.value)
        XCTAssertEqual(report.headDisplacementMetric.provenance, .unavailable)
        XCTAssertEqual(report.headDisplacementMetric.sampleCount, 4)
        report.markers = []
        XCTAssertNil(report.tempoMetric.value)
        XCTAssertNil(report.headMovementPercent)
    }
}
