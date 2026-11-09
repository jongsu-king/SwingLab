import Foundation

/// Where the golfer is hitting: air and wind the readout's simulations adopt. Every field is the
/// golfer's own entry; the phone measures none of them. Pressure follows from altitude with the
/// International Standard Atmosphere, so a mountain range reads longer than sea level.
public struct RangeConditions: Codable, Sendable, Equatable {
    public var temperatureKelvin: Double
    public var altitudeMetres: Double
    public var relativeHumidity: Double   // 0...1
    public var tailwind: Double           // m/s along the target line; negative = headwind
    public var crosswind: Double          // m/s across the target line; positive = left to right

    public init(temperatureKelvin: Double, altitudeMetres: Double, relativeHumidity: Double, tailwind: Double, crosswind: Double) {
        self.temperatureKelvin = temperatureKelvin; self.altitudeMetres = altitudeMetres
        self.relativeHumidity = relativeHumidity; self.tailwind = tailwind; self.crosswind = crosswind
    }

    /// 20 °C at sea level, 50 % humidity, calm: the conditions every earlier readout assumed.
    public static let standard = RangeConditions(temperatureKelvin: Atmosphere.standard.temperature, altitudeMetres: 0,
                                                 relativeHumidity: Atmosphere.standard.relativeHumidity, tailwind: 0, crosswind: 0)

    public var isStandard: Bool { self == .standard }
    public var pressure: Double { Atmosphere.pressure(atAltitude: altitudeMetres) }
    public var atmosphere: Atmosphere { Atmosphere(temperature: temperatureKelvin, pressure: pressure, relativeHumidity: relativeHumidity) }
    public var wind: Wind { Wind(tailwind: tailwind, rightward: crosswind) }

    /// Within what `BallFlight.simulate` accepts; anything else falls back to standard conditions.
    public var isValid: Bool {
        [temperatureKelvin, altitudeMetres, relativeHumidity, tailwind, crosswind].allSatisfy(\.isFinite)
            && (233...333).contains(temperatureKelvin) && (50_000...110_000).contains(pressure)
            && (0...1).contains(relativeHumidity) && abs(tailwind) <= 30 && abs(crosswind) <= 30
    }
}

public extension Atmosphere {
    /// International Standard Atmosphere pressure at a geopotential altitude (m), troposphere only:
    /// p = 101 325 Pa · (1 − 2.25577 × 10⁻⁵ · h)^5.25588. Clamped to −500…11 000 m.
    static func pressure(atAltitude metres: Double) -> Double {
        let altitude = min(11_000, max(-500, metres.isFinite ? metres : 0))
        return 101_325 * pow(1 - 2.25577e-5 * altitude, 5.25588)
    }
}
