import Foundation

/// Image scale from the ball at address: a golf ball is 42.67 mm in diameter (USGA minimum),
/// so its apparent diameter converts pixels to millimetres at the ball's depth.
public struct BallScale: Codable, Sendable, Equatable {
    public let center: PixelPoint
    public let diameterPixels: Double
    /// Sample standard deviation of the per-frame diameters (pixels).
    public let diameterStandardDeviation: Double
    public let frameCount: Int
    public var millimetresPerPixel: Double { BallScaleFitter.ballDiameterMillimetres / diameterPixels }
    /// Relative scale uncertainty; floored at 0.2 px because sub-pixel fits are not perfect.
    public var relativeUncertainty: Double { max(diameterStandardDeviation, 0.2) / diameterPixels }
}

public enum BallScaleFitter {
    public static let ballDiameterMillimetres = 42.67

    /// One frame: a round blob brighter than its surroundings, measured with partial-pixel area.
    public static func measure(_ image: GrayImage, near guess: PixelPoint, searchRadius: Int) -> (center: PixelPoint, diameter: Double)? {
        let cx = Int(guess.x), cy = Int(guess.y)
        let minX = max(0, cx - searchRadius), maxX = min(image.width - 1, cx + searchRadius)
        let minY = max(0, cy - searchRadius), maxY = min(image.height - 1, cy + searchRadius)
        guard maxX - minX >= 8, maxY - minY >= 8 else { return nil }
        var border: [Float] = [], inside: [Float] = []
        var brightest = (minX, minY), brightestValue: Float = -1
        for y in minY...maxY { for x in minX...maxX {
            let value = image[x, y]
            inside.append(value)
            if x == minX || y == minY || x == maxX || y == maxY { border.append(value) }
            if value > brightestValue { brightestValue = value; brightest = (x, y) }
        } }
        let background = BlobFinder.percentile(border, 0.5), peak = BlobFinder.percentile(inside, 0.99)
        guard peak - background > 0.15 else { return nil }
        var mask = [Bool](repeating: false, count: image.pixels.count)
        var weight = [Double](repeating: 0, count: image.pixels.count)
        for y in minY...maxY { for x in minX...maxX {
            let index = y * image.width + x, value = Double(image[x, y])
            weight[index] = min(1, max(0, (value - background) / (peak - background)))
            mask[index] = weight[index] > 0.5
        } }
        guard let blob = BlobFinder.blob(seed: brightest, mask: mask, weight: weight, width: image.width,
                                         height: image.height, bounds: (minX, minY, maxX, maxY)),
              !blob.touchesBorder, max(blob.width, blob.height) / min(blob.width, blob.height) <= 1.35 else { return nil }
        let diameter = 2 * (blob.area / .pi).squareRoot()
        return diameter >= 6 ? (blob.center, diameter) : nil
    }

    /// Several still address frames; at least three must measure, and they must agree.
    public static func fit(frames: [GrayImage], near guess: PixelPoint, searchRadius: Int) -> BallScale? {
        let measured = frames.compactMap { measure($0, near: guess, searchRadius: searchRadius) }
        guard measured.count >= 3 else { return nil }
        let diameters = measured.map(\.diameter)
        let mean = diameters.reduce(0, +) / Double(diameters.count)
        let sd = (diameters.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(diameters.count - 1)).squareRoot()
        guard sd / mean < 0.05 else { return nil }
        let center = PixelPoint(x: measured.map(\.center.x).reduce(0, +) / Double(measured.count),
                                y: measured.map(\.center.y).reduce(0, +) / Double(measured.count))
        return BallScale(center: center, diameterPixels: mean, diameterStandardDeviation: sd, frameCount: measured.count)
    }
}

public enum LaunchFailure: String, Error, Codable, Sendable {
    /// The shutter was open long enough to smear the ball into a long streak; the mode refuses.
    case exposureTooLong
    /// Exposure unknown (imported video) and the ball is smeared over more than four diameters.
    case tooBlurred
    case ballNotFound
    case tooFewObservations
    case implausibleSpeed
}

/// A ball position after launch, timed at the middle of the exposure window.
public struct LaunchObservation: Codable, Sendable, Equatable {
    public let time: Double
    public let center: PixelPoint
}

public struct LaunchMeasurement: Codable, Sendable {
    public let ballSpeed: ProvenancedValue    // m/s
    public let launchAngle: ProvenancedValue  // rad, upward positive, in the image plane
    public let relativeSpeedUncertainty: Double
    public let residualPixels: Double
    public let observations: [LaunchObservation]
}

/// Face-on launch measurement for `Docs/Specs/LaunchMonitor.md`. Experimental until validated
/// against a reference launch monitor (Acceptance A22/A23). Rolling-shutter skew is ignored.
public enum LaunchTracker {
    public static let maximumExposure = 1.0 / 1000
    public static let method = "launch.faceOnTrack.v1"

    /// `reference` is a still frame with the ball at address. `targetDirection` is +1 when the ball
    /// flies toward increasing image x, −1 otherwise. Only motion ahead of and not below the ball counts.
    /// `exposure` is nil for imported video whose shutter time is unknown: positions are then timed at
    /// frame start (a constant offset that cancels in the velocity) and smear is limited by shape instead.
    public static func observe(frames: [(time: Double, image: GrayImage)], reference: GrayImage, scale: BallScale,
                               exposure: Double?, targetDirection: Double) -> Result<[LaunchObservation], LaunchFailure> {
        if let exposure { guard exposure.isFinite, exposure > 0, exposure <= maximumExposure else { return .failure(.exposureTooLong) } }
        let timeOffset = (exposure ?? 0) / 2
        var rejectedForBlur = false
        let radius = scale.diameterPixels / 2
        let sx = Int(scale.center.x), sy = Int(scale.center.y)
        guard reference.contains(sx, sy) else { return .failure(.ballNotFound) }
        let contrast = Double(reference[sx, sy]) - BlobFinder.percentile(reference.pixels, 0.5)
        guard contrast > 0.15 else { return .failure(.ballNotFound) }
        let ballArea = Double.pi * radius * radius
        var observations: [LaunchObservation] = []
        for frame in frames.sorted(by: { $0.time < $1.time }) {
            let image = frame.image
            guard image.width == reference.width, image.height == reference.height else { continue }
            var mask = [Bool](repeating: false, count: image.pixels.count)
            var weight = [Double](repeating: 0, count: image.pixels.count)
            for y in 0..<image.height { for x in 0..<image.width {
                let dx = Double(x) + 0.5 - scale.center.x, dy = Double(y) + 0.5 - scale.center.y
                // Ahead of the ball, not below its centre line, and outside the vacated address spot.
                guard dx * targetDirection > radius, dy <= radius, hypot(dx, dy) > 2 * radius else { continue }
                let index = y * image.width + x
                let difference = Double(image.pixels[index] - reference.pixels[index])
                weight[index] = min(1, max(0, difference / contrast))
                mask[index] = weight[index] > 0.3
            } }
            var seen = Set<Int>(), blobs: [Blob] = []
            for index in mask.indices where mask[index] && !seen.contains(index) {
                guard let found = BlobFinder.component(seed: (index % image.width, index / image.width), mask: mask, weight: weight,
                                                       width: image.width, height: image.height,
                                                       bounds: (0, 0, image.width - 1, image.height - 1)) else { continue }
                seen.formUnion(found.members)
                guard found.blob.area >= 0.3 * ballArea, !found.blob.touchesBorder else { continue }
                if exposure == nil, max(found.blob.width, found.blob.height) > 4 * scale.diameterPixels {
                    rejectedForBlur = true
                    continue
                }
                blobs.append(found.blob)
            }
            let expected: PixelPoint
            if observations.count >= 2 {
                let a = observations[observations.count - 2], b = observations[observations.count - 1]
                let dt = (frame.time + timeOffset - b.time) / (b.time - a.time)
                expected = PixelPoint(x: b.center.x + (b.center.x - a.center.x) * dt, y: b.center.y + (b.center.y - a.center.y) * dt)
            } else {
                expected = observations.last?.center ?? scale.center
            }
            guard let chosen = blobs.min(by: { hypot($0.center.x - expected.x, $0.center.y - expected.y) <
                                                 hypot($1.center.x - expected.x, $1.center.y - expected.y) }) else { continue }
            // The ball must keep moving forward; a static blob is not the ball.
            if let last = observations.last, (chosen.center.x - last.center.x) * targetDirection < radius { continue }
            observations.append(LaunchObservation(time: frame.time + timeOffset, center: chosen.center))
        }
        if observations.isEmpty { return .failure(rejectedForBlur ? .tooBlurred : .ballNotFound) }
        return .success(observations)
    }

    /// Least-squares straight line through the observations. Over the first ~20 ms gravity moves the
    /// ball ≈ 2 mm, far below the pixel scale, so a line is adequate.
    public static func fit(_ observations: [LaunchObservation], scale: BallScale) -> Result<LaunchMeasurement, LaunchFailure> {
        let points = observations.sorted { $0.time < $1.time }
        guard points.count >= 2, let first = points.first, let last = points.last, last.time > first.time else {
            return .failure(.tooFewObservations)
        }
        let times = points.map { $0.time - first.time }
        func line(_ values: [Double]) -> (slope: Double, intercept: Double) {
            let n = Double(values.count), meanT = times.reduce(0, +) / n, meanV = values.reduce(0, +) / n
            let covariance = zip(times, values).map { ($0 - meanT) * ($1 - meanV) }.reduce(0, +)
            let variance = times.map { ($0 - meanT) * ($0 - meanT) }.reduce(0, +)
            let slope = covariance / variance
            return (slope, meanV - slope * meanT)
        }
        let xs = points.map(\.center.x), ys = points.map(\.center.y)
        let fx = line(xs), fy = line(ys)
        let residuals = zip(times, zip(xs, ys)).map { t, p in hypot(p.0 - (fx.intercept + fx.slope * t), p.1 - (fy.intercept + fy.slope * t)) }
        let residual = (residuals.map { $0 * $0 }.reduce(0, +) / Double(residuals.count)).squareRoot()
        let speed = hypot(fx.slope, fy.slope) * scale.millimetresPerPixel / 1000
        guard speed.isFinite, (5...95).contains(speed) else { return .failure(.implausibleSpeed) }
        let angle = atan2(-fy.slope, abs(fx.slope))
        let span = hypot(last.center.x - first.center.x, last.center.y - first.center.y)
        let positionError = max(residual, 0.5)
        let relative = (pow(scale.relativeUncertainty, 2) + pow(2.0.squareRoot() * positionError / span, 2)).squareRoot()
        let confidence = max(0, min(0.95, 1 - relative / 0.10)) * (points.count >= 3 ? 1 : 0.8)
        return .success(LaunchMeasurement(
            ballSpeed: ProvenancedValue(value: speed, unit: "m/s", provenance: .visionDerived, confidence: confidence,
                                        method: method, sampleCount: points.count),
            launchAngle: ProvenancedValue(value: angle, unit: "rad", provenance: .visionDerived, confidence: confidence,
                                          method: method, sampleCount: points.count),
            relativeSpeedUncertainty: relative, residualPixels: residual, observations: points))
    }
}

/// Carry is never measured here: it is simulated from the measured launch with the cited spin range
/// for the club, and shown as the shortest and longest carry across that range.
public struct CarryRange: Sendable {
    public let shortest: ProvenancedValue
    public let longest: ProvenancedValue
    public let spinRevolutionsPerMinute: ClosedRange<Double>
    public let citations: [ReferenceCitation]
}

public enum CarryRangeEstimator {
    public static let method = "carry.referenceSpinRange.v1"

    public static func estimate(ballSpeed: ProvenancedValue, launchAngle: ProvenancedValue, club: ReferenceClub,
                                atmosphere: Atmosphere = .standard) -> CarryRange? {
        guard [.measured, .visionDerived].contains(ballSpeed.provenance), ballSpeed.unit == "m/s",
              launchAngle.unit == "rad", let speed = ballSpeed.value, let angle = launchAngle.value,
              let spin = ReferenceLaunchData.spinAssumption(club: club) else { return nil }
        let rpm = spin.revolutionsPerMinute
        let samples = (0...4).map { rpm.lowerBound + Double($0) / 4 * (rpm.upperBound - rpm.lowerBound) }
        let carries = samples.compactMap {
            try? BallFlight.simulate(LaunchConditions(ballSpeed: speed, launchAngle: angle * 180 / .pi, spinRate: $0),
                                     atmosphere: atmosphere).carry
        }
        guard let low = carries.min(), let high = carries.max() else { return nil }
        func metric(_ value: Double) -> ProvenancedValue {
            ProvenancedValue(value: value, unit: "m", provenance: .simulated, method: method, sampleCount: carries.count)
        }
        return CarryRange(shortest: metric(low), longest: metric(high), spinRevolutionsPerMinute: rpm, citations: spin.citations)
    }
}
