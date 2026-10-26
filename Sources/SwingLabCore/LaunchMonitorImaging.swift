import Foundation

/// Row-major luminance in 0...1. y grows downward (image convention). The launch monitor works on
/// small regions of interest, so frames are copied into this type only around the ball.
public struct GrayImage: Sendable {
    public let width: Int
    public let height: Int
    public var pixels: [Float]
    public init(width: Int, height: Int, pixels: [Float]) {
        precondition(width > 0 && height > 0 && pixels.count == width * height)
        self.width = width; self.height = height; self.pixels = pixels
    }
    public init(width: Int, height: Int, fill: Float) {
        self.init(width: width, height: height, pixels: [Float](repeating: fill, count: width * height))
    }
    public subscript(x: Int, y: Int) -> Float {
        get { pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }
    func contains(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < width && y < height }
}

public struct PixelPoint: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// One bright blob: intensity-weighted centroid, effective (partial-pixel) area, and extent.
struct Blob {
    var center: PixelPoint
    var area: Double
    var width: Double
    var height: Double
    var touchesBorder: Bool
}

enum BlobFinder {
    /// Flood-fills the 8-connected component that contains `seed` in `mask`, then measures it on the
    /// contrast map `weight` (0...1) over the component plus a one-pixel ring, so anti-aliased edge
    /// pixels contribute their partial coverage instead of being rounded in or out.
    static func blob(seed: (Int, Int), mask: [Bool], weight: [Double], width: Int, height: Int,
                     bounds: (Int, Int, Int, Int)) -> Blob? {
        component(seed: seed, mask: mask, weight: weight, width: width, height: height, bounds: bounds)?.blob
    }

    /// Same as `blob`, also returning the member pixel indices so callers can label every component once.
    static func component(seed: (Int, Int), mask: [Bool], weight: [Double], width: Int, height: Int,
                          bounds: (Int, Int, Int, Int)) -> (blob: Blob, members: Set<Int>)? {
        let (minX, minY, maxX, maxY) = bounds
        guard mask[seed.1 * width + seed.0] else { return nil }
        var visited = Set<Int>([seed.1 * width + seed.0]), stack = [seed], members: [(Int, Int)] = []
        var touches = false
        while let (x, y) = stack.popLast() {
            members.append((x, y))
            if x == minX || y == minY || x == maxX || y == maxY { touches = true }
            for dy in -1...1 { for dx in -1...1 where dx != 0 || dy != 0 {
                let nx = x + dx, ny = y + dy
                guard nx >= minX, ny >= minY, nx <= maxX, ny <= maxY else { continue }
                let index = ny * width + nx
                if mask[index], visited.insert(index).inserted { stack.append((nx, ny)) }
            } }
        }
        var ring = Set(members.map { $0.1 * width + $0.0 })
        for (x, y) in members { for dy in -1...1 { for dx in -1...1 {
            let nx = x + dx, ny = y + dy
            if nx >= minX, ny >= minY, nx <= maxX, ny <= maxY { ring.insert(ny * width + nx) }
        } } }
        var total = 0.0, sumX = 0.0, sumY = 0.0
        var lowX = Int.max, highX = Int.min, lowY = Int.max, highY = Int.min
        for index in ring {
            let w = weight[index]
            guard w > 0 else { continue }
            let x = index % width, y = index / width
            total += w; sumX += w * (Double(x) + 0.5); sumY += w * (Double(y) + 0.5)
            if w > 0.5 { lowX = min(lowX, x); highX = max(highX, x); lowY = min(lowY, y); highY = max(highY, y) }
        }
        guard total > 0, lowX <= highX else { return nil }
        let blob = Blob(center: PixelPoint(x: sumX / total, y: sumY / total), area: total,
                        width: Double(highX - lowX + 1), height: Double(highY - lowY + 1), touchesBorder: touches)
        return (blob, visited)
    }

    static func percentile(_ values: [Float], _ fraction: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return Double(sorted[min(sorted.count - 1, max(0, Int(fraction * Double(sorted.count - 1))))])
    }
}
