// Runs the same core test methods when Apple's command-line tools omit XCTest.
import Foundation

@MainActor class XCTestCase {}
enum CheckFailure: Error { case nilValue }
@MainActor var failures = 0
@MainActor func fail(_ detail: String, file: StaticString, line: UInt) {
    failures += 1
    print("FAIL \(file):\(line): \(detail)")
}
@MainActor func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) {
    if a != b { fail("\(a) != \(b)", file: file, line: line) }
}
@MainActor func XCTAssertEqual(_ a: Double, _ b: Double, accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
    if !a.isFinite || !b.isFinite || abs(a - b) > accuracy { fail("\(a) != \(b) ± \(accuracy)", file: file, line: line) }
}
@MainActor func XCTAssertTrue(_ condition: Bool, file: StaticString = #filePath, line: UInt = #line) {
    if !condition { fail("Expected true", file: file, line: line) }
}
@MainActor func XCTAssertNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) {
    if value != nil { fail("Expected nil", file: file, line: line) }
}
@MainActor func XCTAssertLessThan<T: Comparable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) {
    if !(a < b) { fail("Expected \(a) < \(b)", file: file, line: line) }
}
@MainActor func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do { _ = try expression(); fail("Expected an error", file: file, line: line) } catch {}
}
@MainActor func XCTUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) throws -> T {
    guard let value else { fail("Unexpected nil", file: file, line: line); throw CheckFailure.nilValue }
    return value
}
@main struct CoreCheckRunner {
    @MainActor static func main() throws {
        let units = UnitsTests(), geography = GeographyTests(), dispersion = DispersionTests(), timing = TimingAndGeometryTests()
        let provenance = ProvenanceTests()
        let checks: [(String, () throws -> Void)] = [
            ("independent unit conversions", units.testIndependentUnitsRoundTrip),
            ("language fallback", units.testLanguageFallbackAndRegionalMatching),
            ("known geodesic distances", geography.testIdentityAndKnownDistance),
            ("coordinate projection", geography.testProjectionAndBearing),
            ("date-line and invalid coordinates", geography.testDateLineAndInvalidLocation),
            ("50/80/95 percent probability ellipses", dispersion.testProbabilityEllipseHasCorrectMassRadius),
            ("hazard integration and absent geometry", dispersion.testHazardHalfPlaneAndMissingGeometry),
            ("invalid statistical inputs", dispersion.testInvalidDistributionRejected),
            ("timestamp-based tempo", timing.testTempoUsesActualSeconds),
            ("invalid timing rejection", timing.testInvalidTimingRejected),
            ("joint angles and missing joints", timing.testProjectedAngleMissingJointHandling),
            ("explainable club ranking", timing.testExplainableClubRankingChangesWithRiskPreference),
            ("interrupted media deletion recovery", timing.testInterruptedMediaDeletionRecovery),
            ("stable provenance and legacy labels", provenance.testStableProvenanceAndLegacyLabels),
            ("typed recording metadata migration", provenance.testTypedRecordingMetadataMigration),
            ("measurement value invariants", provenance.testMeasurementInvariants),
            ("measurement decoding validation", provenance.testDecodingCannotBypassMeasurementValidation),
            ("schema-v1 analysis migration", provenance.testSchemaOneAnalysisJSONStillDecodes),
            ("typed metric SI units and origin", provenance.testTypedMetricSIUnitsAndProvenance),
            ("missing and invalid pose metrics", provenance.testInvalidOrMissingPoseMetricsRemainUnavailable)
        ]
        for (name, check) in checks {
            let before = failures
            do { try check() } catch { failures += 1; print("FAIL \(name): \(error)") }
            if before == failures { print("PASS \(name)") }
        }
        print("\(checks.count) test groups; \(failures) failed assertions. Portable harness, not XCTest.")
        if failures > 0 { exit(1) }
    }
}
