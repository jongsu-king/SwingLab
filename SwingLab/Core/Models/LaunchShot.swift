import Foundation
import SwiftData
import SwingLabCore

enum LaunchShotSource: String, Codable, Sendable {
    case liveCamera
    case recordedVideo
}

/// One launch measured by the camera. Ball speed and launch angle keep their provenance and are
/// stored in SI. Carry is not stored: it is a simulation that depends on the club chosen later.
@Model
final class LaunchShot {
    @Attribute(.unique) var id: UUID
    var date: Date
    var sourceID: String
    /// `ReferenceClub` chosen when the shot was saved; it selects the published spin range.
    var referenceClubID: String
    var ballSpeedMetersPerSecond: Double
    var launchAngleRadians: Double
    var provenanceID: String
    var confidence: Double?
    var relativeSpeedUncertainty: Double
    var trackedPositions: Int
    var method: String
    var notes: String

    /// nil when the measurement has no value; an unavailable launch is never saved as a shot.
    init?(measurement: LaunchMeasurement, club: ReferenceClub, source: LaunchShotSource, date: Date = .now) {
        guard let speed = measurement.ballSpeed.value, let angle = measurement.launchAngle.value,
              measurement.ballSpeed.provenance != .unavailable else { return nil }
        id = UUID()
        self.date = date
        sourceID = source.rawValue
        referenceClubID = club.rawValue
        ballSpeedMetersPerSecond = speed
        launchAngleRadians = angle
        provenanceID = measurement.ballSpeed.provenance.rawValue
        confidence = measurement.ballSpeed.confidence
        relativeSpeedUncertainty = measurement.relativeSpeedUncertainty
        trackedPositions = measurement.observations.count
        method = measurement.ballSpeed.method
        notes = ""
    }

    var source: LaunchShotSource? { LaunchShotSource(rawValue: sourceID) }
    var referenceClub: ReferenceClub? { ReferenceClub(rawValue: referenceClubID) }
    private var provenance: Provenance { Provenance(rawValue: provenanceID) ?? .unavailable }

    var ballSpeed: ProvenancedValue {
        ProvenancedValue(value: ballSpeedMetersPerSecond, unit: "m/s", provenance: provenance, confidence: confidence,
                         method: method, sampleCount: trackedPositions)
    }
    var launchAngle: ProvenancedValue {
        ProvenancedValue(value: launchAngleRadians, unit: "rad", provenance: provenance, confidence: confidence,
                         method: method, sampleCount: trackedPositions)
    }
}
