#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SwingLabCore

final class BallFlightTests: XCTestCase {
    private let yard = 0.9144, mph = 0.44704
    private var driver: LaunchConditions { .init(ballSpeed: 167 * mph, launchAngle: 10.9, spinRate: 2686) }
    private var sevenIron: LaunchConditions { .init(ballSpeed: 120 * mph, launchAngle: 16.3, spinRate: 7097) }

    func testIntegratorMatchesClosedFormProjectileInVacuum() throws {
        for angle in [10.0, 30.0, 45.0] {
            let speed = 40.0
            let result = try BallFlight.simulate(.init(ballSpeed: speed, launchAngle: angle, spinRate: 3000), coefficients: .vacuum)
            let radians = angle * .pi / 180
            XCTAssertEqual(result.carry, speed * speed * sin(2 * radians) / BallFlight.gravity, accuracy: 0.01)
            XCTAssertEqual(result.apex, pow(speed * sin(radians), 2) / (2 * BallFlight.gravity), accuracy: 0.01)
            XCTAssertEqual(result.flightTime, 2 * speed * sin(radians) / BallFlight.gravity, accuracy: 0.002)
            XCTAssertEqual(result.landingAngle, angle, accuracy: 0.01)
        }
    }

    /// Widely cited TrackMan PGA Tour averages (see Docs/Physics.md for the source note).
    /// The cited model matches driver carry but overestimates high-spin lift, so the 7-iron
    /// tolerance is wider and the apex is only bounded. These are documented gaps, not tuning targets.
    func testReferenceShotsAgainstTourAverages() throws {
        let drive = try BallFlight.simulate(driver)
        XCTAssertEqual(drive.carry / yard, 275, accuracy: 275 * 0.05)
        XCTAssertTrue(drive.apex / yard > 28 && drive.apex / yard < 46)
        let iron = try BallFlight.simulate(sevenIron)
        XCTAssertEqual(iron.carry / yard, 172, accuracy: 172 * 0.10)
        XCTAssertTrue(iron.apex / yard > 28 && iron.apex / yard < 42)
        XCTAssertTrue(iron.landingAngle > drive.landingAngle)
        XCTAssertLessThan(drive.landingSpinRate, 2686)
        XCTAssertEqual(drive.carryMetric.provenance, .simulated)
        XCTAssertEqual(drive.carryMetric.unit, "m")
        XCTAssertEqual(drive.carryMetric.method, AeroCoefficients.smitsSmith1994.id)
    }

    func testSpinAxisAndStartDirectionCurveTheRightWay() throws {
        let fade = try BallFlight.simulate(.init(ballSpeed: 70, launchAngle: 12, spinRate: 2800, spinAxis: 10))
        let draw = try BallFlight.simulate(.init(ballSpeed: 70, launchAngle: 12, spinRate: 2800, spinAxis: -10))
        XCTAssertTrue(fade.landingPoint.right > 5)
        XCTAssertEqual(fade.landingPoint.right, -draw.landingPoint.right, accuracy: 1e-6)
        XCTAssertEqual(fade.carry, draw.carry, accuracy: 1e-6)
        let pushed = try BallFlight.simulate(.init(ballSpeed: 70, launchAngle: 12, launchDirection: 5, spinRate: 2800))
        // A straight ball started 5° right lands about carry × tan(5°) right of the line.
        XCTAssertEqual(pushed.landingPoint.right, pushed.landingPoint.forward * tan(5 * .pi / 180), accuracy: 0.5)
    }

    func testWindAirDensityAndLandingHeight() throws {
        let still = try BallFlight.simulate(driver)
        XCTAssertTrue(try BallFlight.simulate(driver, wind: .init(tailwind: 5, rightward: 0)).carry > still.carry)
        XCTAssertTrue(try BallFlight.simulate(driver, wind: .init(tailwind: -5, rightward: 0)).carry < still.carry)
        XCTAssertTrue(try BallFlight.simulate(driver, wind: .init(tailwind: 0, rightward: 5)).landingPoint.right > 3)
        // Thinner air (≈ 1,600 m station pressure, warm) flies farther; humid air is slightly thinner than dry air.
        let altitude = Atmosphere(temperature: 303.15, pressure: 83_500, relativeHumidity: 0.3)
        XCTAssertTrue(altitude.density < Atmosphere.standard.density)
        XCTAssertTrue(try BallFlight.simulate(driver, atmosphere: altitude).carry > still.carry * 1.03)
        XCTAssertLessThan(Atmosphere(temperature: 303.15, pressure: 101_325, relativeHumidity: 1).density,
                          Atmosphere(temperature: 303.15, pressure: 101_325, relativeHumidity: 0).density)
        XCTAssertEqual(Atmosphere(temperature: 288.15, pressure: 101_325, relativeHumidity: 0).density, 1.225, accuracy: 0.001)
        XCTAssertTrue(try BallFlight.simulate(driver, landingHeight: 10).carry < still.carry)
        XCTAssertTrue(try BallFlight.simulate(driver, landingHeight: -10).carry > still.carry)
    }

    func testInvalidOrUnreachableInputsThrow() {
        XCTAssertThrowsError(try BallFlight.simulate(.init(ballSpeed: .nan, launchAngle: 10, spinRate: 2500)))
        XCTAssertThrowsError(try BallFlight.simulate(.init(ballSpeed: 0, launchAngle: 10, spinRate: 2500)))
        XCTAssertThrowsError(try BallFlight.simulate(.init(ballSpeed: 70, launchAngle: 95, spinRate: 2500)))
        XCTAssertThrowsError(try BallFlight.simulate(.init(ballSpeed: 70, launchAngle: 10, spinRate: -1)))
        XCTAssertThrowsError(try BallFlight.simulate(driver, atmosphere: .init(temperature: 20, pressure: 101_325, relativeHumidity: 0.5)))
        // A landing height above the apex is never reached.
        XCTAssertThrowsError(try BallFlight.simulate(driver, landingHeight: 60))
    }
}
