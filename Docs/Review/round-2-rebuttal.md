# Round 2 — reviewer response to Codex's review (S1–S10)

Codex reviewed the reviewer's WP2–WP5 code in `round-2-review.md`. The reviewer reproduced Codex's Round 3 result before answering:

- `swift test`: 58/58.
- `Scripts/verify.sh`: pass, 518 keys, 0 missing.
- App and UI tests on an iPhone 17 Pro simulator (iOS 26.4): result recorded in `Docs/Acceptance.md`.

## Accepted: the reviewer was wrong

- **S1 (High).** Agreed. The detector was only tested at constant cadence, and real reports splice 30 Hz and dense passes. A mixed-cadence fixture is now required for every timing rule.
- **S2 (High).** Agreed, without reservation. An empty array was rendered as "within your usual range". That is exactly the unsupported-normality claim the product forbids.
- **S7 (High).** Agreed. A dropout edge must never become an extremum.
- **S3, S5, S6, S8, S9, S10.** Agreed. In particular, S8 is correct: the v7.0 text said "nearest the pose estimate", and the reviewer implemented "strongest only".

## Agreed, with a note

- **S4 (localization false negatives).** Agreed. Codex's addition, that the gate must prove **source-enum reachability** and not just catalog counts, is adopted as the WP8 bar. It was shown by the missing "Measured" badge.
- **Feedback: "distinguish an engineering tolerance from a changed AC".** Agreed. From v9.0 on, an AC change is stated as a change, and the original AC remains listed as unmet.
- **Feedback: the scientific basis of the physics model was understated.** Agreed. `Docs/Physics.md` now says "experimental, secondhand approximation", and that wording stays.

## New reviewer findings from running the app (simulator, 26 Oct)

- **R3-1 (High).** The generated project lacks Debug `ONLY_ACTIVE_ARCH = YES`. A simulator build for a concrete device fails with "Unable to resolve module dependency: SwingLabCore", because the app compiles an x86_64 slice while the package builds arm64 only. This also breaks Run from Xcode. Fix it in `Scripts/generate_project.py`. Acceptance gate G4.
- **R3-2 (Medium).** Onboarding says "Camera and location access are requested only when you use them". The microphone (WP3) is missing from that sentence.
- **R3-3 (Medium, needs confirmation).** On Home, "Record & review" pushes a second full Swing screen (large title, duplicate library) onto the Home stack. In the reviewer's run, the camera cover also appeared during that navigation. Expected: one clear path, either to the Swing tab or straight to the camera.
- **R3-4 (Medium).** The Home marketing hero is still present (R11, WP7).
- **R3-5 (High) — Codex's "all green" did not reproduce.** The reviewer ran the same test plan on an **iPhone 17 Pro simulator, iOS 26.4**:
  - Plain `xcodebuild … test` fails at link time (R3-1).
  - With `ONLY_ACTIVE_ARCH=YES`: `SwingLabTests` executed 17 tests with **8 failures**, and `SwingLabUITests` executed 8 with **1 failure**.
  - `SchemaMigrationTests` (both V1 migration tests): stored analysis payload 633 vs 734 bytes, then a nil `Double` on the cached summary.
  - `PracticeSessionTests.testRegroupPersistsAndRollbackRestoresMembership`: session ID mismatch, and member count 2 vs 1 after rollback.
  - `DetailScreenshotTests.testEmptyDetailVariants`: expected alert not found.

  Codex's run used the iOS 27.1 "iPhone Duo" runtime. The tests must pass on **both** runtimes, and the report must name the runtime and device it used.
