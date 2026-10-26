import Foundation

/// Launch conditions in SI units. These are inputs to a hypothetical simulation; SwingLab never
/// fills them from video, because a single camera does not observe them.
public struct LaunchConditions: Codable, Sendable, Equatable {
    public var ballSpeed: Double        // m/s
    public var launchAngle: Double      // degrees above horizontal
    public var launchDirection: Double  // degrees, positive = right of the target line
    public var spinRate: Double         // rpm
    public var spinAxis: Double         // degrees, positive tilts the axis so the ball curves right
    public init(ballSpeed: Double, launchAngle: Double, launchDirection: Double = 0, spinRate: Double, spinAxis: Double = 0) {
        self.ballSpeed = ballSpeed; self.launchAngle = launchAngle; self.launchDirection = launchDirection
        self.spinRate = spinRate; self.spinAxis = spinAxis
    }
}

public struct Atmosphere: Codable, Sendable, Equatable {
    public var temperature: Double       // K
    public var pressure: Double          // Pa (station pressure, not sea-level corrected)
    public var relativeHumidity: Double  // 0...1
    public init(temperature: Double, pressure: Double, relativeHumidity: Double) {
        self.temperature = temperature; self.pressure = pressure; self.relativeHumidity = relativeHumidity
    }
    public static let standard = Atmosphere(temperature: 293.15, pressure: 101_325, relativeHumidity: 0.5)

    /// Moist-air density: dry-air and water-vapour partial pressures as ideal gases. Saturation
    /// pressure uses the Magnus form of Alduchov & Eskridge (1996).
    public var density: Double {
        let celsius = temperature - 273.15
        let vapour = relativeHumidity * 610.94 * exp(17.625 * celsius / (celsius + 243.04))
        return (pressure - vapour) / (287.058 * temperature) + vapour / (461.495 * temperature)
    }
}

/// Uniform with height; real wind usually increases with height, so results near the apex are optimistic.
public struct Wind: Codable, Sendable, Equatable {
    public var tailwind: Double   // m/s along the target line; negative = headwind
    public var rightward: Double  // m/s across the target line
    public init(tailwind: Double, rightward: Double) { self.tailwind = tailwind; self.rightward = rightward }
    public static let calm = Wind(tailwind: 0, rightward: 0)
}

/// Aerodynamic model. The default is the Smits & Smith (1994) fit; see `Docs/Physics.md` for the
/// citation and its measured disagreement with TrackMan tour averages.
public struct AeroCoefficients: Codable, Sendable, Equatable {
    public var dragBase: Double       // C_D = dragBase + dragSpin · S
    public var dragSpin: Double
    public var liftScale: Double      // C_L = liftScale · S^liftExponent
    public var liftExponent: Double
    public var spinDecay: Double      // dω/dt = −spinDecay · ω · V / r
    public var id: String
    public static let smitsSmith1994 = AeroCoefficients(dragBase: 0.24, dragSpin: 0.18, liftScale: 0.54, liftExponent: 0.4,
                                                        spinDecay: 0.00002, id: "flight.smitsSmith1994.rk4.v1")
    /// Gravity only. Used to verify the integrator against the closed-form projectile range.
    public static let vacuum = AeroCoefficients(dragBase: 0, dragSpin: 0, liftScale: 0, liftExponent: 1, spinDecay: 0,
                                                id: "flight.vacuum.rk4.v1")
}

public struct FlightSample: Codable, Sendable, Equatable {
    public let time: Double
    public let forward: Double
    public let height: Double
    public let right: Double
}

public struct FlightResult: Codable, Sendable {
    public let carry: Double          // m, horizontal distance from launch to landing
    public let landingPoint: PlanePoint
    public let apex: Double           // m above launch
    public let flightTime: Double     // s
    public let landingAngle: Double   // degrees below horizontal
    public let landingSpinRate: Double // rpm
    public let trajectory: [FlightSample]
    public let model: String

    public var carryMetric: ProvenancedValue { metric(carry, "m") }
    public var lateralMetric: ProvenancedValue { metric(landingPoint.right, "m") }
    public var apexMetric: ProvenancedValue { metric(apex, "m") }
    public var flightTimeMetric: ProvenancedValue { metric(flightTime, "s") }
    public var landingAngleMetric: ProvenancedValue { metric(landingAngle * .pi / 180, "rad") }
    private func metric(_ value: Double, _ unit: String) -> ProvenancedValue {
        .init(value: value, unit: unit, provenance: .simulated, method: model)
    }
}

/// Carry-only point-mass simulation: gravity, quadratic drag, Magnus lift, spin decay, uniform wind,
/// RK4 at 1 ms. Roll after landing, bounce, and turf interaction are not modelled.
public enum BallFlight {
    public static let mass = 0.04593       // kg, USGA maximum
    public static let diameter = 0.04267   // m, USGA minimum
    static let gravity = 9.80665
    static let step = 0.001

    public static func simulate(_ launch: LaunchConditions, atmosphere: Atmosphere = .standard, wind: Wind = .calm,
                                landingHeight: Double = 0, coefficients: AeroCoefficients = .smitsSmith1994) throws -> FlightResult {
        let inputs = [launch.ballSpeed, launch.launchAngle, launch.launchDirection, launch.spinRate, launch.spinAxis,
                      atmosphere.temperature, atmosphere.pressure, atmosphere.relativeHumidity,
                      wind.tailwind, wind.rightward, landingHeight,
                      coefficients.dragBase, coefficients.dragSpin, coefficients.liftScale,
                      coefficients.liftExponent, coefficients.spinDecay]
        guard inputs.allSatisfy(\.isFinite), (1...100).contains(launch.ballSpeed), (-10...80).contains(launch.launchAngle),
              (-45...45).contains(launch.launchDirection), (0...15_000).contains(launch.spinRate), (-60...60).contains(launch.spinAxis),
              (233...333).contains(atmosphere.temperature), (50_000...110_000).contains(atmosphere.pressure),
              (0...1).contains(atmosphere.relativeHumidity), abs(wind.tailwind) <= 30, abs(wind.rightward) <= 30,
              abs(landingHeight) <= 100, coefficients.dragBase >= 0, coefficients.dragSpin >= 0,
              coefficients.liftScale >= 0, coefficients.liftExponent > 0, coefficients.spinDecay >= 0 else {
            throw ModelError.invalidInput
        }

        let radius = diameter / 2, area = Double.pi * radius * radius, rho = atmosphere.density
        let elevation = launch.launchAngle * .pi / 180, yaw = launch.launchDirection * .pi / 180, tilt = launch.spinAxis * .pi / 180
        // Axes: x forward along the target line, y up, z right. Backspin points along the launch's
        // horizontal right vector; a positive axis tilt lowers it so lift gains a rightward part.
        let right = Vector(x: -sin(yaw), y: 0, z: cos(yaw))
        let spinAxis = right * cos(tilt) - Vector(x: 0, y: 1, z: 0) * sin(tilt)
        let air = Vector(x: wind.tailwind, y: 0, z: wind.rightward)
        var position = Vector.zero
        var velocity = Vector(x: cos(elevation) * cos(yaw), y: sin(elevation), z: cos(elevation) * sin(yaw)) * launch.ballSpeed
        var omega = launch.spinRate * 2 * .pi / 60
        var time = 0.0, apex = 0.0
        var samples = [FlightSample(time: 0, forward: 0, height: 0, right: 0)]

        // A level/downward shot starting on the landing plane touches ground immediately.
        // Waiting for a positive-to-negative crossing would instead run beneath the ground.
        if landingHeight == 0, velocity.y <= 0 {
            return FlightResult(carry: 0, landingPoint: .init(forward: 0, right: 0), apex: 0, flightTime: 0,
                                landingAngle: -launch.launchAngle, landingSpinRate: launch.spinRate,
                                trajectory: samples, model: coefficients.id)
        }

        func acceleration(_ velocity: Vector, _ omega: Double) -> Vector {
            let relative = velocity - air
            let speed = relative.length
            guard speed > 1e-9 else { return Vector(x: 0, y: -gravity, z: 0) }
            let spinRatio = radius * omega / speed
            let drag = coefficients.dragBase + coefficients.dragSpin * spinRatio
            let lift = spinRatio > 0 ? coefficients.liftScale * pow(spinRatio, coefficients.liftExponent) : 0
            let k = 0.5 * rho * area * speed * speed / mass
            // Only the spin component perpendicular to the airflow produces lift.
            let liftDirection = spinAxis.cross(relative / speed)
            return (relative / speed) * (-drag * k) + liftDirection * (lift * k) + Vector(x: 0, y: -gravity, z: 0)
        }

        while time < 20 {
            let k1v = acceleration(velocity, omega), k1p = velocity
            let k2v = acceleration(velocity + k1v * (step / 2), omega), k2p = velocity + k1v * (step / 2)
            let k3v = acceleration(velocity + k2v * (step / 2), omega), k3p = velocity + k2v * (step / 2)
            let k4v = acceleration(velocity + k3v * step, omega), k4p = velocity + k3v * step
            let nextPosition = position + (k1p + k2p * 2 + k3p * 2 + k4p) * (step / 6)
            let nextVelocity = velocity + (k1v + k2v * 2 + k3v * 2 + k4v) * (step / 6)
            omega -= coefficients.spinDecay * omega * (velocity - air).length / radius * step
            time += step
            if nextVelocity.y < 0, nextPosition.y <= landingHeight, position.y > landingHeight {
                let fraction = (position.y - landingHeight) / (position.y - nextPosition.y)
                let landing = position + (nextPosition - position) * fraction
                let landingVelocity = velocity + (nextVelocity - velocity) * fraction
                let landingTime = time - step + step * fraction
                samples.append(.init(time: landingTime, forward: landing.x, height: landing.y, right: landing.z))
                return FlightResult(carry: hypot(landing.x, landing.z), landingPoint: PlanePoint(forward: landing.x, right: landing.z),
                                    apex: apex, flightTime: landingTime,
                                    landingAngle: atan2(-landingVelocity.y, hypot(landingVelocity.x, landingVelocity.z)) * 180 / .pi,
                                    landingSpinRate: omega * 60 / (2 * .pi), trajectory: samples, model: coefficients.id)
            }
            position = nextPosition
            velocity = nextVelocity
            apex = max(apex, position.y)
            if Int((time / step).rounded()) % 50 == 0 {
                samples.append(.init(time: time, forward: position.x, height: position.y, right: position.z))
            }
        }
        // The ball never came back down through the landing height (e.g. a target far above the apex).
        throw ModelError.insufficientData
    }
}

struct Vector: Sendable {
    var x: Double, y: Double, z: Double
    static let zero = Vector(x: 0, y: 0, z: 0)
    var length: Double { (x * x + y * y + z * z).squareRoot() }
    func cross(_ o: Vector) -> Vector { Vector(x: y * o.z - z * o.y, y: z * o.x - x * o.z, z: x * o.y - y * o.x) }
    static func + (a: Vector, b: Vector) -> Vector { Vector(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
    static func - (a: Vector, b: Vector) -> Vector { Vector(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z) }
    static func * (a: Vector, s: Double) -> Vector { Vector(x: a.x * s, y: a.y * s, z: a.z * s) }
    static func / (a: Vector, s: Double) -> Vector { Vector(x: a.x / s, y: a.y / s, z: a.z / s) }
}
