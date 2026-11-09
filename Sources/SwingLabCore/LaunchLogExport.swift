import Foundation

/// One saved launch as it is exported: the measured values with their provenance, nothing simulated.
public struct LaunchLogRow: Sendable, Equatable {
    public let date: Date
    public let club: String
    public let source: String
    public let ballSpeedMetersPerSecond: Double
    public let launchAngleRadians: Double
    public let provenance: Provenance
    public let confidence: Double?
    public let relativeSpeedUncertainty: Double
    public let trackedPositions: Int
    public let method: String
    public init(date: Date, club: String, source: String, ballSpeedMetersPerSecond: Double, launchAngleRadians: Double,
                provenance: Provenance, confidence: Double?, relativeSpeedUncertainty: Double, trackedPositions: Int, method: String) {
        self.date = date; self.club = club; self.source = source; self.ballSpeedMetersPerSecond = ballSpeedMetersPerSecond
        self.launchAngleRadians = launchAngleRadians; self.provenance = provenance; self.confidence = confidence
        self.relativeSpeedUncertainty = relativeSpeedUncertainty; self.trackedPositions = trackedPositions; self.method = method
    }
}

/// CSV in SI units with a provenance column, so a spreadsheet cannot mistake a simulation for a
/// measurement: carry, total, spin, and club speed are deliberately absent.
public enum LaunchLogExport {
    public static let header = "date_iso8601,club,source,ball_speed_m_s,launch_angle_deg,provenance,confidence,relative_speed_uncertainty,tracked_positions,method"

    public static func csv(_ rows: [LaunchLogRow]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var lines = [header]
        for row in rows.sorted(by: { $0.date < $1.date }) {
            lines.append([
                formatter.string(from: row.date), escape(row.club), escape(row.source),
                number(row.ballSpeedMetersPerSecond, digits: 3), number(row.launchAngleRadians * 180 / .pi, digits: 2),
                row.provenance.rawValue, row.confidence.map { number($0, digits: 3) } ?? "",
                number(row.relativeSpeedUncertainty, digits: 4), String(row.trackedPositions), escape(row.method)
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func number(_ value: Double, digits: Int) -> String {
        guard value.isFinite else { return "" }
        return String(format: "%.\(digits)f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    /// RFC 4180 quoting for fields that contain a comma, a quote, or a line break.
    static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
