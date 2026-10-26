# Round 3 — reviewer corrections, native verification, and WP4

This is a **partial v7 delivery at the WP4 boundary**. The reviewer review and all demonstrated High findings are handled. Practice sessions are implemented and migrated. WP6–WP9 remain unstarted; no completion of those packages is claimed. All changes remain in the working tree. No commit, push, tag, reset, checkout, stash, or branch change was performed; `Docs/Prompts/` is unchanged.

## A. Completed functionality

- Reviewed every commit after `4dc9668` through `901da63`. [Round 2 review](Review/round-2-review.md) contains numbered severities, concrete scenarios, fixes, seven explicit decision responses, and feedback for the reviewer. An unproven audio-gap hypothesis is explicitly marked **not demonstrated**, with no speculative production change.
- Fixed mixed-cadence phase detection losing address/finish, long wrist-dropout edges becoming impact, audio choosing the loudest rather than nearest qualifying pose candidate, unsupported all-metrics coaching claims, and unavailable recordings evicting analyzed baselines.
- Fixed immediate-ground flight launches, invalid custom coefficients, SI landing-angle metrics, and stale flight results. Retained the experimental aerodynamic model without fitting TrackMan validation data; corrected the historical reference landing angle and documented a better primary-source model family and its limits.
- Added frozen V2 model snapshots, `SwingLabSchemaV3`, `PracticeSession`, optional recording club IDs, rolling 90-minute grouping, explicit regrouping, session notes/context, and same-club/known-angle consistency (n, mean, sample SD, CV; n ≥ 5 only). Deletion/rollback and annotated empty sessions retain data correctly.
- Ran real iOS-hosted XCTest for the first time, including V1→V2, V1→V3, V2→V3, and practice-session persistence. Fixed UI tests for the actual iPhone Duo navigation rail.
- Added reproducible screenshot capture/export and macOS SwiftData migration checks. Screenshot QA corrected primary-button contrast, the truncated German angle control, and the missing Measured badge in all 12 locales. The general localization checker gap remains WP8.

## B. Changed files

- `Docs/Acceptance.md`
- `Docs/Capture.md`
- `Docs/Coaching.md`
- `Docs/DesignAudit.md`
- `Docs/MilestoneReport.md`
- `Docs/PhaseDetection.md`
- `Docs/Physics.md`
- `Docs/PracticeSessions.md`
- `Docs/Review/round-2-review.md`
- `Docs/Rounds/round-3.md`
- `Scripts/Localization-practice.json`
- `Scripts/Localization-round3-review.json`
- `Scripts/MigrationTestHarness.swift`
- `Scripts/PortableTestHarness.swift`
- `Scripts/capture_screenshots.sh`
- `Scripts/check_migrations.sh`
- `Scripts/verify.sh`
- `Sources/SwingLabCore/BallFlight.swift`
- `Sources/SwingLabCore/Coaching.swift`
- `Sources/SwingLabCore/ImpactOnsetDetector.swift`
- `Sources/SwingLabCore/PracticeGrouping.swift`
- `Sources/SwingLabCore/SwingPhaseDetector.swift`
- `SwingLab.xcodeproj/project.pbxproj`
- `SwingLab/App/OnboardingView.swift`
- `SwingLab/App/SwingLabApp.swift`
- `SwingLab/Core/Models/PracticeSession.swift`
- `SwingLab/Core/Models/SwingRecording.swift`
- `SwingLab/Core/Persistence/LocalDataController.swift`
- `SwingLab/Core/Persistence/PracticeSessionStore.swift`
- `SwingLab/Core/Persistence/Schema.swift`
- `SwingLab/Core/Persistence/SchemaV2.swift`
- `SwingLab/Features/Camera/CameraView.swift`
- `SwingLab/Features/CourseManager/CourseView.swift`
- `SwingLab/Features/FlightSimulation/HypotheticalFlightView.swift`
- `SwingLab/Features/Home/HomeView.swift`
- `SwingLab/Features/MyBag/BagView.swift`
- `SwingLab/Features/Performance/PerformanceView.swift`
- `SwingLab/Features/Swing/PracticeSessionViews.swift`
- `SwingLab/Features/Swing/SwingDetailView.swift`
- `SwingLab/Features/Swing/SwingView.swift`
- `SwingLab/Resources/Localizable.xcstrings`
- `SwingLabTests/PracticeSessionTests.swift`
- `SwingLabTests/SchemaMigrationTests.swift`
- `SwingLabUITests/NavigationTests.swift`
- `SwingLabUITests/ScreenshotTests.swift`
- `Tests/SwingLabCoreTests/BallFlightTests.swift`
- `Tests/SwingLabCoreTests/CoachingTests.swift`
- `Tests/SwingLabCoreTests/ImpactOnsetTests.swift`
- `Tests/SwingLabCoreTests/PhaseDetectionTests.swift`
- `Tests/SwingLabCoreTests/PracticeGroupingTests.swift`

Actual screenshots and their evidence manifest are listed below. Command logs are under `Docs/Logs/` and `Docs/Logs/round-3/`; build products remain in ignored `DerivedData/` and `.build/`.

## C. Implementation details

Phase detection uses local cadence and continuity segments across the real coarse/dense splice. An impact proxy requires a contiguous local extremum. Audio retains comparable-peak ambiguity rejection and uses the candidate nearest pose timing; its engineering thresholds are not calibrated contact probabilities.

V2 is frozen independently of the mutable current models. The V1→V2 stage fetches the frozen type and builds cached metrics once. V2→V3 preserves payload/cache bytes and adds associations. Stable club UUIDs preserve baseline identity across club renaming. New recordings snapshot handedness; historical unknowns remain unknown. Auto-grouping uses an inclusive 90-minute inactivity window partitioned by club, camera angle, and handedness. Manual regrouping preserves recording labels. Session dates derive from members, and notes survive empty-session cleanup. See [Practice sessions](PracticeSessions.md) and [Coaching](Coaching.md).

Session/list statistics read cached columns, not pose JSON. Aggregate values are labeled estimated and carry n. Unknown camera angles cannot establish a comparable baseline. Missing or constant baselines never imply normality.

No new permission was added in Round 3. Microphone permission was already introduced by the reviewer. On-device analysis and local media storage remain intact. Screenshot fixtures are DEBUG-only, in-memory, and contain no fabricated analysis.

## D. Build results and exact commands

Final verification details are appended after the last screenshot correction and gate. Earlier real evidence is preserved in `Docs/Logs/round-3/wp4-app-build.log`, `Docs/Logs/round3-wp4-native-gate.log`, and `Docs/Logs/round-3/wp4-verify-final.log`.

Environment: Xcode 27.1 (`27A9275`), iOS 27.1 SDK; runtime iOS 27.1 (`24A94425`) appeared during this run. Its supported-device inventory permits only iPhone Duo, arm64. Creating iPhone 18 Pro returned `Incompatible device`; no standard-phone screenshot is claimed.

An overlapping early Xcode invocation hit a build-database lock; subsequent builds were serialized. A native test attempt encountered mixed simulator architecture artifacts; device test/capture commands specify arm64 and `ONLY_ACTIVE_ARCH=YES`. The exact generic build subsequently succeeded without an architecture override. No compiler warning was suppressed. Xcode emitted AppIntents metadata and runtime-build-number diagnostics; the report does not claim literal zero warnings.

## E. Tests and screenshots

Final automated evidence is listed in D. There are **48 actual screenshots** (8 screens × English/Korean/German × light/dark), with per-image evidence in [the manifest](Screenshots/round-3/manifest.json). The driver example was entered by tapping the real button, followed by Simulate.

| Screen | English light | English dark | Korean light | Korean dark | German light | German dark |
|---|---|---|---|---|---|---|
| home | [en light](Screenshots/round-3/round3-en-light-home.png) | [en dark](Screenshots/round-3/round3-en-dark-home.png) | [ko light](Screenshots/round-3/round3-ko-light-home.png) | [ko dark](Screenshots/round-3/round3-ko-dark-home.png) | [de light](Screenshots/round-3/round3-de-light-home.png) | [de dark](Screenshots/round-3/round3-de-dark-home.png) |
| swing | [en light](Screenshots/round-3/round3-en-light-swing.png) | [en dark](Screenshots/round-3/round3-en-dark-swing.png) | [ko light](Screenshots/round-3/round3-ko-light-swing.png) | [ko dark](Screenshots/round-3/round3-ko-dark-swing.png) | [de light](Screenshots/round-3/round3-de-light-swing.png) | [de dark](Screenshots/round-3/round3-de-dark-swing.png) |
| swing-detail-empty | [en light](Screenshots/round-3/round3-en-light-swing-detail-empty.png) | [en dark](Screenshots/round-3/round3-en-dark-swing-detail-empty.png) | [ko light](Screenshots/round-3/round3-ko-light-swing-detail-empty.png) | [ko dark](Screenshots/round-3/round3-ko-dark-swing-detail-empty.png) | [de light](Screenshots/round-3/round3-de-light-swing-detail-empty.png) | [de dark](Screenshots/round-3/round3-de-dark-swing-detail-empty.png) |
| flight | [en light](Screenshots/round-3/round3-en-light-flight.png) | [en dark](Screenshots/round-3/round3-en-dark-flight.png) | [ko light](Screenshots/round-3/round3-ko-light-flight.png) | [ko dark](Screenshots/round-3/round3-ko-dark-flight.png) | [de light](Screenshots/round-3/round3-de-light-flight.png) | [de dark](Screenshots/round-3/round3-de-dark-flight.png) |
| course | [en light](Screenshots/round-3/round3-en-light-course.png) | [en dark](Screenshots/round-3/round3-en-dark-course.png) | [ko light](Screenshots/round-3/round3-ko-light-course.png) | [ko dark](Screenshots/round-3/round3-ko-dark-course.png) | [de light](Screenshots/round-3/round3-de-light-course.png) | [de dark](Screenshots/round-3/round3-de-dark-course.png) |
| performance | [en light](Screenshots/round-3/round3-en-light-performance.png) | [en dark](Screenshots/round-3/round3-en-dark-performance.png) | [ko light](Screenshots/round-3/round3-ko-light-performance.png) | [ko dark](Screenshots/round-3/round3-ko-dark-performance.png) | [de light](Screenshots/round-3/round3-de-light-performance.png) | [de dark](Screenshots/round-3/round3-de-dark-performance.png) |
| settings | [en light](Screenshots/round-3/round3-en-light-settings.png) | [en dark](Screenshots/round-3/round3-en-dark-settings.png) | [ko light](Screenshots/round-3/round3-ko-light-settings.png) | [ko dark](Screenshots/round-3/round3-ko-dark-settings.png) | [de light](Screenshots/round-3/round3-de-light-settings.png) | [de dark](Screenshots/round-3/round3-de-dark-settings.png) |
| bag | [en light](Screenshots/round-3/round3-en-light-bag.png) | [en dark](Screenshots/round-3/round3-en-dark-bag.png) | [ko light](Screenshots/round-3/round3-ko-light-bag.png) | [ko dark](Screenshots/round-3/round3-ko-dark-bag.png) | [de light](Screenshots/round-3/round3-de-light-bag.png) | [de dark](Screenshots/round-3/round3-de-dark-bag.png) |

See [the screenshot review](DesignAudit.md) and [capture notes](Screenshots/round-3/README.md). The macOS harness supplements the real iOS tests and does not substitute for them. An independent store seeded from untouched original V2 declarations also migrated successfully, validating frozen-schema checksum compatibility.

## F. Current limitations and WP status

| WP | Status | Verified by | Remaining gap |
|---|---|---|---|
| WP1 | Done (carried forward) | Core legacy JSON/provenance tests; native migrations | General source localization integrity is WP8. |
| WP2 | Partial | Core synthetic uniform/mixed cadence and gap tests; native build | Original noisy ±1.5-interval AC is not met; disclosed 30 ms engineering floor is not real-swing validation. Optional 3D absent. |
| WP3 | Partial | Core click/noise tests; native AAC/LPCM fixture; iOS build | Physical camera A/V sync, capture channel/codec guarantee, and thresholds remain unverified. |
| WP4 | Done | Core statistics/grouping; iOS migration/session tests; macOS disk supplement | Coaching thresholds and drills remain uncalibrated on real golfers. |
| WP5 | Partial | Vacuum/reference/symmetry/wind tests; real simulated-flight UI captures | Primary coefficients still unverified; omitted Reynolds dependence and documented apex/iron errors. |
| WP6 | Not started | None | Geometry editor/import, hazard probabilities, caddie aim search. |
| WP7 | Not started | Screenshot audit only | Tokens, data-first Home, outdoor contrast option, hero removal, full radius/spacing audit. |
| WP8 | Not started | Existing builder only; one observed badge gap fixed manually | Complete source reachability/dynamic-call checking and plural variants absent. |
| WP9 | Not started | None | Seeded club/ball tracking, Kalman/gating/line fit, tracer/export. |

There is no physical iPhone validation, real swing/audio ground truth, validated contact accuracy, or App Store/signing work. Simulator screenshots cover empty states and explicit hypothetical inputs; they do not establish camera performance, on-course GPS accuracy, or trained ball/club detection. The screenshot audit retains known WP7 design debt rather than calling the whole UI finished.

## G. Next milestone

WP6 is next in the requested order: user-drawn course geometry, an OSM/ODbL fixture parser and failure-tolerant import, probabilities only over supplied geometry, and caddie club/aim search with honest carry-versus-total uncertainty. Then WP7, WP8, and WP9. Preserve the green native/test/verification gates and frozen historical schemas.
