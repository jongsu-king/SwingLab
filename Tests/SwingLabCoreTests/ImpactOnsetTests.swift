#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SwingLabCore

/// 48 kHz signals on the video timeline from 1.0 s to 2.6 s. Background: white noise plus a loud
/// 100 Hz hum that the high-pass must reject. Clicks are 5 kHz bursts decaying with τ = 2 ms.
private enum SyntheticAudio {
    static let rate = 48_000.0, start = 1.0, window = 1.9...2.5, poseImpact = 2.2

    static func signal(clicks: [(time: Double, amplitude: Double)], noise: Double = 0.01, clip: Float? = nil) -> [Float] {
        var seed: UInt64 = 0xA0D10
        return (0..<Int(1.6 * rate)).map { index in
            let t = start + Double(index) / rate
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            var value = noise * (Double(seed >> 11) / Double(1 << 53) * 2 - 1) + 0.2 * sin(2 * .pi * 100 * t)
            for click in clicks where t >= click.time {
                value += click.amplitude * exp(-(t - click.time) / 0.002) * sin(2 * .pi * 5_000 * (t - click.time))
            }
            let sample = Float(value)
            return clip.map { max(-$0, min($0, sample)) } ?? sample
        }
    }

    static func detect(_ samples: [Float], poseImpact: Double? = poseImpact) -> Result<AudioImpactEstimate, AudioImpactRejection> {
        ImpactOnsetDetector.detect(samples: samples, sampleRate: rate, startTime: start, window: window, poseImpact: poseImpact)
    }
}

final class ImpactOnsetTests: XCTestCase {
    func testClickInNoiseIsTimedWithinOneMillisecond() throws {
        let estimate = try SyntheticAudio.detect(SyntheticAudio.signal(clicks: [(2.21, 0.8)])).get()
        XCTAssertEqual(estimate.time, 2.21, accuracy: 0.001)
        XCTAssertEqual(estimate.provenance, .audioDerived)
        XCTAssertTrue(estimate.peakToNoiseDB > 30)
        XCTAssertEqual(estimate.rule, ImpactOnsetDetector.rule)
    }

    func testClippedClickIsStillTimed() throws {
        let estimate = try SyntheticAudio.detect(SyntheticAudio.signal(clicks: [(2.21, 3.0)], clip: 0.5)).get()
        XCTAssertEqual(estimate.time, 2.21, accuracy: 0.001)
    }

    func testTwoComparableClicksAreAmbiguous() {
        let result = SyntheticAudio.detect(SyntheticAudio.signal(clicks: [(2.15, 0.8), (2.30, 0.6)]))
        XCTAssertEqual(result.failure, .ambiguous)
    }

    func testWeakSecondaryTransientDoesNotBlockTheImpact() throws {
        // A rattle 14 dB below the impact is not comparable, so the impact is still accepted.
        let estimate = try SyntheticAudio.detect(SyntheticAudio.signal(clicks: [(2.21, 0.8), (2.36, 0.16)])).get()
        XCTAssertEqual(estimate.time, 2.21, accuracy: 0.001)
    }

    func testNoClickOrClickOutsideWindowFindsNothing() {
        XCTAssertEqual(SyntheticAudio.detect(SyntheticAudio.signal(clicks: [])).failure, .noTransient)
        XCTAssertEqual(SyntheticAudio.detect(SyntheticAudio.signal(clicks: [(2.55, 0.8)])).failure, .noTransient)
        XCTAssertEqual(SyntheticAudio.detect(SyntheticAudio.signal(clicks: [(1.5, 0.8)])).failure, .noTransient)
    }

    func testTransientFarFromPoseImpactIsRejected() throws {
        let samples = SyntheticAudio.signal(clicks: [(2.45, 0.8)])
        XCTAssertEqual(SyntheticAudio.detect(samples).failure, .inconsistentWithPose)
        // Without a pose impact there is nothing to disagree with.
        XCTAssertEqual(try SyntheticAudio.detect(samples, poseImpact: nil).get().time, 2.45, accuracy: 0.001)
    }

    func testFaintClickStaysEstimatedAndInvalidInputIsRejected() throws {
        // ≈ 18–22 dB above the high-passed floor: found, but below the audio-derived threshold.
        let faint = try SyntheticAudio.detect(SyntheticAudio.signal(clicks: [(2.21, 0.06)])).get()
        XCTAssertLessThan(faint.confidence, ImpactOnsetDetector.audioDerivedThreshold)
        XCTAssertEqual(faint.provenance, .estimated)
        XCTAssertEqual(SyntheticAudio.detect([]).failure, .noAudio)
        XCTAssertEqual(ImpactOnsetDetector.detect(samples: [0, .nan, 0], sampleRate: 48_000, startTime: 0,
                                                  window: 0...1, poseImpact: nil).failure, .invalidSignal)
        XCTAssertEqual(ImpactOnsetDetector.detect(samples: [Float](repeating: 0, count: 4_800), sampleRate: 4_000, startTime: 0,
                                                  window: 0...1, poseImpact: nil).failure, .invalidSignal)
    }
}

extension ImpactOnsetTests {
    func testAudioImpactReplacesPoseProxyOnlyWhenClearAndOrdered() throws {
        let pose = [SwingPhaseMarker(phase: .top, time: 1.9, provenance: .estimated),
                    SwingPhaseMarker(phase: .downswing, time: 2.01, provenance: .estimated),
                    SwingPhaseMarker(phase: .impact, time: 2.2, provenance: .estimated),
                    SwingPhaseMarker(phase: .followThrough, time: 2.45, provenance: .estimated)]
        func outcome(_ time: Double, _ confidence: Double) -> AudioImpactOutcome {
            .init(estimate: .init(time: time, confidence: confidence, peakToNoiseDB: 12 + 24 * confidence, rule: ImpactOnsetDetector.rule),
                  rejection: nil, poseImpactTime: 2.2)
        }
        let replaced = ImpactOnsetDetector.apply(outcome(2.21, 0.9), to: pose)
        let impact = try XCTUnwrap(replaced.first { $0.phase == .impact })
        XCTAssertEqual(impact.time, 2.21)
        XCTAssertEqual(impact.provenance, .audioDerived)
        XCTAssertEqual(impact.rule, ImpactOnsetDetector.rule)
        XCTAssertEqual(replaced.count, pose.count)
        // Faint, out-of-order, rejected, or user-entered: the existing impact stays.
        XCTAssertEqual(ImpactOnsetDetector.apply(outcome(2.21, 0.3), to: pose).first { $0.phase == .impact }?.provenance, .estimated)
        XCTAssertEqual(ImpactOnsetDetector.apply(outcome(2.0, 0.9), to: pose).first { $0.phase == .impact }?.time, 2.2)
        let rejected = AudioImpactOutcome(estimate: nil, rejection: .ambiguous, poseImpactTime: 2.2)
        XCTAssertEqual(ImpactOnsetDetector.apply(rejected, to: pose).first { $0.phase == .impact }?.time, 2.2)
        let manual = pose.map { $0.phase == .impact ? SwingPhaseMarker(phase: .impact, time: 2.18, provenance: .userEntered) : $0 }
        XCTAssertEqual(ImpactOnsetDetector.apply(outcome(2.21, 0.9), to: manual).first { $0.phase == .impact }?.time, 2.18)
        // Tempo with an audio impact but an estimated top stays estimated.
        let report = PoseAnalysisReport(frames: [], markers: [SwingPhaseMarker(phase: .address, time: 1.0, provenance: .estimated)] + replaced,
                                        analyzedAt: .now, sampledFrameCount: 0, poseFrameCount: 0, sampleRateLimit: 240, notes: [],
                                        analysisVersion: 2, audioImpact: outcome(2.21, 0.9))
        XCTAssertEqual(report.tempoMetric.provenance, .estimated)
        let decoded = try JSONDecoder().decode(PoseAnalysisReport.self, from: JSONEncoder().encode(report))
        XCTAssertEqual(decoded.audioImpact, report.audioImpact)
    }
}

private extension Result {
    var failure: Failure? { if case let .failure(error) = self { error } else { nil } }
}
