import Foundation

/// The nine-window shot shapes, with the mild curves named separately: where the ball starts
/// (left, on line, right) and how it curves (none, mild, strong, left or right). Names follow the
/// right-handed convention; a left-hander's values are mirrored before classification so the
/// same names apply.
public enum ShotShape: String, CaseIterable, Codable, Sendable, Identifiable {
    case straight, push, pull
    case draw, hook, fade, slice
    case pushDraw, pushHook, pushSlice
    case pullFade, pullSlice, pullHook

    public var id: String { rawValue }
    public var localizationKey: LocalizationKey {
        switch self {
        case .straight: "Straight"
        case .push: "Push"
        case .pull: "Pull"
        case .draw: "Draw"
        case .hook: "Hook"
        case .fade: "Fade"
        case .slice: "Slice"
        case .pushDraw: "Push-draw"
        case .pushHook: "Push-hook"
        case .pushSlice: "Push-slice"
        case .pullFade: "Pull-fade"
        case .pullSlice: "Pull-slice"
        case .pullHook: "Pull-hook"
        }
    }

    /// Illustrative launch direction (°, right +) and spin axis (°, right curve +) for a right-hander,
    /// to fill the hypothetical-flight inputs. They are starting points to edit, not typical values
    /// for anyone in particular.
    public var preset: (launchDirection: Double, spinAxis: Double) {
        switch self {
        case .straight: (0, 0)
        case .push: (5, 0)
        case .pull: (-5, 0)
        case .draw: (0, -4)
        case .hook: (0, -24)
        case .fade: (0, 4)
        case .slice: (0, 24)
        case .pushDraw: (4, -4)
        case .pushHook: (4, -24)
        case .pushSlice: (4, 20)
        case .pullFade: (-4, 4)
        case .pullSlice: (-4, 24)
        case .pullHook: (-4, -20)
        }
    }

    /// The preset in the golfer's own frame: a left-hander's draw curves to the right.
    public func preset(for handedness: Handedness) -> (launchDirection: Double, spinAxis: Double) {
        let values = preset
        let mirror: Double = handedness == .left ? -1 : 1
        return (values.launchDirection * mirror, values.spinAxis * mirror)
    }
}

/// Classifies a simulated flight. The start is read from the launch direction, the curve from how
/// far the landing point lies from the straight line through that start, as a share of the carry.
/// Thresholds are conventions, not measurements; both are listed in `Docs/Principles`.
public struct ShotShapeClassification: Sendable, Equatable {
    public let shape: ShotShape
    /// Launch direction as simulated (°, right +).
    public let startDegrees: Double
    /// Lateral distance between the landing point and the straight start line (m, right +).
    public let curveMetres: Double
    public let provenance: Provenance
    public var startMetric: ProvenancedValue {
        ProvenancedValue(value: startDegrees * .pi / 180, unit: "rad", provenance: provenance, method: ShotShapeClassifier.method)
    }
    public var curveMetric: ProvenancedValue {
        ProvenancedValue(value: curveMetres, unit: "m", provenance: provenance, method: ShotShapeClassifier.method)
    }
}

public enum ShotShapeClassifier {
    public static let method = "shotShape.startAndCurve.v1"
    /// Starts within this of the target line count as on line (°).
    public static let startThresholdDegrees = 2.0
    /// Curve as a share of carry: under `mildCurve` is none, under `strongCurve` is mild (draw/fade).
    public static let mildCurve = 0.015, strongCurve = 0.06

    /// `launch` and `result` must belong to the same simulation; the result's provenance is simulated.
    public static func classify(launch: LaunchConditions, result: FlightResult, handedness: Handedness = .right) -> ShotShapeClassification? {
        guard result.carry > 0, launch.launchDirection.isFinite, result.landingPoint.right.isFinite else { return nil }
        let mirror: Double = handedness == .left ? -1 : 1
        let start = launch.launchDirection * mirror
        let straightLineRight = result.landingPoint.forward * tan(launch.launchDirection * .pi / 180)
        let curve = (result.landingPoint.right - straightLineRight) * mirror
        let share = abs(curve) / result.carry
        let startSide: Int = abs(start) < startThresholdDegrees ? 0 : (start > 0 ? 1 : -1)
        let curveSide: Int = share < mildCurve ? 0 : (curve > 0 ? 1 : -1)
        let strong = share >= strongCurve
        let shape: ShotShape
        switch (startSide, curveSide) {
        case (0, 0): shape = .straight
        case (1, 0): shape = .push
        case (-1, 0): shape = .pull
        case (0, -1): shape = strong ? .hook : .draw
        case (0, 1): shape = strong ? .slice : .fade
        case (1, -1): shape = strong ? .pushHook : .pushDraw
        case (1, 1): shape = .pushSlice
        case (-1, 1): shape = strong ? .pullSlice : .pullFade
        default: shape = .pullHook
        }
        return ShotShapeClassification(shape: shape, startDegrees: launch.launchDirection, curveMetres: curve * mirror, provenance: .simulated)
    }
}

/// A flight and its run after landing, sampled by time for an animation. Positions between the
/// simulation's samples are interpolated linearly; the run continues along the landing direction
/// along the ground, slowing to a stop.
public struct FlightPlayback: Sendable, Equatable {
    public struct Position: Sendable, Equatable {
        public let forward: Double
        public let height: Double
        public let right: Double
        public let rolling: Bool
    }

    public let samples: [FlightSample]
    /// Ground distance after landing (m, signed along the landing direction).
    public let run: Double
    public let rollDuration: Double

    public init(samples: [FlightSample], run: Double = 0, rollDuration: Double = 1.5) {
        self.samples = samples.sorted { $0.time < $1.time }
        self.run = run.isFinite ? run : 0
        self.rollDuration = max(0, rollDuration)
    }

    public var flightTime: Double { samples.last?.time ?? 0 }
    public var duration: Double { flightTime + (run == 0 ? 0 : rollDuration) }
    public var landing: FlightSample? { samples.last }

    /// Unit vector of the ground direction the ball lands with; the target line when unknown.
    public var landingDirection: (forward: Double, right: Double) {
        guard samples.count >= 2 else { return (1, 0) }
        let a = samples[samples.count - 2], b = samples[samples.count - 1]
        let dx = b.forward - a.forward, dz = b.right - a.right
        let length = hypot(dx, dz)
        return length > 1e-9 ? (dx / length, dz / length) : (1, 0)
    }

    /// Where the ball comes to rest.
    public var rest: (forward: Double, right: Double) {
        guard let landing else { return (0, 0) }
        let direction = landingDirection
        return (landing.forward + direction.forward * run, landing.right + direction.right * run)
    }

    public func position(at time: Double) -> Position {
        guard let first = samples.first, let last = samples.last else { return Position(forward: 0, height: 0, right: 0, rolling: false) }
        if time <= first.time { return Position(forward: first.forward, height: first.height, right: first.right, rolling: false) }
        if time >= last.time {
            guard run != 0, rollDuration > 0 else { return Position(forward: last.forward, height: 0, right: last.right, rolling: time > last.time) }
            // Ease out: the ball covers the run with a speed that falls linearly to zero.
            let fraction = min(1, (time - last.time) / rollDuration)
            let covered = run * (1 - (1 - fraction) * (1 - fraction))
            let direction = landingDirection
            return Position(forward: last.forward + direction.forward * covered, height: 0, right: last.right + direction.right * covered, rolling: true)
        }
        var low = 0, high = samples.count - 1
        while high - low > 1 {
            let middle = (low + high) / 2
            if samples[middle].time <= time { low = middle } else { high = middle }
        }
        let a = samples[low], b = samples[high]
        let span = b.time - a.time
        let fraction = span > 0 ? (time - a.time) / span : 0
        return Position(forward: a.forward + (b.forward - a.forward) * fraction, height: max(0, a.height + (b.height - a.height) * fraction),
                        right: a.right + (b.right - a.right) * fraction, rolling: false)
    }
}
