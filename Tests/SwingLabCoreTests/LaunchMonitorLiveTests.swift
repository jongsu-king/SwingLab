#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SwingLabCore

/// A capture stream on an arbitrary session clock: 240 fps sensor-orientation luma crops and 48 kHz
/// sound in 1,024-sample buffers, with the strike at `impact`. Sound arrives 20 ms after video, as
/// on a device.
private enum LiveStream {
    static let fps = 240.0, rate = 48_000.0, chunk = 1_024
    static let start = 500.0, impact = 500.30, end = 500.60

    static func sound(clicks: [Double], until stop: Double = end) -> [(time: Double, samples: [Float])] {
        var seed: UInt64 = 0x5EED
        var chunks: [(time: Double, samples: [Float])] = []
        var index = 0
        while start + Double(index) / rate < stop {
            let time = start + Double(index) / rate
            let samples = (0..<chunk).map { offset -> Float in
                let t = start + Double(index + offset) / rate
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                var value = 0.004 * (Double(seed >> 11) / Double(1 << 53) * 2 - 1) + 0.05 * sin(2 * .pi * 120 * t)
                for click in clicks where t >= click {
                    value += 0.6 * exp(-(t - click) / 0.002) * sin(2 * .pi * 5_000 * (t - click))
                }
                return Float(value)
            }
            chunks.append((time, samples))
            index += chunk
        }
        return chunks
    }

    /// Inverse of the clockwise turn: what the sensor delivers for an upright image.
    static func sensorBytes(_ upright: GrayImage) -> (width: Int, height: Int, bytes: [UInt8]) {
        let width = upright.height, height = upright.width
        var bytes = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height { for x in 0..<width {
            bytes[y * width + x] = UInt8(max(0, min(255, (upright[height - 1 - y, x] * 255).rounded())))
        } }
        return (width, height, bytes)
    }

    static func crop(_ bytes: [UInt8], width: Int, rect: PixelRect) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(rect.width * rect.height)
        for y in rect.y..<(rect.y + rect.height) { out += bytes[(y * width + rect.x)..<(y * width + rect.x + rect.width)] }
        return out
    }
}

final class LaunchMonitorLiveTests: XCTestCase {
    func testClockwiseCropMatchesCropOfRotatedFrame() throws {
        let width = 9, height = 6
        let source = LumaFrame(time: 0, width: width, height: height, bytes: (0..<(width * height)).map { UInt8($0) })
        let upright = source.rotated(.clockwise)
        XCTAssertEqual(upright.width, height)
        XCTAssertEqual(upright.height, width)
        // The top-left upright pixel is the sensor's bottom-left pixel.
        XCTAssertEqual(upright.bytes[0], source.bytes[(height - 1) * width])
        let rect = PixelRect(x: 1, y: 2, width: 4, height: 5)
        let sourceRect = LumaRotation.clockwise.sourceRect(for: rect, sourceWidth: width, sourceHeight: height)
        let cropped = LumaFrame(time: 0, width: sourceRect.width, height: sourceRect.height,
                                bytes: LiveStream.crop(source.bytes, width: width, rect: sourceRect)).rotated(.clockwise)
        XCTAssertEqual(cropped.width, rect.width)
        XCTAssertEqual(cropped.height, rect.height)
        XCTAssertEqual(cropped.bytes, LiveStream.crop(upright.bytes, width: upright.width, rect: rect))
    }

    func testFrameRingKeepsNewestFramesInOrder() {
        var ring = FrameRing(capacity: 4)
        for index in 0..<7 { ring.append(LumaFrame(time: Double(index), width: 1, height: 1, bytes: [UInt8(index)])) }
        ring.append(LumaFrame(time: 5.5, width: 1, height: 1, bytes: [0]))  // out of order: dropped
        XCTAssertEqual(ring.ordered.map(\.time), [3, 4, 5, 6])
        XCTAssertEqual(ring.latestTime, 6)
    }

    func testStreamingTriggerTimesStrikesAndIgnoresEchoes() throws {
        var trigger = StreamingImpactTrigger(sampleRate: LiveStream.rate)
        var found: [Double] = []
        // Strike, an echo 0.4 s later (inside the refractory period), then a second strike.
        for chunk in LiveStream.sound(clicks: [500.4123, 500.8123, 502.2], until: 502.6) {
            if let estimate = trigger.append(chunk.samples, startTime: chunk.time) { found.append(estimate.time) }
        }
        XCTAssertEqual(found.count, 2)
        XCTAssertEqual(try XCTUnwrap(found.first), 500.4123, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(found.last), 502.2, accuracy: 0.001)

        var quiet = StreamingImpactTrigger(sampleRate: LiveStream.rate)
        for chunk in LiveStream.sound(clicks: [], until: 502) { XCTAssertNil(quiet.append(chunk.samples, startTime: chunk.time)) }
    }

    func testLiveSessionMeasuresAStreamedShotWithinTheLatencyBudget() throws {
        let speed = 54.0, angle = 16.0
        let shot = LaunchScene.shot(speed: speed, angleDegrees: angle, launchTime: 0)
        let uprightWidth = LaunchScene.width, uprightHeight = LaunchScene.height
        let region = try XCTUnwrap(LaunchRegion.around(ball: LaunchScene.address, frameWidth: uprightWidth,
                                                       frameHeight: uprightHeight, targetDirection: 1))
        let still = LiveStream.sensorBytes(shot.address[0])
        let sourceRect = LumaRotation.clockwise.sourceRect(for: region, sourceWidth: still.width, sourceHeight: still.height)
        // Flight frames k = 1...4 of the scene follow the strike by k / 240 s; later frames are empty turf.
        let flight = shot.flight.map { LiveStream.sensorBytes($0.image) }
        let turf = LiveStream.sensorBytes(LaunchScene.background())
        func frame(at index: Int) -> LumaFrame {
            let time = LiveStream.start + Double(index) / LiveStream.fps
            let k = Int(((time - LiveStream.impact) * LiveStream.fps).rounded())
            let source = time <= LiveStream.impact ? still : (k <= flight.count ? flight[k - 1] : turf)
            return LumaFrame(time: time, width: sourceRect.width, height: sourceRect.height,
                             bytes: LiveStream.crop(source.bytes, width: source.width, rect: sourceRect))
        }
        // The impact lands exactly on a frame boundary so the scene's frame k is k / 240 s after it.
        XCTAssertEqual(((LiveStream.impact - LiveStream.start) * LiveStream.fps).rounded(), 72)

        var session = LiveLaunchSession(frameRate: LiveStream.fps, sampleRate: LiveStream.rate)
        var sound = LiveStream.sound(clicks: [LiveStream.impact])[...]
        var heard: AudioImpactEstimate?, capture: LiveLaunchSession.Capture?, videoClockAtCapture: Double?
        var index = 0
        while capture == nil, LiveStream.start + Double(index) / LiveStream.fps < LiveStream.end {
            let video = frame(at: index)
            var events = session.appendVideo(video)
            while let next = sound.first, next.time + Double(LiveStream.chunk) / LiveStream.rate + 0.02 <= video.time {
                events += session.appendAudio(next.samples, startTime: next.time)
                sound = sound.dropFirst()
            }
            for event in events {
                switch event {
                case let .impact(estimate): heard = estimate
                case let .capture(found): capture = found; videoClockAtCapture = video.time
                case .missedWindow: XCTFail("window missed")
                }
            }
            index += 1
        }
        XCTAssertEqual(try XCTUnwrap(heard).time, LiveStream.impact, accuracy: 0.001)
        let window = try XCTUnwrap(capture)
        // Ready about 0.1 s after the strike: one sound buffer, 60 ms of settling, and 20 ms delivery.
        XCTAssertLessThan(try XCTUnwrap(videoClockAtCapture) - LiveStream.impact, 0.15)
        XCTAssertEqual(window.address.count, 4)
        XCTAssertEqual(window.flight.count, LiveLaunchSession.flightFrameCount)
        XCTAssertTrue(window.flight.allSatisfy { $0.time > window.impactTime })

        let ball = PixelPoint(x: LaunchScene.address.x - Double(region.x), y: LaunchScene.address.y - Double(region.y))
        let outcome = try LaunchPipeline.measure(address: window.address.map { $0.gray(.clockwise) },
                                                 flight: window.flight.map { (time: $0.time, image: $0.gray(.clockwise)) },
                                                 ball: ball, searchRadius: LaunchRegion.searchRadius(frameWidth: uprightWidth),
                                                 targetDirection: 1).get()
        XCTAssertEqual(try XCTUnwrap(outcome.measurement.ballSpeed.value), speed, accuracy: speed * 0.02)
        XCTAssertEqual(try XCTUnwrap(outcome.measurement.launchAngle.value) * 180 / .pi, angle, accuracy: 1.0)
        XCTAssertEqual(outcome.measurement.ballSpeed.provenance, .visionDerived)
    }

    func testStrikeHeardBeforeEnoughHistoryIsReportedAsMissed() {
        var session = LiveLaunchSession(frameRate: LiveStream.fps, sampleRate: LiveStream.rate)
        // Video starts only 50 ms before the strike: the 0.25 s address frame cannot exist.
        let firstFrame = LiveStream.impact - 0.05
        var missed = false
        var frameIndex = 0
        for chunk in LiveStream.sound(clicks: [LiveStream.impact]) {
            while firstFrame + Double(frameIndex) / LiveStream.fps <= chunk.time {
                let time = firstFrame + Double(frameIndex) / LiveStream.fps
                for event in session.appendVideo(LumaFrame(time: time, width: 2, height: 2, bytes: [0, 0, 0, 0])) {
                    if case .missedWindow = event { missed = true }
                }
                frameIndex += 1
            }
            for event in session.appendAudio(chunk.samples, startTime: chunk.time) {
                if case .missedWindow = event { missed = true }
                if case .capture = event { XCTFail("no capture without history") }
            }
        }
        XCTAssertTrue(missed)
    }
}
