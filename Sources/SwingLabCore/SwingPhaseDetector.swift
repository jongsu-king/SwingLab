import Foundation

/// Rule-based, unvalidated phase candidates from 2D hand and body landmarks.
/// Every marker is `.estimated` and carries the rule that produced it plus an
/// ordinal heuristic confidence (not a probability). Rules are documented in
/// `Docs/PhaseDetection.md`. Low-confidence or out-of-order phases return nil.
public enum SwingPhaseDetector {
    /// Phases below this heuristic confidence are omitted rather than guessed.
    public static let minimumConfidence = 0.3

    public static func detect(frames: [PoseFrame], handedness: Handedness) -> [SwingPhaseMarker] {
        guard let track = HandTrack(frames: frames, handedness: handedness), track.count >= 12,
              let topIndex = track.topIndex() else { return [] }
        let top = track.refinedExtremum(at: topIndex, maximum: true)
        var markers: [(SwingPhaseName, Double, Double, String)] = [
            (.top, top, track.confidence(at: top, base: min(0.9, track.descentAfter(topIndex) / (1.6 * track.scale))),
             "pose.handsHighestBeforeLargestDescent.v2")
        ]
        let address = track.addressRun(before: topIndex)
        if let address {
            markers.append((.address, track.times[address.end],
                            track.confidence(at: track.times[address.end], base: min(0.8, 0.45 + address.duration)),
                            "pose.handsStillBeforeBackswing.v2"))
        }
        let impactIndex = track.impactIndex(after: topIndex)
        if let impactIndex {
            let impact = track.refinedExtremum(at: impactIndex, maximum: false)
            markers.append((.impact, impact, track.confidence(at: impact, base: 0.6), "pose.handsLowestAfterTop.v2"))
        }
        let backswingStart = address?.end ?? 0
        if let time = track.crossing(.hip, rising: true, from: backswingStart, to: topIndex) {
            markers.append((.takeaway, time, track.confidence(at: time, base: 0.6), "pose.handsReachHipHeight.v2"))
        }
        if let time = track.crossing(.leadShoulder, rising: true, from: backswingStart, to: topIndex) {
            markers.append((.midBackswing, time, track.confidence(at: time, base: 0.6), "pose.leadWristReachesLeadShoulderHeight.v2"))
        }
        if let impactIndex {
            if let time = track.crossing(.leadShoulder, rising: false, from: topIndex, to: impactIndex) {
                markers.append((.downswing, time, track.confidence(at: time, base: 0.6), "pose.leadWristFallsToLeadShoulderHeight.v2"))
            }
            let followEnd = track.lastIndex(before: track.times[impactIndex] + 1.0)
            if let time = track.crossing(.shoulders, rising: true, from: impactIndex, to: followEnd) {
                markers.append((.followThrough, time, track.confidence(at: time, base: 0.6), "pose.handsReachShoulderHeightAfterImpact.v2"))
                if let finish = track.stillRunStart(after: time, within: 1.5) {
                    markers.append((.finish, track.times[finish], track.confidence(at: track.times[finish], base: 0.6),
                                    "pose.handsStillAfterFollowThrough.v2"))
                }
            }
        }
        let ordered = SwingPhaseName.allCases
        var result: [SwingPhaseMarker] = []
        // Keep only markers that respect the physical phase order; a later rule cannot move an earlier phase.
        for (phase, time, confidence, rule) in markers.sorted(by: { ordered.firstIndex(of: $0.0)! < ordered.firstIndex(of: $1.0)! })
        where confidence >= minimumConfidence && time.isFinite {
            if let previous = result.last, previous.time >= time { continue }
            result.append(.init(phase: phase, time: time, provenance: .estimated, confidence: confidence, rule: rule))
        }
        return result
    }

    /// User-entered markers win per phase. New estimates fill only unset phases and are
    /// dropped when they would violate the chronology the user established.
    public static func merge(estimated: [SwingPhaseMarker], existing: [SwingPhaseMarker]) -> [SwingPhaseMarker] {
        let manual = existing.filter { $0.provenance == .userEntered }
        let order = SwingPhaseName.allCases
        let rank = { (phase: SwingPhaseName) in order.firstIndex(of: phase)! }
        let fills = estimated.filter { candidate in
            guard !manual.contains(where: { $0.phase == candidate.phase }) else { return false }
            let earlier = manual.filter { rank($0.phase) < rank(candidate.phase) }.map(\.time).max()
            let later = manual.filter { rank($0.phase) > rank(candidate.phase) }.map(\.time).min()
            return (earlier.map { candidate.time > $0 } ?? true) && (later.map { candidate.time < $0 } ?? true)
        }
        return (manual + fills).sorted { rank($0.phase) < rank($1.phase) }
    }
}

/// Hands = midpoint of both wrists when both are visible, otherwise the visible wrist.
/// Heights are Vision y (up is positive). Speeds are in body scales per second.
private struct HandTrack {
    enum Level { case hip, shoulders, leadShoulder }

    let times: [Double]
    let y: [Double]
    let x: [Double]
    let interpolated: [Bool]
    let levels: [Level: [Double?]]
    let leadWristY: [Double?]
    let scale: Double
    let interval: Double
    let speed: [Double?]
    var count: Int { times.count }
    var stillSpeed: Double { 0.3 * scale }

    init?(frames: [PoseFrame], handedness: Handedness) {
        var times: [Double] = [], y: [Double] = [], x: [Double] = [], interpolated: [Bool] = []
        var hip: [Double?] = [], shoulders: [Double?] = [], leadShoulder: [Double?] = [], leadWrist: [Double?] = []
        var torsoLengths: [Double] = []
        for frame in frames.sorted(by: { $0.time < $1.time }) where frame.time.isFinite {
            let wrists = [frame.joint(handedness.leadWristName), frame.joint(handedness.trailWristName)].compactMap { $0 }
            let midHip = Self.midpoint(frame.joint("leftHip"), frame.joint("rightHip"))
            let midShoulder = Self.midpoint(frame.joint("leftShoulder"), frame.joint("rightShoulder"))
            if let midHip, let midShoulder { torsoLengths.append(hypot(midShoulder.x - midHip.x, midShoulder.y - midHip.y)) }
            guard !wrists.isEmpty else { continue }
            times.append(frame.time)
            x.append(wrists.map(\.x).reduce(0, +) / Double(wrists.count))
            y.append(wrists.map(\.y).reduce(0, +) / Double(wrists.count))
            interpolated.append(wrists.contains { $0.interpolated })
            hip.append(midHip?.y)
            shoulders.append(midShoulder?.y)
            leadShoulder.append(frame.joint(handedness.leadJointName("Shoulder"))?.y)
            leadWrist.append(frame.joint(handedness.leadWristName)?.y)
        }
        guard torsoLengths.count >= 5, let interval = PoseProcessing.interval(times: times) else { return nil }
        let scale = torsoLengths.sorted()[torsoLengths.count / 2]
        guard scale.isFinite, scale > 0.02 else { return nil }
        self.times = times; self.y = y; self.x = x; self.interpolated = interpolated
        self.levels = [.hip: hip, .shoulders: shoulders, .leadShoulder: leadShoulder]
        self.leadWristY = leadWrist
        self.scale = scale; self.interval = interval
        // A fixed ±20 ms baseline (at least one neighbour each side) keeps landmark jitter from
        // dominating speed at 240 fps, where adjacent samples are only 4 ms apart.
        speed = times.indices.map { index in
            var before = index - 1, after = index + 1
            while before > 0, times[before] > times[index] - 0.02 { before -= 1 }
            while after < times.count - 1, times[after] < times[index] + 0.02 { after += 1 }
            guard before >= 0, after < times.count else { return nil }
            let dt = times[after] - times[before]
            guard dt > 0, dt <= 0.04 + 2.5 * interval else { return nil }
            return hypot(x[after] - x[before], y[after] - y[before]) / dt
        }
    }

    private static func midpoint(_ a: PoseJoint?, _ b: PoseJoint?) -> (x: Double, y: Double)? {
        guard let a, let b else { return nil }
        return ((a.x + b.x) / 2, (a.y + b.y) / 2)
    }

    private func contiguous(_ a: Int, _ b: Int) -> Bool { abs(times[b] - times[a]) <= 2.5 * interval * Double(abs(b - a)) }

    func lastIndex(before time: Double) -> Int { times.lastIndex { $0 <= time } ?? 0 }

    /// Hand drop within 0.6 s after `index`, in normalized image units.
    func descentAfter(_ index: Int) -> Double {
        let window = times.indices.filter { $0 > index && times[$0] - times[index] <= 0.6 }
        return window.map { y[index] - y[$0] }.max() ?? 0
    }

    /// The top precedes the largest rapid hand descent of the clip (top → impact).
    /// A high finish is not followed by such a descent, so it cannot win.
    func topIndex() -> Int? {
        let candidates = times.indices.dropFirst(2).dropLast(2).filter { index in
            (index - 2...index + 2).allSatisfy { y[index] >= y[$0] } && descentAfter(index) >= 0.8 * scale
        }
        return candidates.max { descentAfter($0) < descentAfter($1) }
    }

    /// Lowest hands within 0.6 s after the top. An edge minimum means the clip ended mid-descent.
    func impactIndex(after top: Int) -> Int? {
        let window = times.indices.filter { $0 > top && times[$0] - times[top] <= 0.6 }
        guard let index = window.min(by: { y[$0] < y[$1] }), index != window.last, index + 1 < count else { return nil }
        return index
    }

    /// Three-point parabolic vertex, limited to half a sample so it cannot invent a new extremum.
    func refinedExtremum(at index: Int, maximum: Bool) -> Double {
        guard index > 0, index + 1 < count, contiguous(index - 1, index + 1) else { return times[index] }
        let denominator = y[index - 1] - 2 * y[index] + y[index + 1]
        guard abs(denominator) > 1e-12, (denominator < 0) == maximum else { return times[index] }
        let offset = max(-0.5, min(0.5, 0.5 * (y[index - 1] - y[index + 1]) / denominator))
        let step = offset < 0 ? times[index] - times[index - 1] : times[index + 1] - times[index]
        return times[index] + offset * step
    }

    /// The still run that ends where the backswing starts. Waggles before it are skipped, and a
    /// pause at the top cannot qualify because address hands must sit well below the top.
    func addressRun(before top: Int) -> (end: Int, duration: Double)? {
        var index = top - 1
        while index > 0 {
            guard let value = speed[index], value < stillSpeed else { index -= 1; continue }
            var start = index
            while start > 0, let previous = speed[start - 1], previous < 1.5 * stillSpeed, contiguous(start - 1, start) { start -= 1 }
            let duration = times[index] - times[start]
            if duration >= 0.15, y[index] <= y[top] - 0.8 * scale { return (index, duration) }
            index = start - 1
        }
        return nil
    }

    /// First crossing of a body reference height between two indices, linearly interpolated.
    /// `.leadShoulder` compares the lead wrist, all other levels compare the hands.
    func crossing(_ level: Level, rising: Bool, from start: Int, to end: Int) -> Double? {
        guard start < end, let references = levels[level] else { return nil }
        let signal: [Double?] = times.indices.map { index in
            let hand = level == .leadShoulder ? leadWristY[index] : y[index]
            guard let hand, let reference = references[index] else { return nil }
            return hand - reference
        }
        for index in (start + 1)...min(end, count - 1) {
            guard let previous = signal[index - 1], let current = signal[index], contiguous(index - 1, index) else { continue }
            if rising ? (previous < 0 && current >= 0) : (previous > 0 && current <= 0) {
                let fraction = previous / (previous - current)
                return times[index - 1] + fraction * (times[index] - times[index - 1])
            }
        }
        return nil
    }

    /// Start of the first still run of at least 0.2 s after `time`, within `within` seconds.
    func stillRunStart(after time: Double, within: Double) -> Int? {
        var index = times.firstIndex { $0 > time } ?? count
        while index < count, times[index] - time <= within {
            guard let value = speed[index], value < stillSpeed else { index += 1; continue }
            var end = index
            while end + 1 < count, let next = speed[end + 1], next < 1.5 * stillSpeed, contiguous(end, end + 1) { end += 1 }
            if times[end] - times[index] >= 0.2 { return index }
            index = end + 1
        }
        return nil
    }

    /// Ordinal heuristic confidence: the rule's base weight, reduced for coarse sampling
    /// and for interpolated hand samples within ±0.1 s of the event.
    func confidence(at time: Double, base: Double) -> Double {
        let density = interval <= 1.0 / 59 ? 1.0 : interval <= 1.0 / 29 ? 0.85 : 0.6
        let nearby = times.indices.filter { abs(times[$0] - time) <= 0.1 }
        let observed = nearby.isEmpty ? 0 : Double(nearby.filter { !interpolated[$0] }.count) / Double(nearby.count)
        return max(0, min(1, base * density * (0.5 + 0.5 * observed)))
    }
}
