import Foundation

public struct GeoCoordinate: Codable, Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public init(latitude: Double, longitude: Double) { self.latitude = latitude; self.longitude = longitude }
    public var isValid: Bool { latitude.isFinite && longitude.isFinite && abs(latitude) <= 90 && abs(longitude) <= 180 }
}
public enum Geo {
    public static let earthRadius = 6_371_008.8
    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    public static func distance(from a: GeoCoordinate, to b: GeoCoordinate) -> Double {
        guard a.isValid, b.isValid else { return .nan }
        let p1 = radians(a.latitude), p2 = radians(b.latitude)
        let dp = p2 - p1, dl = radians(b.longitude - a.longitude)
        let h = pow(sin(dp / 2), 2) + cos(p1) * cos(p2) * pow(sin(dl / 2), 2)
        return earthRadius * 2 * atan2(sqrt(max(0, min(1, h))), sqrt(max(0, 1 - h)))
    }
    public static func bearing(from a: GeoCoordinate, to b: GeoCoordinate) -> Double {
        guard a.isValid, b.isValid else { return .nan }
        let p1 = radians(a.latitude), p2 = radians(b.latitude), dl = radians(b.longitude - a.longitude)
        let angle = atan2(sin(dl) * cos(p2), cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)) * 180 / .pi
        return (angle + 360).truncatingRemainder(dividingBy: 360)
    }
    public static func destination(from origin: GeoCoordinate, bearingDegrees: Double, distanceMeters: Double) -> GeoCoordinate {
        guard origin.isValid, bearingDegrees.isFinite, distanceMeters.isFinite else { return .init(latitude: .nan, longitude: .nan) }
        let d = distanceMeters / earthRadius, b = radians(bearingDegrees), p = radians(origin.latitude), l = radians(origin.longitude)
        let p2 = asin(max(-1, min(1, sin(p) * cos(d) + cos(p) * sin(d) * cos(b))))
        let l2 = l + atan2(sin(b) * sin(d) * cos(p), cos(d) - sin(p) * sin(p2))
        let longitude = ((l2 * 180 / .pi + 540).truncatingRemainder(dividingBy: 360)) - 180
        return .init(latitude: p2 * 180 / .pi, longitude: longitude)
    }
    public static func project(origin: GeoCoordinate, bearingDegrees: Double, forward: Double, right: Double) -> GeoCoordinate {
        destination(from: origin, bearingDegrees: bearingDegrees + atan2(right, forward) * 180 / .pi, distanceMeters: hypot(forward, right))
    }
}
