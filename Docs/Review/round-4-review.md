# Round 4 — reviewer review (for Codex, Round 5)

Codex stopped at its usage limit before writing the Round 4 report. The reviewer verified the tree as left (`2fed9fa`) with no build-setting overrides:

- `swift test`: 76/76.
- `Scripts/verify.sh`: pass, 647 keys, 0 missing.
- `xcodebuild test`:
  - iPhone 17 Pro, iOS 26.4: 22/22 app tests, 9/9 UI tests.
  - iPhone Duo, iOS 27.1: 22/22 app tests, 9/9 UI tests.

R3-1, R3-2, R3-3, and R3-5 are resolved. Write the missing Round 4 milestone report first.

## Findings

- **T1 (Medium) — catalog provenance.**
  - **Problem:** 763 of 814 "sourced" club records cite the same Callaway trade-in rate-card PDF, including PING, Cobra, Tour Edge, and other brands. A trade-in sheet supports that a model *exists*. It does not support the **release year** or the category split.
  - **Fix:**
    - Record the evidence type per field, e.g. `existence` vs. `releaseYear`.
    - Count a record as year-verified only with a manufacturer page, press release, or contemporaneous review.
    - Report both numbers in `Docs/Catalog.md`.
- **T2 (Low) — duplicate model text.** The editor shows the model name twice ("Qi10" under the catalog actions and again under Equipment). Use one source of truth for the selected identity.
- **T3 (Low) — Loft "Unavailable" with an Optional placeholder** reads as contradictory in the editor (`round4-en-light-catalog-editor.png`). Show "Unavailable" only for read-only metrics, not for empty inputs.
- **T4 (Info) — Task D status.** Course geometry, caddie aim search, seeded club tracking, and the localization reachability checker exist in source. Report each against its v7.0 AC.

## Reviewer work while Codex is unavailable (26 Oct – 2 Nov)

All of it is in scope for your review in Round 5 (see `Docs/Prompts/v10.0.md`, Task B).

- **Launch-monitor core.** `Sources/SwingLabCore/LaunchMonitor.swift` and `LaunchMonitorImaging.swift` (flat, because the portable check scripts glob only `Sources/SwingLabCore/*.swift`), with synthetic-frame tests in `Tests/SwingLabCoreTests/LaunchMonitorTests.swift`.
- **Measure launch from a recorded video.** `SwingLab/Services/LaunchVideoAnalyzer.swift`, `SwingLab/Features/FlightSimulation/LaunchMeasureView.swift`.
- **Camera launch mode.** `CameraEngine.setLaunchMode` in `SwingLab/Services/CameraService.swift`: fastest ≥ 200 fps format with a custom 1/2000 s shutter.
- **Live readout.** `Sources/SwingLabCore/LaunchMonitorLive.swift` (`LaunchRegion`, `LaunchPipeline`, `LumaFrame`, `FrameRing`, `StreamingImpactTrigger`, `LiveLaunchSession`), `SwingLab/Services/LiveLaunchCapture.swift`, `CameraEngine.setLiveLaunch`, `SwingLab/Features/Camera/LiveLaunchPanel.swift`, with streamed-shot tests in `Tests/SwingLabCoreTests/LaunchMonitorLiveTests.swift`.
- **T2 and T3 fixed by the reviewer** in `ClubEditorView.swift`: the duplicate model line is gone, and empty inputs no longer carry an "Unavailable" badge. Check that the fix is right; do not redo it.
- **Tests added:** `PersistenceTests.testDeleteAllRemovesEveryRecordAndStoredVideo` (A17) and `CorruptVideoTests` (A20, corrupt video).
