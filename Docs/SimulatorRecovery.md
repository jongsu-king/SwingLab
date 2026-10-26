# iOS 26.4 rollback recovery

The Round 4 baseline on **iPhone 17 Pro, iOS 26.4** reproduced all eight reported app assertions. The analysis JSON survived V1 migration byte for byte (734 bytes), and cached metrics were correct. Failures occurred only after the test removed phase markers, encoded a new 633-byte payload, and called `ModelContext.rollback()`. The retained object's payload and cached tempo stayed edited. Session membership likewise stayed changed even though the deleted empty session was restored. A new course-area Data test reproduced the same retained-value behavior independently of migration.

`processPendingChanges()` before rollback did not correct these failures (see `Logs/round-4/development5-iphone17pro-ios26.4.log`). The assertions were not relaxed to tolerate byte-count differences. The app now captures values before fallible edits and restores them explicitly after aborting the store transaction:

- `AnalysisPersistence.save`: exact original Data plus every cached metric, analysis version and frame rate.
- `PracticeSessionStore.saveChange`: both sides of recording/session membership, session dates, notes and context labels.
- `CourseGeometryStore.replaceAreas`: exact original point/polygon envelope bytes.
- The catalog editor already uses a detached draft and restores the original configuration on save failure.

Migration and regroup tests inject a thrown save error through these production paths. They still assert the exact payload, metric values, original session ID and inverse members, and then verify subsequent edits and independent readers. Restoration is assignment from a snapshot, so it is also safe when iOS 27.1 has already restored the fields. No frozen schema's stored attributes changed for this fix.

Apple's [rollback documentation](https://developer.apple.com/documentation/swiftdata/modelcontext/rollback%28%29) promises restoration; [Apple DTS also reproduced a related relationship rollback failure on iOS 26.4](https://developer.apple.com/forums/thread/820173). Our evidence establishes the described cases, not a general statement about all SwiftData operations. `rollbackPendingChanges()` alone is explicitly documented as insufficient for retained-value restoration on iOS 26.4.

Final full-plan results for **iPhone 17 Pro / iOS 26.4** and **iPhone Duo / iOS 27.1** are recorded in `MilestoneReport.md`. Host-only supplemental checks use macOS SwiftData and are not substitutes for those simulator runs.
