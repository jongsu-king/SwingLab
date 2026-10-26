import Foundation

public enum DistanceUnit: String, CaseIterable, Codable, Sendable {
    case yards, meters
    public var symbol: String { self == .yards ? "yd" : "m" }
    public func fromSI(_ value: Double) -> Double { self == .yards ? value / 0.9144 : value }
    public func toSI(_ value: Double) -> Double { self == .yards ? value * 0.9144 : value }
}
public enum SpeedUnit: String, CaseIterable, Codable, Sendable {
    case mph, kilometersPerHour, metersPerSecond
    public var symbol: String {
        switch self { case .mph: "mph"; case .kilometersPerHour: "km/h"; case .metersPerSecond: "m/s" }
    }
    public func fromSI(_ value: Double) -> Double {
        switch self { case .mph: value / 0.44704; case .kilometersPerHour: value * 3.6; case .metersPerSecond: value }
    }
    public func toSI(_ value: Double) -> Double {
        switch self { case .mph: value * 0.44704; case .kilometersPerHour: value / 3.6; case .metersPerSecond: value }
    }
}
public enum TemperatureUnit: String, CaseIterable, Codable, Sendable {
    case celsius, fahrenheit
    public var symbol: String { self == .celsius ? "°C" : "°F" }
    /// SI temperature is Kelvin.
    public func fromSI(_ kelvin: Double) -> Double { self == .celsius ? kelvin - 273.15 : (kelvin - 273.15) * 1.8 + 32 }
    public func toSI(_ value: Double) -> Double { (self == .celsius ? value : (value - 32) / 1.8) + 273.15 }
}
public enum MeasurementProvenance: String, Codable, CaseIterable, Sendable {
    case measured = "Measured"
    case visionDerived = "Vision-derived"
    case estimated = "Estimated"
    case simulated = "Simulated"
    case userEntered = "User-entered"
    case unavailable = "Unavailable"
}
