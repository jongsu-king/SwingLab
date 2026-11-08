import Foundation

/// Turf the ball lands on. The surface is never measured, so every roll is a simulation for the
/// named assumption; `Docs/Physics.md` ("Bounce and roll") lists the constants and their status.
public struct TurfSurface: Codable, Sendable, Equatable {
    /// Rolling deceleration once the hops are over (m/s²).
    public var rollingDeceleration: Double
    /// Extra incidence added at the reference landing (18.6 m/s, 44.4°); it stands in for the
    /// ball digging into the turf, which absorbs forward speed that a flat plane would keep.
    public var tiltAtReference: Double
    public var id: String
    public init(rollingDeceleration: Double, tiltAtReference: Double, id: String) {
        self.rollingDeceleration = rollingDeceleration; self.tiltAtReference = tiltAtReference; self.id = id
    }
    public static let fairway = TurfSurface(rollingDeceleration: 2.0, tiltAtReference: 15.4 * .pi / 180,
                                            id: "roll.tiltedBounce.fairway.v1")
}

public struct RollResult: Codable, Sendable, Equatable {
    /// Ground distance after landing, hops and roll together (m). Negative when a high-spin
    /// landing backs the ball up.
    public let run: Double
    public let bounceCount: Int
    public let model: String
}

/// Bounce-and-roll after landing. Each bounce tilts the turf normal toward the incoming ball,
/// restitutes the normal speed with a speed-dependent coefficient, and leaves the ball rolling
/// along the tilted surface; hops shorter than a ball diameter end in rolling deceleration.
/// The restitution polynomial and the tilt are as quoted in secondary literature for Penner's
/// turf model; they have not been checked against the primary paper or against measured runs.
public enum BallRoll {
    static let referenceSpeed = 18.6, referenceDescent = 44.4 * Double.pi / 180
    static let maximumTilt = 40.0 * Double.pi / 180
    static let maximumBounces = 12

    /// - Parameters:
    ///   - landingSpeed: m/s.
    ///   - landingAngleDegrees: degrees below horizontal.
    ///   - landingSpinRate: rpm, positive = backspin.
    public static func run(landingSpeed: Double, landingAngleDegrees: Double, landingSpinRate: Double,
                           surface: TurfSurface = .fairway) throws -> RollResult {
        guard [landingSpeed, landingAngleDegrees, landingSpinRate, surface.rollingDeceleration, surface.tiltAtReference]
                .allSatisfy(\.isFinite), (0...100).contains(landingSpeed), (0...90).contains(landingAngleDegrees),
              (-20_000...20_000).contains(landingSpinRate), surface.rollingDeceleration > 0,
              (0...maximumTilt).contains(surface.tiltAtReference) else { throw ModelError.invalidInput }
        let radius = BallFlight.diameter / 2, gravity = BallFlight.gravity
        var speed = landingSpeed, descent = landingAngleDegrees * .pi / 180
        var backspin = landingSpinRate * 2 * .pi / 60
        var run = 0.0, bounces = 0
        while bounces < maximumBounces, speed * sin(descent) > 0.5 {
            let tilt = min(maximumTilt, surface.tiltAtReference * (speed / referenceSpeed) * (descent / referenceDescent))
            let incidence = min(descent + tilt, 89 * .pi / 180)
            let normal = speed * sin(incidence), tangential = speed * cos(incidence)
            let normalOut = restitution(normal) * normal
            // Friction ends the contact with the ball rolling on the tilted surface; backspin takes
            // forward speed away, topspin from an earlier bounce gives it back.
            let tangentialOut = (5 * tangential - 2 * radius * backspin) / 7
            backspin = -tangentialOut / radius
            let horizontal = tangentialOut * cos(tilt) + normalOut * sin(tilt)
            let vertical = normalOut * cos(tilt) - tangentialOut * sin(tilt)
            bounces += 1
            // The ball stays down, or kicks backwards: it rolls out from here.
            guard vertical > 0, horizontal > 0 else {
                return RollResult(run: run + roll(horizontal, surface), bounceCount: bounces, model: surface.id)
            }
            let hop = 2 * horizontal * vertical / gravity
            run += hop
            speed = hypot(horizontal, vertical)
            descent = atan2(vertical, horizontal)
            if hop < BallFlight.diameter { break }
        }
        return RollResult(run: run + roll(speed * cos(descent), surface), bounceCount: bounces, model: surface.id)
    }

    /// Normal coefficient of restitution of a golf ball on turf against the normal speed (m/s).
    static func restitution(_ normalSpeed: Double) -> Double {
        min(0.9, max(0.12, 0.510 - 0.0375 * normalSpeed + 0.000903 * normalSpeed * normalSpeed))
    }

    /// Signed rolling distance from a ground speed; a negative speed rolls backwards.
    private static func roll(_ groundSpeed: Double, _ surface: TurfSurface) -> Double {
        groundSpeed * abs(groundSpeed) / (2 * surface.rollingDeceleration)
    }
}
