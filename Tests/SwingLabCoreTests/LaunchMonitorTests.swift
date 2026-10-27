#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SwingLabCore

/// Renders a 480×360 face-on region: textured turf-like background and a 42.67 mm ball drawn at
/// 0.4922 px/mm (≈ 21 px), anti-aliased by 4×4 supersampling and smeared over the exposure window.
enum LaunchScene {
    static let width = 480, height = 360
    static let pixelsPerMillimetre = 0.4922
    static let address = PixelPoint(x: 120.3, y: 280.6)
    static var radius: Double { BallScaleFitter.ballDiameterMillimetres * pixelsPerMillimetre / 2 }

    static func background() -> GrayImage {
        var seed: UInt64 = 0x6E55
        var image = GrayImage(width: width, height: height, fill: 0)
        for y in 0..<height { for x in 0..<width {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let noise = Float(Double(seed >> 11) / Double(1 << 53) - 0.5) * 0.08
            image[x, y] = 0.30 + Float(y) / Float(height) * 0.08 + noise
        } }
        return image
    }

    /// Ball positions sampled across the exposure window are averaged, which produces the blur streak.
    static func frame(centers: [PixelPoint], on base: GrayImage) -> GrayImage {
        var image = base
        guard !centers.isEmpty else { return image }
        let r = radius, reach = Int(r) + 2
        let minX = max(0, Int(centers.map(\.x).min()!) - reach), maxX = min(width - 1, Int(centers.map(\.x).max()!) + reach)
        let minY = max(0, Int(centers.map(\.y).min()!) - reach), maxY = min(height - 1, Int(centers.map(\.y).max()!) + reach)
        guard minX <= maxX, minY <= maxY else { return image }
        for y in minY...maxY { for x in minX...maxX {
            var coverage = 0.0
            for center in centers { for sy in 0..<4 { for sx in 0..<4 {
                let px = Double(x) + (Double(sx) + 0.5) / 4, py = Double(y) + (Double(sy) + 0.5) / 4
                if hypot(px - center.x, py - center.y) <= r { coverage += 1 }
            } } }
            coverage /= Double(16 * centers.count)
            image[x, y] = Float(Double(image[x, y]) * (1 - coverage) + 0.95 * coverage)
        } }
        return image
    }

    /// Launch at `launchTime`; frames at k/fps. Returns address frames (ball still) and flight frames.
    static func shot(speed: Double, angleDegrees: Double, fps: Double = 240, exposure: Double = 1.0 / 2000,
                     launchTime: Double = 0.0021) -> (address: [GrayImage], flight: [(time: Double, image: GrayImage)]) {
        let base = background()
        let still = frame(centers: [address], on: base)
        let pxPerSecond = speed * 1000 * pixelsPerMillimetre, angle = angleDegrees * .pi / 180
        func center(at t: Double) -> PixelPoint {
            let dt = max(0, t - launchTime)
            return PixelPoint(x: address.x + pxPerSecond * cos(angle) * dt, y: address.y - pxPerSecond * sin(angle) * dt)
        }
        let flight = (1...4).map { k -> (time: Double, image: GrayImage) in
            let start = Double(k) / fps
            let samples = (0..<12).map { center(at: start + exposure * (Double($0) + 0.5) / 12) }
            return (start, frame(centers: samples, on: base))
        }
        return ([still, still, still, still], flight)
    }
}

final class LaunchMonitorTests: XCTestCase {
    func testBallScaleFromAddressFrames() throws {
        let shot = LaunchScene.shot(speed: 54, angleDegrees: 16)
        let scale = try XCTUnwrap(BallScaleFitter.fit(frames: shot.address, near: PixelPoint(x: 118, y: 282), searchRadius: 24))
        XCTAssertEqual(scale.diameterPixels, 2 * LaunchScene.radius, accuracy: 0.3)
        XCTAssertEqual(scale.center.x, LaunchScene.address.x, accuracy: 0.3)
        XCTAssertEqual(scale.center.y, LaunchScene.address.y, accuracy: 0.3)
        XCTAssertEqual(scale.millimetresPerPixel, 1 / LaunchScene.pixelsPerMillimetre, accuracy: 0.03)
        // No ball near the guess: no scale.
        XCTAssertNil(BallScaleFitter.fit(frames: [LaunchScene.background()], near: PixelPoint(x: 300, y: 100), searchRadius: 24))
    }

    func testSevenIronAndDriverLaunchesAreMeasuredOnSyntheticFrames() throws {
        for (speed, angle) in [(54.0, 16.0), (74.0, 10.5), (40.0, 24.0)] {
            let shot = LaunchScene.shot(speed: speed, angleDegrees: angle)
            let scale = try XCTUnwrap(BallScaleFitter.fit(frames: shot.address, near: LaunchScene.address, searchRadius: 24))
            let observations = try LaunchTracker.observe(frames: shot.flight, reference: shot.address[0], scale: scale,
                                                         exposure: 1.0 / 2000, targetDirection: 1).get()
            XCTAssertTrue(observations.count >= 2)
            let measurement = try LaunchTracker.fit(observations, scale: scale).get()
            XCTAssertEqual(try XCTUnwrap(measurement.ballSpeed.value), speed, accuracy: speed * 0.02)
            XCTAssertEqual(try XCTUnwrap(measurement.launchAngle.value) * 180 / .pi, angle, accuracy: 1.0)
            XCTAssertEqual(measurement.ballSpeed.provenance, .visionDerived)
            XCTAssertEqual(measurement.ballSpeed.unit, "m/s")
            XCTAssertEqual(measurement.launchAngle.unit, "rad")
            XCTAssertTrue(measurement.relativeSpeedUncertainty < 0.05)
        }
    }

    func testLongExposureNoBallAndTooFewPointsAreRefused() throws {
        let shot = LaunchScene.shot(speed: 54, angleDegrees: 16, exposure: 1.0 / 240)
        let scale = try XCTUnwrap(BallScaleFitter.fit(frames: shot.address, near: LaunchScene.address, searchRadius: 24))
        XCTAssertEqual(LaunchTracker.observe(frames: shot.flight, reference: shot.address[0], scale: scale,
                                             exposure: 1.0 / 240, targetDirection: 1).failureValue, .exposureTooLong)
        // Nothing moves: no observation.
        let still = (1...3).map { (Double($0) / 240, shot.address[0]) }
        XCTAssertEqual(LaunchTracker.observe(frames: still, reference: shot.address[0], scale: scale,
                                             exposure: 1.0 / 2000, targetDirection: 1).failureValue, .ballNotFound)
        // Looking the wrong way finds nothing either.
        let fast = LaunchScene.shot(speed: 54, angleDegrees: 16)
        XCTAssertEqual(LaunchTracker.observe(frames: fast.flight, reference: fast.address[0], scale: scale,
                                             exposure: 1.0 / 2000, targetDirection: -1).failureValue, .ballNotFound)
        // Imported video (exposure unknown): a short smear is accepted with the same speed. A 1/240 s smear
        // (≈ 5 diameters) is refused: it is either rejected by shape or too faint to detect at all.
        let unknownShort = try LaunchTracker.observe(frames: fast.flight, reference: fast.address[0], scale: scale,
                                                     exposure: nil, targetDirection: 1).get()
        XCTAssertEqual(try XCTUnwrap(LaunchTracker.fit(unknownShort, scale: scale).get().ballSpeed.value), 54, accuracy: 54 * 0.02)
        let smeared = LaunchTracker.observe(frames: shot.flight, reference: shot.address[0], scale: scale,
                                            exposure: nil, targetDirection: 1).failureValue
        XCTAssertTrue(smeared == .tooBlurred || smeared == .ballNotFound)
        let one = [LaunchObservation(time: 0.01, center: PixelPoint(x: 200, y: 250))]
        XCTAssertEqual(LaunchTracker.fit(one, scale: scale).failureValue, .tooFewObservations)
        // 2 px in 4 ms at this scale is ≈ 1 m/s: implausible for a struck ball.
        let crawl = [LaunchObservation(time: 0, center: PixelPoint(x: 200, y: 250)), LaunchObservation(time: 0.004, center: PixelPoint(x: 202, y: 250))]
        XCTAssertEqual(LaunchTracker.fit(crawl, scale: scale).failureValue, .implausibleSpeed)
    }

    func testCarryIsASimulatedRangeFromCitedSpin() throws {
        let speed = ProvenancedValue(value: 54, unit: "m/s", provenance: .visionDerived, method: LaunchTracker.method)
        let angle = ProvenancedValue(value: 16 * .pi / 180, unit: "rad", provenance: .visionDerived, method: LaunchTracker.method)
        if let range = CarryRangeEstimator.estimate(ballSpeed: speed, launchAngle: angle, club: .iron7) {
            XCTAssertEqual(range.shortest.provenance, .simulated)
            XCTAssertTrue(try XCTUnwrap(range.shortest.value) <= XCTUnwrap(range.longest.value))
            XCTAssertTrue(!range.citations.isEmpty)
        } else {
            XCTAssertNil(ReferenceLaunchData.spinAssumption(club: .iron7))
        }
        // An estimated or user-entered speed never becomes a carry range.
        let guessed = ProvenancedValue(value: 54, unit: "m/s", provenance: .estimated, method: "guess")
        XCTAssertNil(CarryRangeEstimator.estimate(ballSpeed: guessed, launchAngle: angle, club: .iron7))
    }
}

private extension Result {
    var failureValue: Failure? { if case let .failure(error) = self { error } else { nil } }
}
