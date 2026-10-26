import SwiftData

extension ModelContext {
    /// Abort store-level pending work. This does not restore retained model values on
    /// iOS 26.4: fallible edits must additionally restore an explicit pre-edit snapshot.
    /// See AnalysisPersistence, PracticeSessionStore.saveChange, and CourseGeometryStore.
    func rollbackPendingChanges() {
        processPendingChanges()
        rollback()
    }
}
