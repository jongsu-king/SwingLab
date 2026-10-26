import Foundation
import SwiftData
import SwingLabCore

@MainActor
enum CourseGeometryStore {
    /// Restore the exact pre-edit blob on failure. iOS 26 rollback can retain changed live values.
    /// A snapshot assignment is idempotent on runtimes that already restore those values.
    static func replaceAreas(_ areas: [CourseArea], on hole: CourseHole, context: ModelContext,
                             save: (ModelContext) throws -> Void = { try $0.save() }) throws {
        let previous = hole.referenceData
        hole.areas = areas
        do { try save(context) }
        catch {
            context.rollbackPendingChanges()
            hole.referenceData = previous
            throw error
        }
    }
}
