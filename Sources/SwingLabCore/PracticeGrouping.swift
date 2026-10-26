import Foundation

/// Only user-provided context is used to partition automatic sessions. Unknown stays unknown.
public struct PracticeContext: Hashable, Sendable {
    public let clubID: UUID?
    public let cameraAngle: CameraAngle
    public let handedness: Handedness?

    public init(clubID: UUID?, cameraAngle: CameraAngle, handedness: Handedness?) {
        self.clubID = clubID; self.cameraAngle = cameraAngle; self.handedness = handedness
    }
}

public struct PracticeGroupingSample: Sendable {
    public let id: UUID
    public let date: Date
    public let context: PracticeContext
    public init(id: UUID, date: Date, context: PracticeContext) {
        self.id = id; self.date = date; self.context = context
    }
}

public struct PracticeGroup: Sendable {
    /// The first recording's ID provides a deterministic group identity for migration.
    public let id: UUID
    public let date: Date
    public var lastRecordingDate: Date
    public let context: PracticeContext
    public var recordingIDs: [UUID]
}

public struct PracticeSessionCandidate: Sendable {
    public let id: UUID
    public let lastRecordingDate: Date
    public let context: PracticeContext
    public init(id: UUID, lastRecordingDate: Date, context: PracticeContext) {
        self.id = id; self.lastRecordingDate = lastRecordingDate; self.context = context
    }
}

public enum PracticeGrouping {
    public static let maximumIdleInterval: TimeInterval = 90 * 60

    /// A rolling inactivity window, inclusive at 90 minutes. It is not a 90-minute
    /// maximum session duration. Equal timestamps are ordered by stable UUID text.
    public static func groups(for samples: [PracticeGroupingSample]) -> [PracticeGroup] {
        let ordered = samples.filter { $0.date.timeIntervalSince1970.isFinite }.sorted {
            $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date
        }
        var groups: [PracticeGroup] = []
        var lastGroup: [PracticeContext: Int] = [:]
        var seen = Set<UUID>()
        for sample in ordered where seen.insert(sample.id).inserted {
            if let index = lastGroup[sample.context],
               sample.date.timeIntervalSince(groups[index].lastRecordingDate) <= maximumIdleInterval {
                groups[index].recordingIDs.append(sample.id)
                groups[index].lastRecordingDate = sample.date
            } else {
                lastGroup[sample.context] = groups.count
                groups.append(.init(id: sample.id, date: sample.date, lastRecordingDate: sample.date,
                                    context: sample.context, recordingIDs: [sample.id]))
            }
        }
        return groups
    }

    /// Select the most recent compatible session preceding a new recording. Existing
    /// user regrouping is never rewritten. A future session is not an earlier baseline.
    public static func matchingSession(for sample: PracticeGroupingSample, candidates: [PracticeSessionCandidate]) -> UUID? {
        candidates.filter {
            let gap = sample.date.timeIntervalSince($0.lastRecordingDate)
            return $0.context == sample.context && gap.isFinite && gap >= 0 && gap <= maximumIdleInterval
        }.sorted {
            $0.lastRecordingDate == $1.lastRecordingDate ? $0.id.uuidString < $1.id.uuidString
                : $0.lastRecordingDate > $1.lastRecordingDate
        }.first?.id
    }
}
