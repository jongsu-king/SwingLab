# SwingLab 1.0 — acceptance scorecard

The reviewer grants the final **PASS** only when every row is ✅ with evidence the reviewer reproduced: a command and its output, a screenshot, a device recording, or a labelled dataset. A claim in a milestone report is not evidence. Codex may propose evidence but does not mark rows ✅.

Legend: ✅ verified · 🟡 implemented, not yet verified to the bar · ❌ missing or failing · ⬜ needs a real iPhone or user data

_Last updated: 30 Oct 2026, reviewer work between Rounds 4 and 5._

## Engineering gates

| # | Gate | Bar | Status | Evidence |
|---|---|---|---|---|
| G1 | iOS build | `xcodebuild … build` 0 errors, 0 warnings (Swift 6) | ✅ | First native build, 26 Oct (`Docs/CompileRisk.md`) |
| G2 | Core tests | `swift test` all pass under XCTest | ✅ | 85/85 on 27 Oct (reviewer); also on every push in GitHub Actions (`core-tests.yml`, Swift 6.3.3) |
| G3 | App tests on simulator | `xcodebuild test` (`SwingLabTests` + `SwingLabUITests`) all pass on iOS 26.4 and 27.1 | ✅ | Reviewer, 27 Oct, no build-setting overrides: iPhone 17 Pro iOS 26.4 and iPhone Duo iOS 27.1 each 40 passed, 0 failed (29 app + 11 UI) on 30 Oct; 4 opt-in tests skipped by design (12-language screenshots, location-denied run) |
| G4 | Project opens and runs from Xcode | Simulator run from Xcode without command-line overrides | ✅ | Reviewer, 30 Oct: opened `SwingLab.xcodeproj` in Xcode 27.1, scheme SwingLab, destination iPhone 17 Pro (iOS 26.4), Product → Run. Xcode reported the run as running and the app's Home screen was on the simulator. |
| G5 | Repository checks | `Scripts/verify.sh` passes | ✅ | Round 4: 647 keys, 0 missing; catalog validator passes (reproduced) |

## Product criteria (v6.0 §34, made measurable)

| # | Criterion | Bar for ✅ | Status |
|---|---|---|---|
| A1 | One-iPhone operation | No feature requires external hardware; verified by code review and device run | 🟡 |
| A2 | Premium native interface | Every primary screen reviewed in light and dark mode and in 12 languages. No v6.0 §4 "strictly avoid" item. No marketing hero on Home. |🟡 |
| A3 | Camera recording | On a real iPhone: every advertised fps is recorded at the actual rate; sound recorded; save, playback, frame-step, and export work | ⬜ |
| A4 | Vision pose detection | On ≥ 10 real full-body clips in good light, pose found in ≥ 80 % of frames | ⬜ |
| A5 | Swing phase analysis | On ≥ 10 hand-labelled real swings at 120 fps or more: median absolute error of address, top, and impact ≤ 20 ms. Audio impact ≤ 5 ms where sound exists. | ⬜ |
| A6 | Tempo analysis | Derived only from markers meeting A5; provenance shown | 🟡 |
| A7 | Coaching feedback | Statements only when the evidence supports them (n ≥ 5, same angle and club); never claims normality from missing data | 🟡 |
| A8 | Swing comparison | Phase-synchronised playback; warnings for angle, handedness, and fps mismatch; verified on device | 🟡 |
| A9 | Practice tracking | Sessions, grouping, consistency (n ≥ 5) | 🟡 |
| A10 | GPS course | On a real course or field: distances to known points agree within the reported GPS accuracy | ⬜ |
| A11 | Shot recording | A full 9-hole round recorded end to end on device, with edits | ⬜ |
| A12 | Club management | Create, edit, delete, and gapping, verified in the UI | ✅ |
| A13 | Landing regions | Statistical regions from user data, math-tested, drawn on the map | 🟡 |
| A14 | Strategy recommendations | Caddie v2 searches aim, accounts for hazards, and is explainable and localized | ❌ |
| A15 | Language selection | 12 languages; the checker fails on any missing key, including keys passed through helpers; screenshots reviewed |✅ |
| A16 | Independent units | Distance, speed, wind, and temperature switch independently everywhere |✅ |
| A17 | Local-first storage | No account; V1→V2→V3 migration tests pass on the simulator; full deletion works | ✅ |
| A18 | Honest provenance | Every displayed number carries a typed origin; spin and ball speed stay Unavailable; audit passes | 🟡 |
| A19 | Device performance | Recording holds the selected fps; analysis of a 10 s 240 fps clip finishes in reasonable time without thermal shutdown | ⬜ |
| A20 | Error handling | Denied permissions, interruptions, low storage, and corrupt video each tested | 🟡 |
| A21 | App Store readiness | Public privacy policy URL, metadata in 12 languages, TestFlight build uploaded (needs a paid developer account) | ❌ |

| A22 | Launch monitor: ball speed | Real-time readout ≤ 2 s after impact. On ≥ 10 real shots recorded alongside a reference launch monitor: within ±3 %. | 🟡 |
| A23 | Launch monitor: launch angle | Same shots: vertical launch within ±1.5°. Spin, club speed, and smash factor stay Unavailable. | 🟡 |
| A24 | Club & shaft catalog (user request) | Brand → category → year → model picker with search; custom entry; shafts (catalog and custom); length in inches; hosel position picker with loft/lie Δ. Every entry sourced or labelled unverified. | 🟡 |

Requested by the user on 26 Oct 2026; specified in `Docs/Specs/LaunchMonitor.md`. Spin RPM stays Unavailable.

Evidence notes (reviewer, 27 Oct):
- **A17 ✅.** No account or sign-in code exists. On both simulators: `SchemaMigrationTests` (V1→V2, V2→V3), `CatalogMigrationTests` (V3→V4→V5), `LaunchShotTests` (V4→V5), and `PersistenceTests.testDeleteAllRemovesEveryRecordAndStoredVideo` (every record type and every stored video removed, library usable afterwards) pass.
- **A20 🟡.** Tested on the simulator:
  - **Corrupt video** (`CorruptVideoTests`): import metadata, pose analysis, and launch measurement each fail with an error.
  - **Location denied** (`PermissionTests`, run with `simctl privacy revoke location`): Course shows how to turn it on.
  - **Camera failure:** the camera shows its error alert and closes cleanly. Screenshots: `Docs/Screenshots/reviewer-2026-10-27/a20-*.jpg`.
  - **Still need a device:** denied camera access (the simulator cannot revoke the camera), interruptions, and low storage.
- **A22/A23 🟡.** Implemented end to end: live readout from the camera (ring buffer, streaming audio trigger, shared measurement pipeline). On a synthetic stream the frames are ready about 0.1 s after the strike and speed/angle are within 2 %/1°. Nothing is verified on a device or against a reference launch monitor.
- **A15 ✅.** 689 keys in 12 languages with 0 missing; the reachability checker passes locally and in GitHub Actions. All 12 languages reviewed on the eight primary screens: en/ko/de light and dark (Round 4), and the other nine in light (`Docs/Review/layout-review-12-languages.md`). Two layout findings (L1, L2) were fixed and re-captured.
- **A12 ✅.** `BagAndUnitsTests.testCreateEditGapAndDeleteClubs` passes on both simulators. It adds two clubs with carries (the gapping chart appears), renames one through Edit, and deletes the other with confirmation. `CatalogEditorTests` covers adding from the catalog.
- **A16 ✅.** `BagAndUnitsTests.testDistanceAndSpeedUnitsSwitchIndependently` passes on both simulators. With distance in m, wind in km/h, and temperature in °F, Hypothetical flight shows each in its own unit while ball speed stays in mph. Code check: no screen hardcodes a unit; every displayed measurement goes through `SLMetricReadout` or the preference's `symbol`, `fromSI`, and `toSI`.
- **A2 🟡.** The eight primary screens are reviewed in light and dark mode in all 12 languages (30 Oct), and the launch log and add-club editor in all 12, light and dark. Five layout findings (L1–L5) are fixed and re-captured, and the v6.0 §4 check is done (`Docs/Review/layout-review-12-languages.md`). Still to do: camera and live readout (need a device), launch measurement, catalog picker, and scorecard.
- **A24 🟡.** T2 (duplicate model line) and T3 ("Unavailable" on empty inputs) fixed by the reviewer. T1 (release-year evidence) is open for Round 5.

Ball tracking beyond the launch window, and spin, are not acceptance criteria for 1.0. They ship only if they pass their own validation (v6.0 §34), and spin RPM stays **Unavailable**.

## What the reviewer needs from the user

- **A3, A4, A5, A19:** an iPhone connected to this Mac, and about 10 recorded swings, some at 240 fps with sound.
- **A22, A23:** about 10 shots filmed face-on at 240 fps beside a reference launch monitor (e.g. TrackMan), with a photo of each shot's readout.
- **A10, A11:** one short session on a course or open field.
- **A21:** an Apple Developer Program account.
