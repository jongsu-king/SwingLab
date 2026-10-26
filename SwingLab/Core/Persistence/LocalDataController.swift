import Foundation
import SwiftData
import SwingLabCore

@MainActor enum LocalDataController {
    /// V1 retains its original String columns. Canonicalize their content without a
    /// structural store change; typed accessors also support unopened legacy rows.
    static func normalizeRecordingMetadata(context: ModelContext) throws {
        var changed = false
        for recording in try context.fetch(FetchDescriptor<SwingRecording>()) {
            if recording.normalizeMetadata() { changed = true }
        }
        guard changed else { return }
        do { try context.save() }
        catch { context.rollback(); throw error }
    }
    static func recoverInterruptedDeletion(context: ModelContext) throws {
        let names = Set(try context.fetch(FetchDescriptor<SwingRecording>()).map(\.videoFileName))
        try MediaDeletionRecovery.reconcile(library: VideoLibrary.directory(), referencedNames: names)
    }
    /// Stage media removal before committing records. A failed save restores the library.
    static func deleteAll(context: ModelContext) throws {
        let manager = FileManager.default
        let library = try VideoLibrary.directory()
        let parent = library.deletingLastPathComponent()
        let staged = parent.appendingPathComponent("SwingVideos.deleted-" + UUID().uuidString)
        try manager.moveItem(at: library, to: staged)
        do {
            for value in try context.fetch(FetchDescriptor<SwingRecording>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<GolfClub>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<RoundSession>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<ShotRecord>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<HoleScore>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<GolfCourse>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<CourseHole>()) { context.delete(value) }
            try context.save()
        } catch {
            context.rollback()
            try manager.moveItem(at: staged, to: library)
            throw error
        }
        // If cleanup fails, the next deletion attempt also retries staged folders.
        let prefix = "SwingVideos.deleted-"
        for url in try manager.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)
            where url.lastPathComponent.hasPrefix(prefix)
                && UUID(uuidString: String(url.lastPathComponent.dropFirst(prefix.count))) != nil {
            try manager.removeItem(at: url)
        }
    }
}
