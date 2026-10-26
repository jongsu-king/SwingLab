import Foundation

public struct ClubTrackPoint: Codable, Sendable, Equatable {
    public let time: Double
    public let x: Double
    public let y: Double
    public let confidence: Double
    public init(time: Double, x: Double, y: Double, confidence: Double) {
        self.time = time; self.x = x; self.y = y; self.confidence = confidence
    }
}
public struct SeededClubTrack: Sendable {
    public private(set) var points: [ClubTrackPoint] = []
    public private(set) var lostAt: Double?
    public let endTime: Double
    /// An engineering stop threshold, not a calibrated probability of club identity.
    public static let minimumConfidence = 0.5
    public init(endTime: Double) { self.endTime = endTime }
    /// Never reacquires or extrapolates after loss, never tracks beyond the top marker.
    @discardableResult public mutating func append(_ point: ClubTrackPoint) -> Bool {
        guard lostAt == nil, point.time.isFinite, point.time <= endTime else { return false }
        guard [point.x, point.y, point.confidence].allSatisfy(\.isFinite),
              (0...1).contains(point.x), (0...1).contains(point.y),
              (Self.minimumConfidence...1).contains(point.confidence),
              points.last.map({ point.time > $0.time && point.time - $0.time <= 0.1 }) ?? true else {
            lostAt = point.time; return false
        }
        points.append(point); return true
    }
    public mutating func markLost(at time: Double) {
        if lostAt == nil, time.isFinite, time <= endTime { lostAt = time }
    }
}
