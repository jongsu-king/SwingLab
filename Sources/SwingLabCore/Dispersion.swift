import Foundation

public struct PlanePoint: Codable, Equatable, Sendable {
    public var forward: Double
    public var right: Double
    public init(forward: Double, right: Double) { self.forward = forward; self.right = right }
}
public enum ModelError: Error, Equatable { case invalidInput, insufficientData }

/// Bivariate normal in the shot's local forward/right plane; inputs are metres.
public struct GaussianDispersion: Sendable {
    public let mean: PlanePoint
    public let carrySD: Double
    public let lateralSD: Double
    public let correlation: Double
    public init(meanCarry: Double, meanLateral: Double, carrySD: Double, lateralSD: Double, correlation: Double) throws {
        guard [meanCarry, meanLateral, carrySD, lateralSD, correlation].allSatisfy(\.isFinite),
              meanCarry > 0, carrySD > 0, lateralSD > 0, abs(correlation) < 1 else { throw ModelError.invalidInput }
        mean = .init(forward: meanCarry, right: meanLateral)
        self.carrySD = carrySD; self.lateralSD = lateralSD; self.correlation = correlation
    }
    /// A 2D normal's probability mass uses chi-square(2), not a 1D z-score.
    public func ellipse(probability: Double, segments: Int = 72) -> [PlanePoint] {
        guard probability > 0, probability < 1, segments >= 8, segments <= 4096 else { return [] }
        let radius = sqrt(-2 * log(1 - probability))
        return (0...segments).map { index in
            let angle = Double(index) / Double(segments) * 2 * .pi
            return transform(z1: radius * cos(angle), z2: radius * sin(angle))
        }
    }
    public func squaredMahalanobisDistance(_ p: PlanePoint) -> Double {
        let u = (p.forward - mean.forward) / carrySD, v = (p.right - mean.right) / lateralSD
        return (u * u - 2 * correlation * u * v + v * v) / (1 - correlation * correlation)
    }
    public func transform(z1: Double, z2: Double) -> PlanePoint {
        .init(forward: mean.forward + carrySD * z1,
              right: mean.right + lateralSD * (correlation * z1 + sqrt(1 - correlation * correlation) * z2))
    }
    /// Deterministic stratified integration. Requires complete, supplied geometry.
    public func probability(in polygon: [PlanePoint], sampleCount: Int = 8192) -> Double? {
        guard polygon.count >= 3, polygon.allSatisfy({ $0.forward.isFinite && $0.right.isFinite }), sampleCount >= 256, sampleCount <= 1_000_000 else { return nil }
        var hits = 0
        let goldenRatio = 0.6180339887498949
        for i in 0..<sampleCount {
            let u = (Double(i) + 0.5) / Double(sampleCount)
            let v = (Double(i) * goldenRatio).truncatingRemainder(dividingBy: 1)
            let r = sqrt(-2 * log(u)), angle = 2 * .pi * v
            if Geometry.contains(transform(z1: r * cos(angle), z2: r * sin(angle)), polygon: polygon) { hits += 1 }
        }
        return Double(hits) / Double(sampleCount)
    }
}
public enum Geometry {
    public static func contains(_ point: PlanePoint, polygon: [PlanePoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false, j = polygon.count - 1
        for i in polygon.indices {
            let a = polygon[i], b = polygon[j]
            if (a.right > point.right) != (b.right > point.right),
               point.forward < (b.forward - a.forward) * (point.right - a.right) / (b.right - a.right) + a.forward { inside.toggle() }
            j = i
        }
        return inside
    }
    public static func jointAngle(a: PlanePoint, vertex: PlanePoint, b: PlanePoint) -> Double? {
        let u = PlanePoint(forward: a.forward - vertex.forward, right: a.right - vertex.right)
        let v = PlanePoint(forward: b.forward - vertex.forward, right: b.right - vertex.right)
        let length = hypot(u.forward, u.right) * hypot(v.forward, v.right)
        guard length > 1e-10, length.isFinite else { return nil }
        return acos(max(-1, min(1, (u.forward * v.forward + u.right * v.right) / length))) * 180 / .pi
    }
}
