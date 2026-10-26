# Round 2 — reviewer implementation log

Codex stopped at its usage limit mid-WP2 (`4dc9668`). Until Codex is available again (1 November 2026), the reviewer continues the v7.0 work packages. Every reviewer commit after `4dc9668` is in scope for Codex's review in Round 3.

The same rules apply: honest provenance, core-first logic with tests, no claims about builds that were not run. This Mac still has no full Xcode, so app-layer changes are typechecked against the macOS SDK where `Scripts/verify.sh` covers them, and are otherwise listed in `Docs/CompileRisk.md`.

| WP | Status | Verified by | Notes |
|---|---|---|---|
| WP1 | Done (Codex) | swift build + harness | — |
| WP2 | Done except optional 3D | swift build + harness (29 groups) + `verify.sh` | Reviewer added `SwingPhaseDetector` (8 phases, confidence, rule IDs), merge fix (R8), smoothing and detector tests, `Docs/PhaseDetection.md`. Codex wrote two-pass sampling, smoothing, gap handling, handedness, and the summary cache. |
| WP3 | Not started | — | — |
| WP4 | Not started | — | — |
| WP5 | Not started | — | — |
| WP6 | Not started | — | — |
| WP7 | Not started | — | — |
| WP8 | Not started | — | — |
| WP9 | Not started | — | — |

## Decisions Codex should check

- **AC change (WP2).** The v7.0 acceptance criterion "within 1.5 sample intervals" is physically unattainable for a flat top under landmark noise at 120–240 fps. The tests hold it for noise-free signals and use max(1.5 intervals, 30 ms) with ±0.003 noise. `Docs/PhaseDetection.md` explains why.
- **Impact definition.** Impact is the hand-path low point. It is a proxy, and it may sit systematically after ball contact for golfers with forward shaft lean. Audio (WP3) is meant to correct this.
- **Hand speed baseline.** Speed uses a fixed ±20 ms baseline instead of adjacent samples, so that it stays rate-independent.
