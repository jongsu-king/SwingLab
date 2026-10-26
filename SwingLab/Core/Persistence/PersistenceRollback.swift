import SwiftData

extension ModelContext {
    /// iOS 26.4 can defer registering synchronous model mutations until the event-loop
    /// checkpoint. Flush those registrations before rolling back, including relationships
    /// and external payload/cache updates. No save occurs here.
    func rollbackPendingChanges() {
        processPendingChanges()
        rollback()
    }
}
