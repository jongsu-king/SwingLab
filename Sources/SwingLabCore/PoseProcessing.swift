import Foundation

/// Small polynomial least-squares solver shared by offline smoothing and phase
/// refinement. Coordinates are centred/scaled by callers to avoid ill-conditioning.
enum PosePolynomial {
    static func fit(x: [Double], y: [Double], degree: Int) -> [Double]? {
        guard x.count == y.count, x.count > degree, degree >= 0, degree <= 3,
              x.allSatisfy(\.isFinite), y.allSatisfy(\.isFinite) else { return nil }
        let size = degree + 1
        var matrix = Array(repeating: Array(repeating: 0.0, count: size + 1), count: size)
        for index in x.indices {
            var powers = [1.0]
            for _ in 0..<(degree * 2) { powers.append(powers.last! * x[index]) }
            for row in 0..<size {
                for column in 0..<size { matrix[row][column] += powers[row + column] }
                matrix[row][size] += powers[row] * y[index]
            }
        }
        for column in 0..<size {
            guard let pivot = (column..<size).max(by: { abs(matrix[$0][column]) < abs(matrix[$1][column]) }),
                  abs(matrix[pivot][column]) > 1e-10 else { return nil }
            if pivot != column { matrix.swapAt(pivot, column) }
            let scale = matrix[column][column]
            for index in column...size { matrix[column][index] /= scale }
            for row in 0..<size where row != column {
                let multiple = matrix[row][column]
                for index in column...size { matrix[row][index] -= multiple * matrix[column][index] }
            }
        }
        let result = matrix.map { $0[size] }
        return result.allSatisfy(\.isFinite) ? result : nil
    }
    static func value(_ coefficients: [Double], at x: Double) -> Double {
        coefficients.reversed().reduce(0) { $0 * x + $1 }
    }
}

public enum ZeroPhaseSmoother {
    /// Centred local quadratic Savitzky–Golay fit. Actual PTS are used in the
    /// polynomial; the odd window is selected from the measured sample interval.
    /// At boundaries it fits the available neighbours without a causal recursion.
    public static func smooth(times: [Double], values: [Double], windowDuration: Double = 0.05) -> [Double] {
        guard times.count == values.count, let interval = PoseProcessing.interval(times: times),
              values.allSatisfy(\.isFinite), windowDuration.isFinite, windowDuration > 0 else { return [] }
        guard values.count >= 3 else { return values }
        let halfWindow = max(1, min(120, Int((windowDuration / (2 * interval)).rounded())))
        return values.indices.map { index in
            let range = max(0, index - halfWindow)...min(values.count - 1, index + halfWindow)
            guard range.count >= 3 else { return values[index] }
            let x = range.map { (times[$0] - times[index]) / interval }
            return PosePolynomial.fit(x: x, y: range.map { values[$0] }, degree: 2)?.first ?? values[index]
        }
    }
}

public struct PoseTrajectoryPoint: Sendable {
    public let time: Double
    public let joint: PoseJoint
    public var interpolated: Bool { joint.interpolated }
}

public enum PoseProcessing {
    public static func sampleInterval(frames: [PoseFrame]) -> Double? { interval(times: frames.map(\.time)) }

    /// A local interval is essential when coarse and dense passes share one report.
    public static func localSampleInterval(frames: [PoseFrame], time: Double) -> Double? {
        guard time.isFinite, let nearest = frames.indices.min(by: {
            abs(frames[$0].time - time) < abs(frames[$1].time - time)
        }) else { return nil }
        return sampleInterval(frames: Array(frames[max(0, nearest - 3)...min(frames.count - 1, nearest + 3)]))
    }
    static func interval(times: [Double]) -> Double? {
        guard times.count >= 2, times.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
        let deltas = zip(times.dropFirst(), times).map(-)
        guard deltas.allSatisfy({ $0 > 0 }) else { return nil }
        let sorted = deltas.sorted(), middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    /// Run separately for coarse/dense regions. Keeps only timestamps and joints.
    /// Missing-frame timestamps are materialized only for one/two sample gaps;
    /// missing joints are then interpolated under the same duration/count limit.
    public static func process(frames: [PoseFrame], sampleInterval: Double) -> [PoseFrame] {
        guard sampleInterval.isFinite, sampleInterval > 0, interval(times: frames.map(\.time)) != nil else { return [] }
        var result: [PoseFrame] = []
        for frame in frames {
            if let previous = result.last {
                let steps = (frame.time - previous.time) / sampleInterval
                if steps > 1.5, steps <= 3.25 {
                    let missing = min(2, max(1, Int(steps.rounded()) - 1))
                    for offset in 1...missing {
                        result.append(.init(time: previous.time + (frame.time - previous.time) * Double(offset) / Double(missing + 1), joints: []))
                    }
                }
            }
            var seen = Set<String>()
            let valid = frame.joints.filter {
                $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) &&
                $0.confidence.isFinite && (0.35...1).contains($0.confidence) && seen.insert($0.name).inserted
            }
            result.append(.init(time: frame.time, joints: valid))
        }
        let names = Set(result.flatMap { $0.joints.map(\.name) }).sorted()
        for name in names {
            var previousIndex: Int?
            for index in result.indices {
                guard let current = result[index].joint(name) else { continue }
                if let previousIndex, index - previousIndex > 1, index - previousIndex <= 3,
                   result[index].time - result[previousIndex].time <= 3.25 * sampleInterval,
                   let previous = result[previousIndex].joint(name) {
                    for gap in (previousIndex + 1)..<index {
                        let fraction = (result[gap].time - result[previousIndex].time) / (result[index].time - result[previousIndex].time)
                        result[gap].joints.append(.init(name: name,
                            x: previous.x + (current.x - previous.x) * fraction,
                            y: previous.y + (current.y - previous.y) * fraction,
                            confidence: min(previous.confidence, current.confidence) * 0.8, interpolated: true))
                    }
                }
                previousIndex = index
            }
            // Never smooth across a missing joint or a timestamp discontinuity.
            let segments = indexSegments(frames: result, jointName: name, maximumInterval: sampleInterval * 1.5)
            for segment in segments where segment.count >= 3 {
                let times = segment.map { result[$0].time }
                let x = ZeroPhaseSmoother.smooth(times: times, values: segment.map { result[$0].joint(name)!.x })
                let y = ZeroPhaseSmoother.smooth(times: times, values: segment.map { result[$0].joint(name)!.y })
                for (offset, frameIndex) in segment.enumerated() {
                    guard let jointIndex = result[frameIndex].joints.firstIndex(where: { $0.name == name }) else { continue }
                    result[frameIndex].joints[jointIndex].x = min(1, max(0, x[offset]))
                    result[frameIndex].joints[jointIndex].y = min(1, max(0, y[offset]))
                }
            }
        }
        return result
    }

    public static func trajectorySegments(frames: [PoseFrame], jointName: String, sampleInterval: Double) -> [[PoseTrajectoryPoint]] {
        guard sampleInterval.isFinite, sampleInterval > 0, interval(times: frames.map(\.time)) != nil else { return [] }
        return indexSegments(frames: frames, jointName: jointName, maximumInterval: sampleInterval * 1.5).map { indices in
            indices.compactMap { index in frames[index].joint(jointName).map { .init(time: frames[index].time, joint: $0) } }
        }
    }
    private static func indexSegments(frames: [PoseFrame], jointName: String, maximumInterval: Double) -> [[Int]] {
        var segments: [[Int]] = [], current: [Int] = []
        for index in frames.indices {
            guard frames[index].joint(jointName) != nil else {
                if !current.isEmpty { segments.append(current); current = [] }
                continue
            }
            if let previous = current.last, frames[index].time - frames[previous].time > maximumInterval {
                segments.append(current); current = []
            }
            current.append(index)
        }
        if !current.isEmpty { segments.append(current) }
        return segments
    }
}
