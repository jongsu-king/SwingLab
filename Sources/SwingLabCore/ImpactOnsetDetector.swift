import Foundation

/// A transient in the impact sound, on the video timeline. The time is the attack onset of the
/// high-passed envelope as heard at the microphone; sound travel (≈ 2.9 ms per metre between
/// golfer and iPhone) is not removed because the distance is unknown.
public struct AudioImpactEstimate: Codable, Sendable, Equatable {
    public let time: Double
    /// Ordinal confidence from the peak-to-noise ratio: 12 dB → 0, 36 dB → 1 (capped at 0.95).
    public let confidence: Double
    public let peakToNoiseDB: Double
    public let rule: String
    /// Only a clear, unique transient becomes an audio-derived measurement.
    public var provenance: Provenance { confidence >= ImpactOnsetDetector.audioDerivedThreshold ? .audioDerived : .estimated }
}

public enum AudioImpactRejection: String, Codable, Sendable, Error {
    case noAudio, invalidSignal, noTransient, ambiguous, inconsistentWithPose
}

/// What the analysis found, kept beside the markers so the pose and audio estimates stay comparable.
public struct AudioImpactOutcome: Codable, Sendable, Equatable {
    public let estimate: AudioImpactEstimate?
    public let rejection: AudioImpactRejection?
    public let poseImpactTime: Double?
    public init(estimate: AudioImpactEstimate?, rejection: AudioImpactRejection?, poseImpactTime: Double?) {
        self.estimate = estimate; self.rejection = rejection; self.poseImpactTime = poseImpactTime
    }
}

public enum ImpactOnsetDetector {
    public static let audioDerivedThreshold = 0.5
    public static let rule = "audio.highPassEnvelopeOnset.v1"
    static let cutoffHz = 2_000.0
    static let candidateThresholdDB = 12.0
    static let comparableWithinDB = 6.0
    static let minimumSeparation = 0.03
    static let maximumPoseDisagreement = 0.12

    /// - Parameters:
    ///   - samples: mono PCM; `startTime` is the video-timeline time of `samples[0]`.
    ///   - window: kinematic search window (top → top + 0.6 s).
    ///   - poseImpact: the pose impact proxy; a transient further than 0.12 s from it is rejected.
    public static func detect(samples: [Float], sampleRate: Double, startTime: Double,
                              window: ClosedRange<Double>, poseImpact: Double?) -> Result<AudioImpactEstimate, AudioImpactRejection> {
        guard !samples.isEmpty else { return .failure(.noAudio) }
        guard sampleRate.isFinite, sampleRate >= 8_000, startTime.isFinite, window.lowerBound.isFinite,
              window.upperBound.isFinite, samples.allSatisfy(\.isFinite), samples.count >= Int(0.05 * sampleRate) else {
            return .failure(.invalidSignal)
        }
        let envelope = rmsEnvelope(highPass(samples.map(Double.init), sampleRate: sampleRate), radius: max(1, Int(0.0005 * sampleRate)))
        let noise = max(1e-9, median(envelope))
        let first = max(0, Int(((window.lowerBound - startTime) * sampleRate).rounded(.up)))
        let last = min(envelope.count - 1, Int(((window.upperBound - startTime) * sampleRate).rounded(.down)))
        guard first < last else { return .failure(.noTransient) }

        // Peaks of contiguous above-threshold runs, merged when closer than 30 ms.
        let threshold = noise * pow(10, candidateThresholdDB / 20)
        let separation = Int(minimumSeparation * sampleRate)
        var peaks: [Int] = []
        var index = first
        while index <= last {
            guard envelope[index] > threshold else { index += 1; continue }
            var peak = index
            while index <= last, envelope[index] > threshold || index - peak < separation {
                if envelope[index] > envelope[peak] { peak = index }
                index += 1
            }
            peaks.append(peak)
        }
        guard let strongest = peaks.max(by: { envelope[$0] < envelope[$1] }) else { return .failure(.noTransient) }
        let strongestDB = 20 * log10(envelope[strongest] / noise)
        let comparable = peaks.filter { 20 * log10(envelope[$0] / noise) >= strongestDB - comparableWithinDB }
        guard comparable.count == 1 else { return .failure(.ambiguous) }

        // Pose proximity chooses among non-comparable transients. Loudness alone must not
        // promote a louder neighboring golfer's impact over the candidate nearest our swing.
        let selected: Int
        if let poseImpact, poseImpact.isFinite {
            selected = peaks.min { abs(startTime + Double($0) / sampleRate - poseImpact)
                < abs(startTime + Double($1) / sampleRate - poseImpact) } ?? strongest
        } else { selected = strongest }
        let selectedDB = 20 * log10(envelope[selected] / noise)
        // Reject peers comparable with the chosen candidate too, even if a third peak is louder.
        guard peaks.filter({ abs(20 * log10(envelope[$0] / noise) - selectedDB) <= comparableWithinDB }).count == 1
        else { return .failure(.ambiguous) }

        // Attack onset: last crossing of 25 % of the rise before the peak, linearly interpolated.
        let level = noise + 0.25 * (envelope[selected] - noise)
        var onset = selected
        while onset > 0, envelope[onset - 1] >= level { onset -= 1 }
        var position = Double(onset)
        if onset > 0 {
            let below = envelope[onset - 1], above = envelope[onset]
            position = Double(onset - 1) + (level - below) / max(above - below, 1e-12)
        }
        let time = startTime + position / sampleRate
        if let poseImpact, poseImpact.isFinite, abs(time - poseImpact) > maximumPoseDisagreement {
            return .failure(.inconsistentWithPose)
        }
        let confidence = min(0.95, max(0, (selectedDB - candidateThresholdDB) / 24))
        return .success(.init(time: time, confidence: confidence, peakToNoiseDB: selectedDB, rule: rule))
    }

    /// Replaces the pose impact with an audio-derived marker only when the estimate clears the
    /// audio-derived threshold and still falls strictly between the neighbouring phases. A faint
    /// or out-of-order transient leaves the pose proxy in place; the outcome is kept either way.
    public static func apply(_ outcome: AudioImpactOutcome, to markers: [SwingPhaseMarker]) -> [SwingPhaseMarker] {
        guard let estimate = outcome.estimate, estimate.provenance == .audioDerived,
              !markers.contains(where: { $0.phase == .impact && $0.provenance == .userEntered }) else { return markers }
        let order = SwingPhaseName.allCases
        let impactRank = order.firstIndex(of: .impact)!
        let others = markers.filter { $0.phase != .impact }
        let before = others.filter { order.firstIndex(of: $0.phase)! < impactRank }.map(\.time).max()
        let after = others.filter { order.firstIndex(of: $0.phase)! > impactRank }.map(\.time).min()
        guard before.map({ estimate.time > $0 }) ?? true, after.map({ estimate.time < $0 }) ?? true else { return markers }
        let marker = SwingPhaseMarker(phase: .impact, time: estimate.time, provenance: .audioDerived,
                                      confidence: estimate.confidence, rule: estimate.rule)
        return (others + [marker]).sorted { order.firstIndex(of: $0.phase)! < order.firstIndex(of: $1.phase)! }
    }

    /// Second-order Butterworth high-pass (RBJ biquad) run forward and backward: zero phase,
    /// so the filter does not delay the onset.
    static func highPass(_ input: [Double], sampleRate: Double) -> [Double] {
        let omega = 2 * Double.pi * min(cutoffHz, 0.45 * sampleRate) / sampleRate
        let q = 1 / 2.0.squareRoot()
        let alpha = sin(omega) / (2 * q)
        let cosine = cos(omega), a0 = 1 + alpha
        let b0 = (1 + cosine) / 2 / a0, b1 = -(1 + cosine) / a0, b2 = b0
        let a1 = -2 * cosine / a0, a2 = (1 - alpha) / a0
        func pass(_ x: [Double]) -> [Double] {
            var y = [Double](repeating: 0, count: x.count)
            var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
            for n in x.indices {
                y[n] = b0 * x[n] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
                x2 = x1; x1 = x[n]; y2 = y1; y1 = y[n]
            }
            return y
        }
        return Array(pass(Array(pass(input).reversed())).reversed())
    }

    /// Centred moving RMS from a running sum of squares.
    static func rmsEnvelope(_ x: [Double], radius: Int) -> [Double] {
        var sums = [Double](repeating: 0, count: x.count + 1)
        for n in x.indices { sums[n + 1] = sums[n] + x[n] * x[n] }
        return x.indices.map { n in
            let lower = max(0, n - radius), upper = min(x.count, n + radius + 1)
            return ((sums[upper] - sums[lower]) / Double(upper - lower)).squareRoot()
        }
    }

    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
