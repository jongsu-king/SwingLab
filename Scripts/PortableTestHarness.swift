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
        let provenance = ProvenanceTests(), summary = SummaryMigrationTests(), phases = PhaseDetectionTests()
        let audio = ImpactOnsetTests(), flight = BallFlightTests(), coaching = CoachingTests(), grouping = PracticeGroupingTests()
        let launch = LaunchMonitorTests(), live = LaunchMonitorLiveTests()
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
            ("missing and invalid pose metrics", provenance.testInvalidOrMissingPoseMetricsRemainUnavailable),
            ("schema-v1 summary migration", summary.testSchemaOneSummaryMigrationPreservesProvenanceAndSI),
            ("missing analysis summary unavailable", summary.testMissingAnalysisRemainsUnavailable),
            ("current summary version and frame rate", summary.testCurrentSummaryPreservesVersionAndFrameRate),
            ("zero-phase smoothing peak timing", phases.testZeroPhaseSmoothingPreservesPeakTiming),
            ("phase detector at 30/60/120/240 fps", phases.testDetectorRecoversKnownEventsAcrossFrameRates),
            ("phase detector with landmark noise", phases.testNoisyLandmarksStayWithinNoiseLimitedTolerance),
            ("mixed coarse/dense phases", phases.testMixedCoarseAndDensePassRetainsAddressAndFinish),
            ("impact absent across long wrist gap", phases.testLongWristGapCannotBecomeAnImpact),
            ("left-handed mirror timing", phases.testLeftHandedMirrorProducesSameTiming),
            ("no swing returns no guesses", phases.testNoSwingOrMissingBodyReturnsNoGuesses),
            ("manual markers win on merge", phases.testMergeKeepsUserMarkersAndDropsConflictingEstimates),
            ("audio click timed within 1 ms", audio.testClickInNoiseIsTimedWithinOneMillisecond),
            ("clipped audio click", audio.testClippedClickIsStillTimed),
            ("two comparable clicks rejected", audio.testTwoComparableClicksAreAmbiguous),
            ("weak secondary transient", audio.testWeakSecondaryTransientDoesNotBlockTheImpact),
            ("audio candidate nearest pose", audio.testSelectsNearestPoseCandidateRatherThanLoudestNeighbor),
            ("no click or click outside window", audio.testNoClickOrClickOutsideWindowFindsNothing),
            ("transient far from pose impact", audio.testTransientFarFromPoseImpactIsRejected),
            ("faint click and invalid audio", audio.testFaintClickStaysEstimatedAndInvalidInputIsRejected),
            ("audio impact replaces pose proxy", audio.testAudioImpactReplacesPoseProxyOnlyWhenClearAndOrdered),
            ("flight integrator vs vacuum closed form", flight.testIntegratorMatchesClosedFormProjectileInVacuum),
            ("flight vs tour reference shots", flight.testReferenceShotsAgainstTourAverages),
            ("spin axis and start direction", flight.testSpinAxisAndStartDirectionCurveTheRightWay),
            ("wind, air density, landing height", flight.testWindAirDensityAndLandingHeight),
            ("invalid flight inputs", flight.testInvalidOrUnreachableInputsThrow),
            ("ground-level nonascending flight", flight.testLevelAndDownwardLaunchTouchFlatGroundImmediately),
            ("summary statistics", coaching.testSummaryStatistics),
            ("coaching needs five comparable swings", coaching.testFewerThanFiveComparableSwingsGivesNoStatement),
            ("coaching baseline shift templates", coaching.testShiftFromOwnBaselineUsesTheRightTemplate),
            ("coaching excludes other angles and clubs", coaching.testOtherAnglesClubsFutureAndUnavailableValuesAreExcluded),
            ("coaching baseline limited to recent 20", coaching.testBaselineIsLimitedToTheMostRecentTwenty),
            ("unanalyzed swings preserve baseline", coaching.testUnanalyzedRecordingsDoNotEvictTheAnalyzedBaseline),
            ("unknown angles cannot define baseline", coaching.testUnknownCameraAnglesDoNotEstablishAComparableBaseline),
            ("empty coaching is not a comparison", coaching.testEmptyFeedbackDoesNotImplyAValidComparison),
            ("rolling 90-minute practice grouping", grouping.testRollingNinetyMinuteWindowAndBoundary),
            ("practice context separates unknown values", grouping.testUnknownClubAngleAndHandednessStaySeparate),
            ("practice grouping deterministic ties", grouping.testEqualTimesAndDuplicateInputsAreDeterministic),
            ("practice matching recent compatible session", grouping.testAssignChoosesMostRecentCompatiblePastSession),
            ("launch: ball scale from address frames", launch.testBallScaleFromAddressFrames),
            ("launch: synthetic 7-iron and driver", launch.testSevenIronAndDriverLaunchesAreMeasuredOnSyntheticFrames),
            ("launch: refusals", launch.testLongExposureNoBallAndTooFewPointsAreRefused),
            ("launch: carry is a simulated range", launch.testCarryIsASimulatedRangeFromCitedSpin),
            ("live launch: clockwise crop", live.testClockwiseCropMatchesCropOfRotatedFrame),
            ("live launch: frame ring", live.testFrameRingKeepsNewestFramesInOrder),
            ("live launch: streaming impact trigger", live.testStreamingTriggerTimesStrikesAndIgnoresEchoes),
            ("live launch: streamed shot within latency budget", live.testLiveSessionMeasuresAStreamedShotWithinTheLatencyBudget),
            ("live launch: missing history reported", live.testStrikeHeardBeforeEnoughHistoryIsReportedAsMissed)
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
