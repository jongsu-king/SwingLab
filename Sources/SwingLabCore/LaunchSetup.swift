import Foundation

/// Whether the camera stands where the launch tracker can work, judged from the ball's apparent
/// size at address: too small and the scale is uncertain, too large and the ball leaves the frame
/// before enough positions are seen.
public struct LaunchSetupCheck: Sendable, Equatable {
    public enum Verdict: String, Sendable, Codable, CaseIterable {
        case tooClose, ready, tooFar
        public var localizationKey: LocalizationKey {
            switch self {
            case .tooClose: "Too close"
            case .ready: "Ready"
            case .tooFar: "Too far"
            }
        }
    }
    public let scale: BallScale
    /// Frames the ball is expected to stay inside the launch region at `LaunchSetupChecker.budgetBallSpeed`.
    public let framesInView: Double
    /// Camera-to-ball distance from the ball's apparent diameter and the lens field of view;
    /// unavailable when the field of view is unknown.
    public let cameraDistance: ProvenancedValue
    /// Where the camera could stand and be ready (m, nearest...farthest); nil without the field of
    /// view, or when no distance satisfies both the scale floor and the frame budget.
    public let recommendedDistance: ClosedRange<Double>?
    public let verdict: Verdict
}

public enum LaunchSetupChecker {
    public static let method = "setup.ballApparentSize.v1"
    /// Fast ball speed the frame budget is checked against (a strong drive).
    public static let budgetBallSpeed = 80.0
    /// Observations the line fit wants; below this the camera is too close.
    public static let minimumFramesInView = 2.5
    /// Below this apparent diameter the scale floor (0.2 px) alone is 2 %; the camera is too far.
    public static let minimumDiameterPixels = 10.0

    /// Pixel focal length of a lens from its horizontal field of view over `widthPixels`.
    public static func focalLengthPixels(fieldOfViewDegrees: Double, widthPixels: Int) -> Double? {
        guard fieldOfViewDegrees.isFinite, fieldOfViewDegrees > 1, fieldOfViewDegrees < 179, widthPixels > 0 else { return nil }
        return Double(widthPixels) / 2 / tan(fieldOfViewDegrees * .pi / 360)
    }

    /// - Parameters:
    ///   - scale: the fitted ball at address, in region coordinates.
    ///   - regionWidth: width of the launch region the tracker reads.
    ///   - targetDirection: +1 when the ball flies towards +x.
    ///   - focalLengthPixels: nil when the lens field of view is unknown.
    public static func check(scale: BallScale, frameRate: Double, regionWidth: Int, targetDirection: Double,
                             focalLengthPixels: Double?) -> LaunchSetupCheck {
        let radius = scale.diameterPixels / 2
        let ahead = targetDirection > 0 ? Double(regionWidth) - scale.center.x - radius : scale.center.x - radius
        let pixelsPerFrame = budgetBallSpeed * 1000 / scale.millimetresPerPixel / max(frameRate, 1)
        let frames = max(0, ahead) / pixelsPerFrame
        let distance = focalLengthPixels.map { $0 * BallScaleFitter.ballDiameterMillimetres / scale.diameterPixels / 1000 }
        let verdict: LaunchSetupCheck.Verdict = scale.diameterPixels < minimumDiameterPixels ? .tooFar
            : (frames < minimumFramesInView ? .tooClose : .ready)
        // The largest ball (nearest camera) that still leaves the frame budget, with the ball's room
        // ahead kept as it is now; the smallest is the scale floor.
        let largestDiameter = max(0, ahead) * BallScaleFitter.ballDiameterMillimetres * max(frameRate, 1)
            / (budgetBallSpeed * 1000 * minimumFramesInView)
        let recommended: ClosedRange<Double>? = focalLengthPixels.flatMap { focal in
            guard largestDiameter >= minimumDiameterPixels else { return nil }
            let nearest = focal * BallScaleFitter.ballDiameterMillimetres / largestDiameter / 1000
            let farthest = focal * BallScaleFitter.ballDiameterMillimetres / minimumDiameterPixels / 1000
            return nearest...farthest
        }
        return LaunchSetupCheck(scale: scale, framesInView: frames,
                                cameraDistance: ProvenancedValue(value: distance, unit: "m",
                                                                 provenance: distance == nil ? .unavailable : .visionDerived,
                                                                 method: method, sampleCount: scale.frameCount),
                                recommendedDistance: recommended, verdict: verdict)
    }
}

/// A strobe of the launch: the address frame and every flight frame combined pixel by pixel at
/// their brightest, so the ball appears once per frame along its track. A picture of what was
/// measured, not a replay.
public enum LaunchStrobe {
    public static func compose(reference: GrayImage, flight: [GrayImage]) -> GrayImage {
        var out = reference
        for frame in flight where frame.width == reference.width && frame.height == reference.height {
            for index in out.pixels.indices where frame.pixels[index] > out.pixels[index] { out.pixels[index] = frame.pixels[index] }
        }
        return out
    }
}
