#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SwingLabCore

final class ShotShapeTests: XCTestCase {
    private let mph = 0.44704

    /// Each preset, simulated at a driver's speed, classifies back to its own shape for both hands.
    func testPresetsRoundTripThroughTheFlightModel() throws {
        for handedness in Handedness.allCases {
            for shape in ShotShape.allCases {
                let preset = shape.preset(for: handedness)
                let launch = LaunchConditions(ballSpeed: 160 * mph, launchAngle: 11, launchDirection: preset.launchDirection,
                                              spinRate: 2700, spinAxis: preset.spinAxis)
                let result = try BallFlight.simulate(launch)
                let classified = try XCTUnwrap(ShotShapeClassifier.classify(launch: launch, result: result, handedness: handedness))
                XCTAssertEqual(classified.shape, shape, "\(handedness) \(shape): start \(classified.startDegrees)°, curve \(classified.curveMetres) m")
                XCTAssertEqual(classified.provenance, .simulated)
            }
        }
        // A left-hander's draw curves to the right in the world frame.
        let lefty = ShotShape.draw.preset(for: .left)
        XCTAssertGreaterThan(lefty.spinAxis, 0)
        XCTAssertEqual(lefty.spinAxis, -ShotShape.draw.preset.spinAxis)
    }

    func testClassificationThresholdsAndInvalidInputs() throws {
        let straight = LaunchConditions(ballSpeed: 60, launchAngle: 12, launchDirection: 1.5, spinRate: 2700)
        let result = try BallFlight.simulate(straight)
        let classified = try XCTUnwrap(ShotShapeClassifier.classify(launch: straight, result: result))
        XCTAssertEqual(classified.shape, .straight)   // 1.5° is inside the 2° start window
        XCTAssertEqual(classified.curveMetres, 0, accuracy: 0.5)
        XCTAssertEqual(classified.startDegrees, 1.5)
        // A level launch on the ground has no carry: nothing to classify.
        let level = LaunchConditions(ballSpeed: 60, launchAngle: 0, spinRate: 2700)
        XCTAssertNil(ShotShapeClassifier.classify(launch: level, result: try BallFlight.simulate(level)))
        XCTAssertEqual(ShotShape.allCases.count, 13)
        XCTAssertEqual(Set(ShotShape.allCases.map(\.localizationKey.rawValue)).count, 13)
    }

    func testPlaybackInterpolatesFlightAndRollsOutAfterLanding() throws {
        let launch = LaunchConditions(ballSpeed: 70, launchAngle: 11, launchDirection: 3, spinRate: 2500, spinAxis: -10)
        let flight = try BallFlight.simulate(launch)
        let playback = FlightPlayback(samples: flight.trajectory, run: 15, rollDuration: 2)
        XCTAssertEqual(playback.flightTime, flight.flightTime, accuracy: 1e-9)
        XCTAssertEqual(playback.duration, flight.flightTime + 2, accuracy: 1e-9)
        // Exactly on a sample.
        let sample = flight.trajectory[flight.trajectory.count / 2]
        let onSample = playback.position(at: sample.time)
        XCTAssertEqual(onSample.forward, sample.forward, accuracy: 1e-9)
        XCTAssertEqual(onSample.height, sample.height, accuracy: 1e-9)
        XCTAssertEqual(onSample.right, sample.right, accuracy: 1e-9)
        XCTAssertFalse(onSample.rolling)
        // Between samples the ball moves forward monotonically and never dips below the ground.
        var previous = 0.0
        for step in stride(from: 0.0, through: playback.duration, by: 0.01) {
            let position = playback.position(at: step)
            XCTAssertGreaterThanOrEqual(position.forward, previous - 1e-9)
            XCTAssertGreaterThanOrEqual(position.height, 0)
            previous = position.forward
        }
        // After landing it rolls along the landing direction and stops at carry + run.
        let landing = try XCTUnwrap(playback.landing)
        let midRoll = playback.position(at: flight.flightTime + 1)
        XCTAssertTrue(midRoll.rolling)
        XCTAssertEqual(midRoll.height, 0)
        XCTAssertGreaterThan(midRoll.forward, landing.forward)
        let rest = playback.position(at: playback.duration + 5)
        let expected = playback.rest
        XCTAssertEqual(rest.forward, expected.forward, accuracy: 1e-9)
        XCTAssertEqual(rest.right, expected.right, accuracy: 1e-9)
        XCTAssertEqual(hypot(expected.forward - landing.forward, expected.right - landing.right), 15, accuracy: 1e-9)
        // Before launch, and with no run, the ball sits where it was.
        XCTAssertEqual(playback.position(at: -1).forward, 0)
        let noRun = FlightPlayback(samples: flight.trajectory)
        XCTAssertEqual(noRun.duration, flight.flightTime, accuracy: 1e-9)
        XCTAssertEqual(noRun.position(at: 100).forward, landing.forward, accuracy: 1e-9)
        XCTAssertEqual(FlightPlayback(samples: []).position(at: 1).forward, 0)
    }
}
