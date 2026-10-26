# Round 1 — Independent Review

Reviewed commit: `round-1` (master prompt v6.0). Reviewer read the source; nothing was compiled for iOS because the Mac has no full Xcode.

Codex: respond to each finding in `Docs/Review/round-1-response.md` — **Agree / Disagree / Partially**, with evidence (file:line, test, or measurement). Push back where the reviewer is wrong; the next prompt will be adjusted accordingly.

## What is good — keep it

- Honest provenance language throughout; no fabricated measurements, no sample data on first launch.
- SI storage with conversion only at the boundaries; tests for units, geodesics, chi-square(2) regions, timing.
- Offline pose analysis decoupled from capture; cancellation, thermal stop, progress.
- Staged deletion and interrupted-deletion recovery.
- Pure-Swift `SwingLabCore` package that builds and runs tests without Xcode. This is the most valuable structural decision of the round.
- The milestone report did not overclaim.

## Findings

| # | Severity | Where | Finding |
|---|----------|-------|---------|
| R1 | Blocker | whole app | Nothing in `SwingLab/` has been compiled. Swift 6 `complete` strict concurrency + SwiftData macros + AVFoundation delegates make a clean first build unlikely. Each round that adds unbuilt UI code compounds the risk. |
| R2 | High | `Services/PoseEstimationService.swift:40` | Pose sampling is capped at 30 Hz even for 120/240 fps clips. A downswing lasts ~0.25–0.30 s → ~8 samples; impact timing error up to ±33 ms; tempo ratio resolution is poor. The high-fps capture work is wasted. |
| R3 | High | `Services/PoseEstimationService.swift:63-71` | Causal exponential smoothing (τ = 45 ms) is applied during offline analysis. It lags the signal, so peak-based markers (top, impact) shift later. Offline data should use zero-phase smoothing. |
| R4 | High | `Services/PoseEstimationService.swift:140-171` | Only address/top/impact are estimated; no per-marker confidence; no handedness (left-handed golfers get mirrored logic); uses mean wrist height only. |
| R5 | High | `Services/CameraService.swift` | No audio input. The impact sound is the strongest single-iPhone impact signal available and it is discarded. |
| R6 | Medium | `Core/Models/SwingRecording.swift:33-39` | `analysis` decodes the full pose JSON on every access; `tempoRatio` is used in lists/charts → full decode per row per render. Cache summary metrics as stored attributes. |
| R7 | Medium | `SwingRecording.swift:73`, `SwingDetailView.swift:108,232` | Provenance, source, and camera angle are free strings (`"Estimated"`, `"User-entered"`, `"Face-on"`). v6.0 §2 requires six explicit categories; nothing enforces them. |
| R8 | Medium | `Features/Swing/SwingDetailView.swift:232-234` | Re-analysis with any manual marker replaces *all* markers with the manual ones, discarding new estimates for phases the user never set. Should merge per phase (manual wins). |
| R9 | Medium | `Sources/SwingLabCore/ClubRecommendation.swift:21-31` | Ranking uses carry vs. target distance only. Ignores carry vs. total, wind, elevation, hazards, and aim offset. The caddie cannot yet answer "where should I aim?". |
| R10 | Medium | Course | No way to supply hazard geometry, so the existing polygon integration (`Dispersion.swift:40-52`) is never used. Needs user-drawn polygons and/or a legally licensed source (OpenStreetMap, ODbL). |
| R11 | Medium | `Core/DesignSystem/Theme.swift`, `Features/Home/HomeView.swift:13-27` | Design system is colors only — no type scale, spacing, or shared components. Home opens with a marketing hero ("A better game, one swing at a time."), which v6.0 §5 explicitly rejects. |
| R12 | Medium | `Core/Localization/AppPreferences.swift:34-39`, `HomeView.swift:64` | English sentences as runtime keys; dynamic keys (`prefs.text(error ?? "")`, `prefs.text(recording.source)`) cannot be statically verified. String concatenation like `"\(n) / \(m) " + "holes scored"` breaks word order in ko/ja/th and has no plural handling. |
| R13 | Medium | — | No `PracticeSession`, consistency statistics, or coaching rule engine (v6.0 Phase 4). |
| R14 | Low | `Services/CameraService.swift:78-80` | Preferred format is the first 1920-wide 60 fps match in `device.formats` order, which may pick a binned/HDR variant. Prefer a deterministic, documented choice. |

## Priority for round 2

1. Get to a verifiable state (build gate if Xcode exists; otherwise move logic into `SwingLabCore`, where it can be verified).
2. Make the core measurement trustworthy: typed provenance, dense sampling, zero-phase smoothing, an 8-phase detector with confidence, and audio impact.
3. Practice sessions, consistency, and grounded coaching.
4. Physics engine, course geometry, and hazard-aware caddie: all core-first, all tested.
5. Design system and a data-first Home.
