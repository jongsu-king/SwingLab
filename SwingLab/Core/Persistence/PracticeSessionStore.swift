import Foundation
import SwiftData
import SwingLabCore

/// Thin SwiftData adapter. Each method stages mutations; its caller saves and rolls back
/// on failure. No actor annotation: migration closures already own their ModelContext.
enum PracticeSessionStore {
    static func groupUngroupedRecordings(context: ModelContext) throws {
        let ungrouped = try context.fetch(FetchDescriptor<SwingRecording>()).filter { $0.practiceSession == nil }
        let lookup = Dictionary(uniqueKeysWithValues: ungrouped.map { ($0.id, $0) })
        let samples = ungrouped.map { sample(for: $0, handedness: $0.handednessOverride) }
        for group in PracticeGrouping.groups(for: samples) {
            let session = PracticeSession(date: group.date, clubID: group.context.clubID,
                                          cameraAngle: group.context.cameraAngle, handedness: group.context.handedness)
            session.id = group.id
            context.insert(session)
            for id in group.recordingIDs { lookup[id]?.practiceSession = session }
        }
    }

    static func assign(recording: SwingRecording, context: ModelContext, defaultHandedness: Handedness) throws {
        guard recording.practiceSession == nil else { return }
        // Capture the current preference at recording creation; changing Settings later
        // must not silently rewrite this recording's known context or session grouping.
        let handedness = recording.handednessOverride ?? defaultHandedness
        recording.handednessOverride = handedness
        let sessions = try context.fetch(FetchDescriptor<PracticeSession>())
        let candidates = sessions.compactMap { session -> PracticeSessionCandidate? in
            guard let last = session.recordings.map(\.createdAt).max() else { return nil }
            return .init(id: session.id, lastRecordingDate: last,
                         context: .init(clubID: session.clubID, cameraAngle: session.cameraAngleValue, handedness: session.handedness))
        }
        if let id = PracticeGrouping.matchingSession(for: sample(for: recording, handedness: handedness), candidates: candidates),
           let session = sessions.first(where: { $0.id == id }) {
            recording.practiceSession = session
        } else { _ = try newSession(for: recording, context: context, defaultHandedness: handedness) }
    }

    static func regroup(recording: SwingRecording, to session: PracticeSession, context: ModelContext) throws {
        let old = recording.practiceSession
        // An empty annotated session keeps its historical date until it receives a recording.
        // Derive the new date from actual members, not that retained metadata value.
        let dates = session.recordings.filter { $0.id != recording.id }.map(\.createdAt) + [recording.createdAt]
        recording.practiceSession = session
        session.date = dates.min() ?? recording.createdAt
        removeEmpty(old, excluding: recording.id, replacement: session, context: context)
    }

    @discardableResult static func newSession(for recording: SwingRecording, context: ModelContext,
                                              defaultHandedness: Handedness?) throws -> PracticeSession {
        let old = recording.practiceSession
        let session = PracticeSession(date: recording.createdAt, clubID: recording.clubID,
                                      cameraAngle: recording.cameraAngleValue,
                                      handedness: recording.handednessOverride ?? defaultHandedness)
        context.insert(session)
        recording.practiceSession = session
        removeEmpty(old, excluding: recording.id, replacement: session, context: context)
        return session
    }

    /// Stage the recording deletion and the same session cleanup used by regrouping.
    /// The caller owns the media-file transaction and saves or rolls back these mutations.
    static func remove(recording: SwingRecording, context: ModelContext) {
        if let session = recording.practiceSession {
            refreshSession(session, excluding: recording.id, context: context)
        }
        context.delete(recording)
    }

    private static func removeEmpty(_ old: PracticeSession?, excluding recordingID: UUID,
                                    replacement: PracticeSession, context: ModelContext) {
        guard let old, old.id != replacement.id else { return }
        refreshSession(old, excluding: recordingID, context: context)
    }

    private static func refreshSession(_ session: PracticeSession, excluding recordingID: UUID,
                                       context: ModelContext) {
        let remaining = session.recordings.filter { $0.id != recordingID }
        if remaining.isEmpty, session.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { context.delete(session) }
        else if let first = remaining.map(\.createdAt).min() { session.date = first }
    }

    private static func sample(for recording: SwingRecording, handedness: Handedness?) -> PracticeGroupingSample {
        .init(id: recording.id, date: recording.createdAt,
              context: .init(clubID: recording.clubID, cameraAngle: recording.cameraAngleValue, handedness: handedness))
    }
}
