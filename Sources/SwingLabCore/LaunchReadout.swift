import Foundation

/// Shortest and longest value of a quantity computed across an assumption bracket.
public struct ReadoutRange: Sendable, Equatable {
    public let low: ProvenancedValue
    public let high: ProvenancedValue
    public init(low: ProvenancedValue, high: ProvenancedValue) { self.low = low; self.high = high }
    public var provenance: Provenance { low.provenance }
    public var isAvailable: Bool { low.value != nil && high.value != nil }
}

/// The launch-monitor readout for one measured launch: carry, total, ball speed, club speed,
/// back spin, and launch angle. Only ball speed and launch angle are measured (vision-derived).
/// Carry and total are simulated across the cited spin bracket for the club; club speed is
/// estimated from published smash factors; spin is the published bracket itself. Each tile keeps
/// its own provenance so none of them can be read as a measurement.
public struct LaunchReadout: Sendable {
    public let club: ReferenceClub
    /// Set when the club was chosen automatically from the launch.
    public let clubGuess: ClubGuess?
    public let ballSpeed: ProvenancedValue      // m/s, vision-derived
    public let launchAngle: ProvenancedValue    // rad, vision-derived
    public let carry: ReadoutRange?             // m, simulated
    public let total: ReadoutRange?             // m, simulated (carry + bounce-and-roll)
    public let apex: ReadoutRange?              // m, simulated
    public let clubSpeed: ReadoutRange?         // m/s, estimated from published smash factors
    public let spin: ReadoutRange?              // rpm, reference bracket
    /// Side view of the simulated flight at the middle of the spin bracket; empty when unavailable.
    public let trajectory: [FlightSample]
    /// Ground run after landing for that same middle flight (m, simulated).
    public let run: Double
    /// The middle flight and its run, for the animated scene. Lateral motion is unknown for a
    /// face-on measurement, so the ball is drawn straight along the target line.
    public var playback: FlightPlayback { FlightPlayback(samples: trajectory, run: run) }
    public let surface: TurfSurface
    public let citations: [ReferenceCitation]
}

public enum LaunchReadoutBuilder {
    public static let totalMethod = "total.carryPlusTiltedBounceRoll.v1"
    public static let apexMethod = "apex.referenceSpinRange.v1"
    public static let clubSpeedMethod = "clubSpeed.publishedSmashFactor.v1"
    public static let spinMethod = "spin.publishedBracket.v1"
    public static let spinSampleCount = 5

    public static func build(measurement: LaunchMeasurement, club: ReferenceClub?, atmosphere: Atmosphere = .standard,
                             wind: Wind = .calm, surface: TurfSurface = .fairway) -> LaunchReadout? {
        build(ballSpeed: measurement.ballSpeed, launchAngle: measurement.launchAngle, club: club, atmosphere: atmosphere,
              wind: wind, surface: surface)
    }

    /// The golfer's range conditions (air and wind) instead of the standard atmosphere.
    public static func build(measurement: LaunchMeasurement, club: ReferenceClub?, conditions: RangeConditions,
                             surface: TurfSurface = .fairway) -> LaunchReadout? {
        let applied = conditions.isValid ? conditions : .standard
        return build(measurement: measurement, club: club, atmosphere: applied.atmosphere, wind: applied.wind, surface: surface)
    }

    /// `club` nil chooses the nearest published club from the launch (`ClubGuess`), falling back to
    /// a 7-iron when nothing published is near. Returns nil unless the speed is actually measured.
    public static func build(ballSpeed speed: ProvenancedValue, launchAngle angle: ProvenancedValue, club: ReferenceClub?,
                             atmosphere: Atmosphere = .standard, wind: Wind = .calm, surface: TurfSurface = .fairway) -> LaunchReadout? {
        guard [.measured, .visionDerived].contains(speed.provenance), speed.unit == "m/s", angle.unit == "rad",
              let speedValue = speed.value, let angleValue = angle.value else { return nil }
        var guess: ClubGuess?
        let chosen: ReferenceClub
        if let club { chosen = club }
        else {
            guess = ReferenceLaunchData.nearestClub(ballSpeed: speed, launchAngle: angle)
            chosen = guess?.club ?? .iron7
        }
        var citations: [ReferenceCitation] = []
        var carry: ReadoutRange?, total: ReadoutRange?, apex: ReadoutRange?, spin: ReadoutRange?
        var trajectory: [FlightSample] = [], run = 0.0
        if let assumption = ReferenceLaunchData.spinAssumption(club: chosen) {
            citations += assumption.citations
            let rpm = assumption.revolutionsPerMinute
            let samples = (0..<spinSampleCount).map {
                rpm.lowerBound + Double($0) / Double(spinSampleCount - 1) * (rpm.upperBound - rpm.lowerBound)
            }
            var flights: [(carry: Double, total: Double, apex: Double, trajectory: [FlightSample], run: Double)] = []
            for sample in samples {
                guard let flight = try? BallFlight.simulate(LaunchConditions(ballSpeed: speedValue, launchAngle: angleValue * 180 / .pi,
                                                                             spinRate: sample), atmosphere: atmosphere, wind: wind),
                      let roll = try? BallRoll.run(landingSpeed: flight.landingSpeed, landingAngleDegrees: max(0, flight.landingAngle),
                                                   landingSpinRate: flight.landingSpinRate, surface: surface) else { continue }
                flights.append((flight.carry, flight.carry + roll.run, flight.apex, flight.trajectory, roll.run))
            }
            if !flights.isEmpty {
                func range(_ values: [Double], unit: String, method: String) -> ReadoutRange {
                    ReadoutRange(low: ProvenancedValue(value: values.min(), unit: unit, provenance: .simulated, method: method,
                                                       sampleCount: values.count),
                                 high: ProvenancedValue(value: values.max(), unit: unit, provenance: .simulated, method: method,
                                                        sampleCount: values.count))
                }
                carry = range(flights.map(\.carry), unit: "m", method: CarryRangeEstimator.method)
                total = range(flights.map(\.total), unit: "m", method: totalMethod)
                apex = range(flights.map(\.apex), unit: "m", method: apexMethod)
                trajectory = flights[flights.count / 2].trajectory
                run = flights[flights.count / 2].run
            }
            spin = ReadoutRange(low: ProvenancedValue(value: rpm.lowerBound, unit: "rpm", provenance: .reference, method: spinMethod,
                                                      sampleCount: assumption.rowIDs.count),
                                high: ProvenancedValue(value: rpm.upperBound, unit: "rpm", provenance: .reference, method: spinMethod,
                                                       sampleCount: assumption.rowIDs.count))
        }
        let clubSpeed = estimatedClubSpeed(ballSpeed: speed, club: chosen)
        if let smash = ReferenceLaunchData.smashAssumption(club: chosen) { citations += smash.citations }
        return LaunchReadout(club: chosen, clubGuess: guess, ballSpeed: speed, launchAngle: angle, carry: carry, total: total,
                             apex: apex, clubSpeed: clubSpeed, spin: spin, trajectory: trajectory, run: run, surface: surface,
                             citations: citations)
    }

    /// Measured ball speed divided by the published smash-factor bracket for the club. The club
    /// head is never observed, so this is an estimate that inherits the speed's confidence.
    public static func estimatedClubSpeed(ballSpeed: ProvenancedValue, club: ReferenceClub) -> ReadoutRange? {
        guard [.measured, .visionDerived].contains(ballSpeed.provenance), ballSpeed.unit == "m/s", let speed = ballSpeed.value,
              let smash = ReferenceLaunchData.smashAssumption(club: club), smash.lowerSI > 0 else { return nil }
        func value(_ factor: Double) -> ProvenancedValue {
            ProvenancedValue(value: speed / factor, unit: "m/s", provenance: .estimated, confidence: ballSpeed.confidence,
                             method: clubSpeedMethod, sampleCount: smash.citations.count)
        }
        return ReadoutRange(low: value(smash.upperSI), high: value(smash.lowerSI))
    }
}
