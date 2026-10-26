# SwingLab 1.0 — acceptance scorecard

The reviewer grants the final **PASS** only when every row is ✅ with evidence the reviewer reproduced: a command and its output, a screenshot, a device recording, or a labelled dataset. A claim in a milestone report is not evidence. Codex may propose evidence but does not mark rows ✅.

Legend: ✅ verified · 🟡 implemented, not yet verified to the bar · ❌ missing or failing · ⬜ needs a real iPhone or user data

_Last updated: 26 Oct 2026, during Round 3._

## Engineering gates

| # | Gate | Bar | Status | Evidence |
|---|---|---|---|---|
| G1 | iOS build | `xcodebuild … build` 0 errors, 0 warnings (Swift 6) | ✅ | First native build, 26 Oct (`Docs/CompileRisk.md`) |
| G2 | Core tests | `swift test` all pass under XCTest | ✅ | 47/47, 26 Oct |
| G3 | App tests on simulator | `xcodebuild test` (`SwingLabTests` + `SwingLabUITests`) all pass | ⬜ | First run in progress (Round 3) |
| G4 | Project opens and runs from Xcode | Simulator run from Xcode without command-line overrides | ❌ | Generated project lacks Debug `ONLY_ACTIVE_ARCH=YES` |
| G5 | Repository checks | `Scripts/verify.sh` passes | ✅ | 26 Oct |

## Product criteria (v6.0 §34, made measurable)

| # | Criterion | Bar for ✅ | Status |
|---|---|---|---|
| A1 | One-iPhone operation | No feature requires external hardware; verified by code review and device run | 🟡 |
| A2 | Premium native interface | Every primary screen reviewed in light and dark mode and in 12 languages. No v6.0 §4 "strictly avoid" item. No marketing hero on Home. | ❌ |
| A3 | Camera recording | On a real iPhone: every advertised fps is recorded at the actual rate; sound recorded; save, playback, frame-step, and export work | ⬜ |
| A4 | Vision pose detection | On ≥ 10 real full-body clips in good light, pose found in ≥ 80 % of frames | ⬜ |
| A5 | Swing phase analysis | On ≥ 10 hand-labelled real swings at 120 fps or more: median absolute error of address, top, and impact ≤ 20 ms. Audio impact ≤ 5 ms where sound exists. | ⬜ |
| A6 | Tempo analysis | Derived only from markers meeting A5; provenance shown | 🟡 |
| A7 | Coaching feedback | Statements only when the evidence supports them (n ≥ 5, same angle and club); never claims normality from missing data | 🟡 |
| A8 | Swing comparison | Phase-synchronised playback; warnings for angle, handedness, and fps mismatch; verified on device | 🟡 |
| A9 | Practice tracking | Sessions, grouping, consistency (n ≥ 5) | ❌ |
| A10 | GPS course | On a real course or field: distances to known points agree within the reported GPS accuracy | ⬜ |
| A11 | Shot recording | A full 9-hole round recorded end to end on device, with edits | ⬜ |
| A12 | Club management | Create, edit, delete, and gapping, verified in the UI | 🟡 |
| A13 | Landing regions | Statistical regions from user data, math-tested, drawn on the map | 🟡 |
| A14 | Strategy recommendations | Caddie v2 searches aim, accounts for hazards, and is explainable and localized | ❌ |
| A15 | Language selection | 12 languages; the checker fails on any missing key, including keys passed through helpers; screenshots reviewed | 🟡 |
| A16 | Independent units | Distance, speed, wind, and temperature switch independently everywhere | 🟡 |
| A17 | Local-first storage | No account; V1→V2→V3 migration tests pass on the simulator; full deletion works | ⬜ |
| A18 | Honest provenance | Every displayed number carries a typed origin; spin and ball speed stay Unavailable; audit passes | 🟡 |
| A19 | Device performance | Recording holds the selected fps; analysis of a 10 s 240 fps clip finishes in reasonable time without thermal shutdown | ⬜ |
| A20 | Error handling | Denied permissions, interruptions, low storage, and corrupt video each tested | 🟡 |
| A21 | App Store readiness | Public privacy policy URL, metadata in 12 languages, TestFlight build uploaded (needs a paid developer account) | ❌ |

Ball tracking and spin are not acceptance criteria for 1.0. They ship only if they pass their own validation (v6.0 §34), and spin RPM stays **Unavailable**.

## What the reviewer needs from the user

- **A3, A4, A5, A19:** an iPhone connected to this Mac, and about 10 recorded swings, some at 240 fps with sound.
- **A10, A11:** one short session on a course or open field.
- **A21:** an Apple Developer Program account.
