#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SwingLabCore

/// Synthetic face-on swing with known events. Hands move on C1 cosine segments:
/// still until 1.0 s, top at 1.9 s, lowest hands (impact proxy) at 2.2 s, still from 2.6 s.
private enum SyntheticSwing {
    static let addressEnd = 1.0, top = 1.9, impact = 2.2
    /// Closed-form crossings of the body reference heights used by the detector.
    static let takeaway = 1.0 + 0.9 * acos(0.6) / .pi          // hands reach hip height 0.45
    static let midBackswing = 1.0 + 0.9 * acos(-0.4) / .pi     // lead wrist reaches shoulder 0.70
    static let downswing = 1.9 + 0.3 * acos(0.4) / .pi         // lead wrist falls to shoulder 0.70
    static let followThrough = 2.2 + 0.4 * acos(-0.4) / .pi    // hands reach shoulder 0.70

    private static func ease(_ u: Double) -> Double { (1 - cos(.pi * min(1, max(0, u)))) / 2 }
    static func hands(_ t: Double) -> (x: Double, y: Double) {
        switch t {
        case ..<1.0: (0.50, 0.35)
        case ..<1.9: (0.50 - 0.10 * ease((t - 1.0) / 0.9), 0.35 + 0.5 * ease((t - 1.0) / 0.9))
        case ..<2.2: (0.40 + 0.22 * ease((t - 1.9) / 0.7), 0.85 - 0.5 * ease((t - 1.9) / 0.3))
        case ..<2.6: (0.40 + 0.22 * ease((t - 1.9) / 0.7), 0.35 + 0.5 * ease((t - 2.2) / 0.4))
        default: (0.62, 0.85)
        }
    }

    /// Deterministic noise in ±amplitude; `dropEvery` removes wrists from that frame (a short gap).
    static func frames(rate: Double, noise: Double = 0, dropEvery: Int = 0, handedness: Handedness = .right) -> [PoseFrame] {
        var seed: UInt64 = 0x5EED
        func jitter() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return noise * (Double(seed >> 11) / Double(1 << 53) * 2 - 1)
        }
        let count = Int((3.2 * rate).rounded())
        return (0..<count).map { index in
            let t = Double(index) / rate
            let h = hands(t)
            // Mirror the image for a left-handed golfer; heights are unchanged.
            func joint(_ name: String, _ x: Double, _ y: Double) -> PoseJoint {
                let mirroredName = handedness == .right ? name
                    : name.hasPrefix("left") ? "right" + name.dropFirst(4) : name.hasPrefix("right") ? "left" + name.dropFirst(5) : name
                return PoseJoint(name: mirroredName, x: (handedness == .right ? x : 1 - x) + jitter(), y: y + jitter(), confidence: 0.9)
            }
            var joints = [joint("leftShoulder", 0.55, 0.70), joint("rightShoulder", 0.45, 0.70),
                          joint("leftHip", 0.54, 0.45), joint("rightHip", 0.46, 0.45), joint("nose", 0.5, 0.85)]
            if dropEvery == 0 || index % dropEvery != 0 {
                joints += [joint("leftWrist", h.x + 0.01, h.y), joint("rightWrist", h.x - 0.01, h.y)]
            }
            return PoseFrame(time: t, joints: joints)
        }
    }

    static func detect(rate: Double, noise: Double = 0, dropEvery: Int = 0, handedness: Handedness = .right) -> [SwingPhaseMarker] {
        let raw = frames(rate: rate, noise: noise, dropEvery: dropEvery, handedness: handedness)
        return SwingPhaseDetector.detect(frames: PoseProcessing.process(frames: raw, sampleInterval: 1 / rate), handedness: handedness)
    }
}

final class PhaseDetectionTests: XCTestCase {
    private let rates = [30.0, 60.0, 120.0, 240.0]

    func testZeroPhaseSmoothingPreservesPeakTiming() throws {
        for rate in rates {
            let times = (0..<Int(2 * rate)).map { Double($0) / rate }
            let values = times.map { 0.3 + 0.4 * exp(-pow(($0 - 1.0) / 0.12, 2)) }
            let smoothed = ZeroPhaseSmoother.smooth(times: times, values: values)
            let peak = try XCTUnwrap(smoothed.indices.max { smoothed[$0] < smoothed[$1] })
            XCTAssertLessThan(abs(times[peak] - 1.0), 1 / rate + 1e-9)
            // A causal exponential filter of the Round 1 type lags the same peak by more than a sample.
            var causal = values
            for index in causal.indices.dropFirst() {
                let alpha = 1 - exp(-(times[index] - times[index - 1]) / 0.045)
                causal[index] = causal[index - 1] + alpha * (values[index] - causal[index - 1])
            }
            let lagged = try XCTUnwrap(causal.indices.max { causal[$0] < causal[$1] })
            XCTAssertTrue(times[lagged] - 1.0 > 1 / rate)
        }
    }

    func testDetectorRecoversKnownEventsAcrossFrameRates() throws {
        for rate in rates {
            let interval = 1 / rate
            let markers = SyntheticSwing.detect(rate: rate, dropEvery: 13)
            func time(_ phase: SwingPhaseName) throws -> Double { try XCTUnwrap(markers.first { $0.phase == phase }).time }
            XCTAssertEqual(try time(.top), SyntheticSwing.top, accuracy: 1.5 * interval)
            XCTAssertEqual(try time(.impact), SyntheticSwing.impact, accuracy: 1.5 * interval)
            // Address is the end of a smooth stillness, so a fixed still-speed threshold
            // fires ~20–25 ms after motion onset regardless of frame rate.
            XCTAssertEqual(try time(.address), SyntheticSwing.addressEnd + 0.012, accuracy: max(1.5 * interval, 0.025))
            XCTAssertEqual(try time(.takeaway), SyntheticSwing.takeaway, accuracy: 1.5 * interval)
            XCTAssertEqual(try time(.midBackswing), SyntheticSwing.midBackswing, accuracy: 1.5 * interval)
            XCTAssertEqual(try time(.downswing), SyntheticSwing.downswing, accuracy: 1.5 * interval)
            XCTAssertEqual(try time(.followThrough), SyntheticSwing.followThrough, accuracy: 1.5 * interval)
            XCTAssertTrue(try time(.finish) > SyntheticSwing.followThrough)
            XCTAssertEqual(markers.count, 8)
            XCTAssertTrue(zip(markers, markers.dropFirst()).allSatisfy { $0.time < $1.time })
            XCTAssertTrue(markers.allSatisfy { $0.provenance == .estimated && $0.rule.hasSuffix(".v2") })
            XCTAssertTrue(markers.allSatisfy { ($0.confidence ?? 0) >= SwingPhaseDetector.minimumConfidence })
        }
    }

    func testNoisyLandmarksStayWithinNoiseLimitedTolerance() throws {
        // ±0.003 landmark noise makes the flat side of the top noise-limited (observed up to ≈ 24 ms,
        // always early) at high frame rates, so the tolerance is the larger of 1.5 intervals and 30 ms.
        for rate in rates {
            let markers = SyntheticSwing.detect(rate: rate, noise: 0.003, dropEvery: 17)
            let tolerance = max(1.5 / rate, 0.030)
            XCTAssertEqual(try XCTUnwrap(markers.first { $0.phase == .top }).time, SyntheticSwing.top, accuracy: tolerance)
            XCTAssertEqual(try XCTUnwrap(markers.first { $0.phase == .impact }).time, SyntheticSwing.impact, accuracy: tolerance)
            XCTAssertEqual(try XCTUnwrap(markers.first { $0.phase == .address }).time, SyntheticSwing.addressEnd + 0.012,
                           accuracy: max(1.5 / rate, 0.035))
            XCTAssertTrue(zip(markers, markers.dropFirst()).allSatisfy { $0.time < $1.time })
        }
    }

    func testMixedCoarseAndDensePassRetainsAddressAndFinish() throws {
        for rate in [60.0, 120.0, 240.0] {
            let window = (SyntheticSwing.top - 0.35)...(SyntheticSwing.impact + 0.35)
            let coarse = PoseProcessing.process(frames: SyntheticSwing.frames(rate: 30), sampleInterval: 1.0 / 30)
            let dense = PoseProcessing.process(frames: SyntheticSwing.frames(rate: rate).filter { window.contains($0.time) },
                                               sampleInterval: 1 / rate)
            let frames = (coarse.filter { !window.contains($0.time) } + dense).sorted { $0.time < $1.time }
            let markers = SwingPhaseDetector.detect(frames: frames, handedness: .right)
            XCTAssertEqual(try XCTUnwrap(markers.first { $0.phase == .address }).time, SyntheticSwing.addressEnd,
                           accuracy: 1.5 / 30)
            XCTAssertEqual(try XCTUnwrap(markers.first { $0.phase == .top }).time, SyntheticSwing.top, accuracy: 1.5 / rate)
            XCTAssertEqual(try XCTUnwrap(markers.first { $0.phase == .impact }).time, SyntheticSwing.impact, accuracy: 1.5 / rate)
            XCTAssertTrue(markers.contains { $0.phase == .finish })
            XCTAssertEqual(markers.count, 8)
        }
    }

    func testLongWristGapCannotBecomeAnImpact() {
        let raw = SyntheticSwing.frames(rate: 240).map { frame in
            PoseFrame(time: frame.time, joints: (2.12...2.30).contains(frame.time)
                      ? frame.joints.filter { !$0.name.hasSuffix("Wrist") } : frame.joints)
        }
        let markers = SwingPhaseDetector.detect(frames: PoseProcessing.process(frames: raw, sampleInterval: 1.0 / 240),
                                                handedness: .right)
        XCTAssertTrue(!markers.contains { $0.phase == .impact })
    }

    func testLeftHandedMirrorProducesSameTiming() throws {
        let right = SyntheticSwing.detect(rate: 120)
        let left = SyntheticSwing.detect(rate: 120, handedness: .left)
        XCTAssertEqual(right.map(\.phase), left.map(\.phase))
        for (a, b) in zip(right, left) { XCTAssertEqual(a.time, b.time, accuracy: 1e-9) }
        // Using the wrong lead side compares the trail wrist with the trail shoulder; it must not crash
        // and must still respect chronological order.
        let wrong = SwingPhaseDetector.detect(frames: SyntheticSwing.frames(rate: 120, handedness: .left), handedness: .right)
        XCTAssertTrue(zip(wrong, wrong.dropFirst()).allSatisfy { $0.time < $1.time })
    }

    func testNoSwingOrMissingBodyReturnsNoGuesses() {
        // Standing still with small sway: no top, so nothing is inferred.
        let still = (0..<240).map { index -> PoseFrame in
            let t = Double(index) / 60, sway = 0.01 * sin(t * 3)
            return PoseFrame(time: t, joints: [
                .init(name: "leftShoulder", x: 0.55, y: 0.70, confidence: 0.9), .init(name: "rightShoulder", x: 0.45, y: 0.70, confidence: 0.9),
                .init(name: "leftHip", x: 0.54, y: 0.45, confidence: 0.9), .init(name: "rightHip", x: 0.46, y: 0.45, confidence: 0.9),
                .init(name: "leftWrist", x: 0.51 + sway, y: 0.35 + sway, confidence: 0.9),
                .init(name: "rightWrist", x: 0.49 + sway, y: 0.35, confidence: 0.9)])
        }
        XCTAssertTrue(SwingPhaseDetector.detect(frames: still, handedness: .right).isEmpty)
        // Without hips and shoulders there is no body scale, so no phase is estimated.
        let handsOnly = SyntheticSwing.frames(rate: 60).map { frame in
            PoseFrame(time: frame.time, joints: frame.joints.filter { $0.name.hasSuffix("Wrist") })
        }
        XCTAssertTrue(SwingPhaseDetector.detect(frames: handsOnly, handedness: .right).isEmpty)
        XCTAssertTrue(SwingPhaseDetector.detect(frames: [], handedness: .right).isEmpty)
        // A clip that ends during the downswing has a top but no impact.
        let truncated = SyntheticSwing.frames(rate: 60).filter { $0.time < 2.1 }
        let markers = SwingPhaseDetector.detect(frames: PoseProcessing.process(frames: truncated, sampleInterval: 1.0 / 60), handedness: .right)
        XCTAssertTrue(markers.contains { $0.phase == .top })
        XCTAssertTrue(!markers.contains { $0.phase == .impact || $0.phase == .followThrough || $0.phase == .finish })
    }

    func testMergeKeepsUserMarkersAndDropsConflictingEstimates() {
        let estimated = SyntheticSwing.detect(rate: 60)
        let manual = [SwingPhaseMarker(phase: .top, time: 1.70, provenance: .userEntered),
                      SwingPhaseMarker(phase: .impact, time: 2.05, provenance: .userEntered),
                      SwingPhaseMarker(phase: .finish, time: 3.0, provenance: .estimated)]
        let merged = SwingPhaseDetector.merge(estimated: estimated, existing: manual)
        XCTAssertEqual(merged.first { $0.phase == .top }?.time, 1.70)
        XCTAssertEqual(merged.first { $0.phase == .top }?.provenance, .userEntered)
        XCTAssertEqual(merged.first { $0.phase == .impact }?.time, 2.05)
        // Mid-backswing (≈1.57 s) fits before the manual top; the estimated downswing (≈2.01 s) still fits
        // between the manual top and impact, but the old estimated finish is replaced by the new estimate.
        XCTAssertTrue(merged.contains { $0.phase == .midBackswing && $0.provenance == .estimated })
        XCTAssertEqual(merged.first { $0.phase == .finish }?.time, estimated.first { $0.phase == .finish }?.time)
        // An estimate outside the user's chronology is dropped instead of moving the user's marker.
        let late = [SwingPhaseMarker(phase: .downswing, time: 2.5, provenance: .estimated)]
        XCTAssertTrue(!SwingPhaseDetector.merge(estimated: late, existing: manual).contains { $0.phase == .downswing })
        XCTAssertTrue(zip(merged, merged.dropFirst()).allSatisfy { $0.time < $1.time })
    }
}
