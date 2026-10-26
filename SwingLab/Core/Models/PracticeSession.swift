import Foundation
import SwiftData
import SwingLabCore

/// Session metadata is user-entered context, never a claim about measured swing conditions.
@Model
final class PracticeSession {
    @Attribute(.unique) var id: UUID
    var date: Date
    var clubID: UUID?
    var cameraAngleID: String
    /// Historical recordings without an explicit override keep unknown handedness.
    var handednessID: String?
    var notes: String
    @Relationship(deleteRule: .nullify, inverse: \SwingRecording.practiceSession)
    var recordings: [SwingRecording] = []

    init(date: Date, clubID: UUID? = nil, cameraAngle: CameraAngle = .unspecified,
         handedness: Handedness? = nil, notes: String = "") {
        id = UUID()
        self.date = date
        self.clubID = clubID
        cameraAngleID = cameraAngle.rawValue
        handednessID = handedness?.rawValue
        self.notes = notes
    }

    var cameraAngleValue: CameraAngle {
        get { CameraAngle(rawValue: cameraAngleID) ?? .unspecified }
        set { cameraAngleID = newValue.rawValue }
    }

    var handedness: Handedness? {
        get { handednessID.flatMap(Handedness.init(rawValue:)) }
        set { handednessID = newValue?.rawValue }
    }
}
