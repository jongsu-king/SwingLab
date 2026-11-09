#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SwingLabCore

final class LaunchReadoutTests: XCTestCase {
    private let mph = 0.44704
    private func measured(speed: Double, angleDegrees: Double, provenance: Provenance = .visionDerived) -> LaunchMeasurement {
        LaunchMeasurement(
            ballSpeed: ProvenancedValue(value: speed, unit: "m/s", provenance: provenance, confidence: 0.8, method: LaunchTracker.method, sampleCount: 3),
            launchAngle: ProvenancedValue(value: angleDegrees * .pi / 180, unit: "rad", provenance: provenance, confidence: 0.8,
                                          method: LaunchTracker.method, sampleCount: 3),
            relativeSpeedUncertainty: 0.02, residualPixels: 0.3, observations: [])
    }

    // MARK: Bounce and roll

    func testLandingSpeedIsReportedAndRunStaysPlausibleForTourShots() throws {
        let drive = try BallFlight.simulate(.init(ballSpeed: 167 * mph, launchAngle: 10.9, spinRate: 2686))
        let seven = try BallFlight.simulate(.init(ballSpeed: 120 * mph, launchAngle: 16.3, spinRate: 7097))
        for flight in [drive, seven] {
            XCTAssertTrue(flight.landingSpeed > 0 && flight.landingSpeed < flight.carry)
            XCTAssertLessThan(flight.landingSpeed, 167 * mph)
        }
        let driveRun = try BallRoll.run(landingSpeed: drive.landingSpeed, landingAngleDegrees: drive.landingAngle,
                                        landingSpinRate: drive.landingSpinRate)
        let sevenRun = try BallRoll.run(landingSpeed: seven.landingSpeed, landingAngleDegrees: seven.landingAngle,
                                        landingSpinRate: seven.landingSpinRate)
        // A tour drive runs tens of metres on a fairway; a 7-iron a handful. These brackets are
        // sanity bounds for an unvalidated model, not accuracy claims (Docs/Physics.md).
        XCTAssertTrue((10...45).contains(driveRun.run), "\(driveRun.run)")
        XCTAssertTrue((2...20).contains(sevenRun.run), "\(sevenRun.run)")
        XCTAssertGreaterThan(driveRun.run, sevenRun.run)
        XCTAssertGreaterThan(driveRun.bounceCount, 0)
        XCTAssertEqual(driveRun.model, TurfSurface.fairway.id)
        // In a vacuum the ball lands as fast as it left.
        let vacuum = try BallFlight.simulate(.init(ballSpeed: 40, launchAngle: 30, spinRate: 3000), coefficients: .vacuum)
        XCTAssertEqual(vacuum.landingSpeed, 40, accuracy: 0.01)
    }

    func testRollRespondsToSpinAngleAndSurface() throws {
        let low = try BallRoll.run(landingSpeed: 30, landingAngleDegrees: 45, landingSpinRate: 3000)
        let high = try BallRoll.run(landingSpeed: 30, landingAngleDegrees: 45, landingSpinRate: 8000)
        XCTAssertGreaterThan(low.run, high.run)
        let flat = try BallRoll.run(landingSpeed: 30, landingAngleDegrees: 25, landingSpinRate: 3000)
        XCTAssertGreaterThan(flat.run, low.run)
        let soft = TurfSurface(rollingDeceleration: 4, tiltAtReference: TurfSurface.fairway.tiltAtReference, id: "test.soft")
        XCTAssertLessThan(try BallRoll.run(landingSpeed: 30, landingAngleDegrees: 45, landingSpinRate: 3000, surface: soft).run, low.run)
        // A steep, high-spin wedge can back up, but never by more than a few metres.
        let lob = try BallRoll.run(landingSpeed: 20, landingAngleDegrees: 60, landingSpinRate: 10_000)
        XCTAssertTrue(lob.run > -8 && lob.run < 5, "\(lob.run)")
        // Dropped straight down with no speed: nothing happens.
        XCTAssertEqual(try BallRoll.run(landingSpeed: 0, landingAngleDegrees: 90, landingSpinRate: 0).run, 0, accuracy: 1e-9)
        XCTAssertEqual(BallRoll.restitution(0), 0.51, accuracy: 1e-9)
        XCTAssertEqual(BallRoll.restitution(20.8), 0.12, accuracy: 0.001)
        XCTAssertLessThanOrEqual(BallRoll.restitution(100), 0.9)
        for (speed, angle, spin) in [(-1.0, 45.0, 0.0), (30.0, 95.0, 0.0), (30.0, 45.0, .nan), (120.0, 45.0, 0.0)] {
            XCTAssertThrowsError(try BallRoll.run(landingSpeed: speed, landingAngleDegrees: angle, landingSpinRate: spin))
        }
        XCTAssertThrowsError(try BallRoll.run(landingSpeed: 30, landingAngleDegrees: 45, landingSpinRate: 0,
                                              surface: TurfSurface(rollingDeceleration: 0, tiltAtReference: 0, id: "bad")))
    }

    // MARK: Club speed and auto club

    func testClubSpeedIsAnEstimateFromPublishedSmashFactors() throws {
        let smash = try XCTUnwrap(ReferenceLaunchData.smashAssumption(club: .iron7))
        XCTAssertTrue(smash.lowerSI >= 1.2 && smash.upperSI <= 1.5 && smash.lowerSI < smash.upperSI)
        XCTAssertFalse(smash.citations.isEmpty)
        let speed = ProvenancedValue(value: 54, unit: "m/s", provenance: .visionDerived, confidence: 0.7, method: LaunchTracker.method)
        let range = try XCTUnwrap(LaunchReadoutBuilder.estimatedClubSpeed(ballSpeed: speed, club: .iron7))
        XCTAssertEqual(try XCTUnwrap(range.low.value), 54 / smash.upperSI, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(range.high.value), 54 / smash.lowerSI, accuracy: 1e-9)
        XCTAssertEqual(range.provenance, .estimated)
        XCTAssertEqual(range.low.confidence, 0.7)
        XCTAssertEqual(range.low.unit, "m/s")
        let guessed = ProvenancedValue(value: 54, unit: "m/s", provenance: .estimated, method: "guess")
        XCTAssertNil(LaunchReadoutBuilder.estimatedClubSpeed(ballSpeed: guessed, club: .iron7))
    }

    func testNearestClubFollowsPublishedRowsAndRefusesEstimates() throws {
        func guess(_ speedMph: Double, _ angle: Double, provenance: Provenance = .visionDerived) -> ClubGuess? {
            ReferenceLaunchData.nearestClub(
                ballSpeed: ProvenancedValue(value: speedMph * mph, unit: "m/s", provenance: provenance, method: "t"),
                launchAngle: ProvenancedValue(value: angle * .pi / 180, unit: "rad", provenance: provenance, method: "t"))
        }
        XCTAssertEqual(try XCTUnwrap(guess(123, 16.1)).club, .iron7)      // PGA 2023 7-iron row
        XCTAssertEqual(try XCTUnwrap(guess(171, 10.4)).club, .driver)     // PGA 2023 driver row
        XCTAssertEqual(try XCTUnwrap(guess(88, 25.2)).club, .pitchingWedge) // LPGA 2023 PW row
        let exact = try XCTUnwrap(guess(123, 16.1))
        XCTAssertEqual(exact.distance, 0, accuracy: 1e-9)
        XCTAssertEqual(exact.rowID, "trackman.pga.2023.iron7")
        XCTAssertTrue((0...1).contains(exact.confidence))
        XCTAssertNotEqual(exact.runnerUp, .iron7)
        XCTAssertGreaterThan(exact.confidence, 0.5)
        // Far from every published row the guess is still made, but with no confidence.
        let far = try XCTUnwrap(guess(60, 40))
        XCTAssertLessThan(far.confidence, 0.2)
        XCTAssertGreaterThan(far.distance, 4)
        XCTAssertNil(guess(123, 16.1, provenance: .estimated))
        XCTAssertNil(guess(123, 16.1, provenance: .userEntered))
    }

    // MARK: Readout

    func testReadoutKeepsEveryTileHonest() throws {
        let readout = try XCTUnwrap(LaunchReadoutBuilder.build(measurement: measured(speed: 54, angleDegrees: 16), club: .iron7))
        XCTAssertEqual(readout.club, .iron7)
        XCTAssertNil(readout.clubGuess)
        XCTAssertEqual(readout.ballSpeed.provenance, .visionDerived)
        XCTAssertEqual(readout.launchAngle.provenance, .visionDerived)
        let carry = try XCTUnwrap(readout.carry), total = try XCTUnwrap(readout.total), apex = try XCTUnwrap(readout.apex)
        let spin = try XCTUnwrap(readout.spin), clubSpeed = try XCTUnwrap(readout.clubSpeed)
        for range in [carry, total, apex] {
            XCTAssertEqual(range.provenance, .simulated)
            XCTAssertEqual(range.low.unit, "m")
            XCTAssertTrue(try XCTUnwrap(range.low.value) <= XCTUnwrap(range.high.value))
            XCTAssertEqual(range.low.sampleCount, LaunchReadoutBuilder.spinSampleCount)
        }
        XCTAssertGreaterThan(try XCTUnwrap(total.low.value), try XCTUnwrap(carry.low.value))
        XCTAssertGreaterThan(try XCTUnwrap(total.high.value), try XCTUnwrap(carry.high.value))
        XCTAssertEqual(total.low.method, LaunchReadoutBuilder.totalMethod)
        XCTAssertEqual(carry.low.method, CarryRangeEstimator.method)
        // The carry bracket matches the existing estimator.
        let legacy = try XCTUnwrap(CarryRangeEstimator.estimate(ballSpeed: readout.ballSpeed, launchAngle: readout.launchAngle, club: .iron7))
        XCTAssertEqual(try XCTUnwrap(carry.low.value), try XCTUnwrap(legacy.shortest.value), accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(carry.high.value), try XCTUnwrap(legacy.longest.value), accuracy: 1e-6)
        XCTAssertEqual(spin.provenance, .reference)
        XCTAssertEqual(spin.low.unit, "rpm")
        XCTAssertEqual(try XCTUnwrap(spin.low.value), legacy.spinRevolutionsPerMinute.lowerBound, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(spin.high.value), legacy.spinRevolutionsPerMinute.upperBound, accuracy: 1e-9)
        XCTAssertEqual(clubSpeed.provenance, .estimated)
        XCTAssertFalse(readout.trajectory.isEmpty)
        let landing = try XCTUnwrap(readout.trajectory.last)
        let shortest = try XCTUnwrap(carry.low.value), longest = try XCTUnwrap(carry.high.value)
        XCTAssertTrue(landing.forward >= shortest - 0.01 && landing.forward <= longest + 0.01)
        XCTAssertEqual(landing.height, 0, accuracy: 1e-6)
        XCTAssertFalse(readout.citations.isEmpty)
        XCTAssertEqual(readout.surface, .fairway)
        // The animated scene uses the middle flight and its run; it rests inside the total bracket.
        XCTAssertGreaterThan(readout.run, 0)
        let rest = readout.playback.rest
        let shortestTotal = try XCTUnwrap(total.low.value), longestTotal = try XCTUnwrap(total.high.value)
        XCTAssertTrue(rest.forward >= shortestTotal - 0.01 && rest.forward <= longestTotal + 0.01)
        XCTAssertEqual(rest.right, 0, accuracy: 1e-9)
    }

    func testReadoutChoosesTheClubAutomaticallyAndRefusesEstimatedSpeeds() throws {
        let auto = try XCTUnwrap(LaunchReadoutBuilder.build(measurement: measured(speed: 123 * mph, angleDegrees: 16.1), club: nil))
        XCTAssertEqual(auto.club, .iron7)
        XCTAssertEqual(auto.clubGuess?.club, .iron7)
        let drive = try XCTUnwrap(LaunchReadoutBuilder.build(measurement: measured(speed: 171 * mph, angleDegrees: 10.4), club: nil))
        XCTAssertEqual(drive.club, .driver)
        XCTAssertGreaterThan(try XCTUnwrap(drive.total?.low.value), try XCTUnwrap(auto.total?.high.value))
        XCTAssertNil(LaunchReadoutBuilder.build(measurement: measured(speed: 54, angleDegrees: 16, provenance: .estimated), club: .iron7))
        XCTAssertNil(LaunchReadoutBuilder.build(measurement: measured(speed: 54, angleDegrees: 16, provenance: .userEntered), club: nil))
    }

    // MARK: Setup and strobe

    func testSetupVerdictsAndCameraDistance() throws {
        func scale(_ diameter: Double, x: Double) -> BallScale {
            BallScale(center: PixelPoint(x: x, y: 300), diameterPixels: diameter, diameterStandardDeviation: 0.3, frameCount: 4)
        }
        let focal = try XCTUnwrap(LaunchSetupChecker.focalLengthPixels(fieldOfViewDegrees: 60, widthPixels: 1280))
        XCTAssertEqual(focal, 640 / tan(30 * Double.pi / 180), accuracy: 1e-6)
        // A 14 px ball three metres away in a 720-wide frame: ready, and the distance is reported.
        let ready = LaunchSetupChecker.check(scale: scale(14, x: 47), frameRate: 240, regionWidth: 468, targetDirection: 1, focalLengthPixels: focal)
        XCTAssertEqual(ready.verdict, .ready)
        XCTAssertEqual(try XCTUnwrap(ready.cameraDistance.value), focal * 42.67 / 14 / 1000, accuracy: 1e-9)
        XCTAssertEqual(ready.cameraDistance.provenance, .visionDerived)
        XCTAssertGreaterThan(ready.framesInView, LaunchSetupChecker.minimumFramesInView)
        // Flying the other way with the ball near the left edge leaves no room: too close.
        XCTAssertEqual(LaunchSetupChecker.check(scale: scale(14, x: 47), frameRate: 240, regionWidth: 468, targetDirection: -1,
                                                focalLengthPixels: focal).verdict, .tooClose)
        // One metre away the ball is 42 px and crosses the region in under two frames.
        let close = LaunchSetupChecker.check(scale: scale(42, x: 47), frameRate: 240, regionWidth: 468, targetDirection: 1, focalLengthPixels: nil)
        XCTAssertEqual(close.verdict, .tooClose)
        XCTAssertNil(close.cameraDistance.value)
        XCTAssertEqual(close.cameraDistance.provenance, .unavailable)
        XCTAssertEqual(LaunchSetupChecker.check(scale: scale(8, x: 47), frameRate: 240, regionWidth: 468, targetDirection: 1,
                                                focalLengthPixels: focal).verdict, .tooFar)
        XCTAssertNil(LaunchSetupChecker.focalLengthPixels(fieldOfViewDegrees: 0, widthPixels: 1280))
        XCTAssertNil(LaunchSetupChecker.focalLengthPixels(fieldOfViewDegrees: 60, widthPixels: 0))
        for verdict in LaunchSetupCheck.Verdict.allCases { XCTAssertFalse(verdict.localizationKey.rawValue.isEmpty) }
    }

    func testStrobeKeepsTheBrightestPixelOfEveryFrame() {
        let shot = LaunchScene.shot(speed: 54, angleDegrees: 16)
        let strobe = LaunchStrobe.compose(reference: shot.address[0], flight: shot.flight.map(\.image))
        XCTAssertEqual(strobe.width, LaunchScene.width)
        for frame in [shot.address[0]] + shot.flight.map(\.image) {
            for index in stride(from: 0, to: frame.pixels.count, by: 97) { XCTAssertGreaterThanOrEqual(strobe.pixels[index], frame.pixels[index]) }
        }
        // The ball is bright at address and in every flight frame.
        XCTAssertGreaterThan(strobe[Int(LaunchScene.address.x), Int(LaunchScene.address.y)], 0.8)
        // Mismatched sizes are ignored rather than crashing.
        XCTAssertEqual(LaunchStrobe.compose(reference: shot.address[0], flight: [GrayImage(width: 2, height: 2, fill: 1)]).pixels,
                       shot.address[0].pixels)
    }

    func testReferenceProvenanceRoundTripsAndStaysOutOfMeasuredChecks() throws {
        XCTAssertEqual(try JSONDecoder().decode(Provenance.self, from: JSONEncoder().encode(Provenance.reference)), .reference)
        XCTAssertEqual(Provenance(legacyValue: "Reference — published averages"), .reference)
        XCTAssertEqual(Provenance.reference.category, .reference)
        let value = ProvenancedValue(value: 7000, unit: "rpm", provenance: .reference, method: "t")
        XCTAssertNil(CarryRangeEstimator.estimate(
            ballSpeed: ProvenancedValue(value: 54, unit: "m/s", provenance: .reference, method: "t"),
            launchAngle: ProvenancedValue(value: 0.28, unit: "rad", provenance: .reference, method: "t"), club: .iron7))
        XCTAssertEqual(value.provenance, .reference)
    }
}

final class LaunchSessionTests: XCTestCase {
    private func shot(_ seconds: Double, _ club: ReferenceClub, speed: Double, angle: Double, carry: ClosedRange<Double>? = nil) -> LaunchSessionShot {
        LaunchSessionShot(time: Date(timeIntervalSince1970: seconds), club: club, ballSpeed: speed, launchAngle: angle * .pi / 180, carry: carry)
    }

    func testSummariesAverageEachClubAndSpreadNeedsFiveShots() throws {
        var shots = [shot(1, .iron7, speed: 54, angle: 16, carry: 170...174), shot(2, .iron7, speed: 56, angle: 15, carry: 173...177),
                     shot(3, .driver, speed: 70, angle: 11)]
        var summaries = LaunchSession.summaries(shots)
        XCTAssertEqual(summaries.map(\.club), [.driver, .iron7])
        let seven = try XCTUnwrap(summaries.first { $0.club == .iron7 })
        XCTAssertEqual(seven.count, 2)
        XCTAssertEqual(try XCTUnwrap(seven.ballSpeed.value), 55, accuracy: 1e-9)
        XCTAssertEqual(seven.ballSpeed.provenance, .visionDerived)
        XCTAssertEqual(try XCTUnwrap(seven.launchAngle.value), 15.5 * .pi / 180, accuracy: 1e-9)
        XCTAssertNil(seven.speedSpread)
        XCTAssertEqual(try XCTUnwrap(seven.carry?.low.value), 170)
        XCTAssertEqual(try XCTUnwrap(seven.carry?.high.value), 177)
        XCTAssertEqual(seven.carry?.provenance, .simulated)
        XCTAssertNil(try XCTUnwrap(summaries.first { $0.club == .driver }).carry)
        for index in 0..<3 { shots.append(shot(10 + Double(index), .iron7, speed: 55, angle: 16)) }
        summaries = LaunchSession.summaries(shots)
        let spread = try XCTUnwrap(summaries.first { $0.club == .iron7 }?.speedSpread)
        XCTAssertEqual(spread.sampleCount, 5)
        XCTAssertGreaterThan(try XCTUnwrap(spread.value), 0)
        XCTAssertTrue(LaunchSession.summaries([]).isEmpty)
    }

    func testChangeComparesWithThePreviousShotOfTheSameClub() throws {
        let shots = [shot(1, .iron7, speed: 54, angle: 16), shot(2, .driver, speed: 70, angle: 11), shot(3, .iron7, speed: 56, angle: 15)]
        let change = try XCTUnwrap(LaunchSession.change(in: shots))
        XCTAssertEqual(try XCTUnwrap(change.ballSpeed.value), 2, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(change.launchAngle.value), -1 * .pi / 180, accuracy: 1e-9)
        XCTAssertEqual(change.ballSpeed.provenance, .visionDerived)
        // The newest shot is the first with its club: nothing to compare.
        XCTAssertNil(LaunchSession.change(in: Array(shots.prefix(2))))
        XCTAssertNil(LaunchSession.change(in: []))
        // Order follows time, not the array.
        XCTAssertEqual(try XCTUnwrap(LaunchSession.change(in: shots.reversed())?.ballSpeed.value), 2, accuracy: 1e-9)
    }

    func testRecommendedDistanceBracketsTheReadyVerdict() throws {
        func scale(_ diameter: Double) -> BallScale {
            BallScale(center: PixelPoint(x: 47, y: 300), diameterPixels: diameter, diameterStandardDeviation: 0.3, frameCount: 4)
        }
        let focal = try XCTUnwrap(LaunchSetupChecker.focalLengthPixels(fieldOfViewDegrees: 60, widthPixels: 1280))
        let ready = LaunchSetupChecker.check(scale: scale(14), frameRate: 240, regionWidth: 468, targetDirection: 1, focalLengthPixels: focal)
        let band = try XCTUnwrap(ready.recommendedDistance)
        XCTAssertTrue(band.contains(try XCTUnwrap(ready.cameraDistance.value)))
        // The ends of the band are exactly where the verdict would flip.
        XCTAssertEqual(band.upperBound, focal * 42.67 / LaunchSetupChecker.minimumDiameterPixels / 1000, accuracy: 1e-9)
        let close = LaunchSetupChecker.check(scale: scale(42), frameRate: 240, regionWidth: 468, targetDirection: 1, focalLengthPixels: focal)
        XCTAssertLessThan(try XCTUnwrap(close.cameraDistance.value), try XCTUnwrap(close.recommendedDistance).lowerBound)
        let far = LaunchSetupChecker.check(scale: scale(8), frameRate: 240, regionWidth: 468, targetDirection: 1, focalLengthPixels: focal)
        XCTAssertGreaterThan(try XCTUnwrap(far.cameraDistance.value), try XCTUnwrap(far.recommendedDistance).upperBound)
        XCTAssertNil(LaunchSetupChecker.check(scale: scale(14), frameRate: 240, regionWidth: 468, targetDirection: 1, focalLengthPixels: nil).recommendedDistance)
        // No room ahead at all: no distance would do.
        XCTAssertNil(LaunchSetupChecker.check(scale: scale(14), frameRate: 240, regionWidth: 468, targetDirection: -1, focalLengthPixels: focal).recommendedDistance)
    }
}

final class RangeConditionsTests: XCTestCase {
    private func measured(speed: Double, angleDegrees: Double) -> LaunchMeasurement {
        LaunchMeasurement(
            ballSpeed: ProvenancedValue(value: speed, unit: "m/s", provenance: .visionDerived, confidence: 0.8, method: LaunchTracker.method, sampleCount: 3),
            launchAngle: ProvenancedValue(value: angleDegrees * .pi / 180, unit: "rad", provenance: .visionDerived, confidence: 0.8,
                                          method: LaunchTracker.method, sampleCount: 3),
            relativeSpeedUncertainty: 0.02, residualPixels: 0.3, observations: [])
    }

    func testStandardAtmospherePressureFollowsAltitude() {
        XCTAssertEqual(Atmosphere.pressure(atAltitude: 0), 101_325, accuracy: 1e-6)
        XCTAssertEqual(Atmosphere.pressure(atAltitude: 1_600), 83_500, accuracy: 300)     // Denver-ish
        XCTAssertEqual(Atmosphere.pressure(atAltitude: 5_000), 54_000, accuracy: 500)
        XCTAssertEqual(Atmosphere.pressure(atAltitude: 20_000), Atmosphere.pressure(atAltitude: 11_000))   // clamped
        XCTAssertEqual(Atmosphere.pressure(atAltitude: .nan), 101_325, accuracy: 1e-6)
        XCTAssertTrue(RangeConditions.standard.isStandard)
        XCTAssertTrue(RangeConditions.standard.isValid)
        XCTAssertEqual(RangeConditions.standard.atmosphere, .standard)
        XCTAssertEqual(RangeConditions.standard.wind, .calm)
        var hot = RangeConditions.standard
        hot.temperatureKelvin = 400
        XCTAssertFalse(hot.isValid)
        var gale = RangeConditions.standard
        gale.tailwind = 31
        XCTAssertFalse(gale.isValid)
    }

    func testReadoutAdoptsTheGolfersConditions() throws {
        let shot = measured(speed: 70, angleDegrees: 11)
        let standard = try XCTUnwrap(LaunchReadoutBuilder.build(measurement: shot, club: .driver, conditions: .standard))
        var tail = RangeConditions.standard; tail.tailwind = 5
        var head = RangeConditions.standard; head.tailwind = -5
        var thin = RangeConditions.standard; thin.altitudeMetres = 1_600; thin.temperatureKelvin = 303.15
        var cold = RangeConditions.standard; cold.temperatureKelvin = 273.15
        func carry(_ conditions: RangeConditions) throws -> Double {
            try XCTUnwrap(LaunchReadoutBuilder.build(measurement: shot, club: .driver, conditions: conditions)?.carry?.high.value)
        }
        let base = try carry(.standard)
        XCTAssertGreaterThan(try carry(tail), base)
        XCTAssertLessThan(try carry(head), base)
        XCTAssertGreaterThan(try carry(thin), base)
        XCTAssertLessThan(try carry(cold), base)
        // A crosswind moves the middle flight sideways; the scene follows it.
        var cross = RangeConditions.standard; cross.crosswind = 5
        let drifted = try XCTUnwrap(LaunchReadoutBuilder.build(measurement: shot, club: .driver, conditions: cross))
        XCTAssertGreaterThan(try XCTUnwrap(drifted.trajectory.last).right, 2)
        XCTAssertEqual(try XCTUnwrap(standard.trajectory.last).right, 0, accuracy: 1e-9)
        // Invalid conditions fall back to standard rather than failing or inventing.
        var broken = RangeConditions.standard; broken.temperatureKelvin = .nan
        XCTAssertEqual(try XCTUnwrap(LaunchReadoutBuilder.build(measurement: shot, club: .driver, conditions: broken)?.carry?.high.value), base, accuracy: 1e-9)
        // Still every tile keeps its provenance.
        XCTAssertEqual(drifted.carry?.provenance, .simulated)
        XCTAssertEqual(drifted.ballSpeed.provenance, .visionDerived)
    }

    func testReferenceClubsMapToBagCategoriesAndNames() {
        XCTAssertEqual(ReferenceClub.driver.bagCategoryRawValue, "Driver")
        XCTAssertEqual(ReferenceClub.wood3.bagCategoryRawValue, "Fairway Wood")
        XCTAssertEqual(ReferenceClub.iron7.bagCategoryRawValue, "Iron")
        XCTAssertEqual(ReferenceClub.pitchingWedge.bagCategoryRawValue, "Wedge")
        XCTAssertTrue(ReferenceClub.iron7.matchesBagClub(name: "7 iron", category: "Iron"))
        XCTAssertTrue(ReferenceClub.iron7.matchesBagClub(name: "P790 7", category: "Iron"))
        XCTAssertFalse(ReferenceClub.iron7.matchesBagClub(name: "8 iron", category: "Iron"))
        XCTAssertFalse(ReferenceClub.iron7.matchesBagClub(name: "7 wood", category: "Fairway Wood"))
        XCTAssertTrue(ReferenceClub.wood3.matchesBagClub(name: "3 wood", category: "Fairway Wood"))
        XCTAssertTrue(ReferenceClub.driver.matchesBagClub(name: "Qi10", category: "Driver"))
        XCTAssertTrue(ReferenceClub.hybrid.matchesBagClub(name: "4H", category: "Hybrid"))
        XCTAssertTrue(ReferenceClub.pitchingWedge.matchesBagClub(name: "PW", category: "Wedge"))
        XCTAssertFalse(ReferenceClub.pitchingWedge.matchesBagClub(name: "56", category: "Wedge"))
        for club in ReferenceClub.allCases { XCTAssertFalse(club.bagCategoryRawValue.isEmpty) }
    }
}
