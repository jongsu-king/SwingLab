# Round 1 response — before Round 2 implementation

Evidence below refers to the unchanged Round 1 source inspected on 26 October 2026. Later edits can move these lines. Gate 0 returned `/Library/Developer/CommandLineTools`; `xcodebuild` requires full Xcode and `simctl` is unavailable. Round 2 uses the verified-core-first policy; source parsing is not an iOS build.

| Finding | Response | Evidence and planned correction |
|---|---|---|
| R1 | **Partially** | `Docs/MilestoneReport.md` D–F explicitly records no iOS compilation. Today's Gate 0 reproduces that limitation. However, “nothing in SwingLab compiled” is too broad: `Scripts/check_capture.sh:16–18` compiles actual media service source against macOS, and `check_course.sh:16–18` checks location/course services. That does not validate SwiftData macros, SwiftUI, or capture delegates on iOS. Keep native edits narrow and maintain `Docs/CompileRisk.md`. |
| R2 | **Partially** | `PoseEstimationService.swift:40` caps analysis at 30 Hz. Dense offline sampling is needed. High-fps capture is not entirely wasted: original frames remain available to playback and manual frame stepping (`SwingDetailView.swift:65–75`). The stated ±33 ms is not a validated error bound: quantization and detector bias are different errors. |
| R3 | **Agree** | `PoseEstimationService.swift:63–71` updates each joint from the previous filtered frame using a 45 ms causal exponential. This adds offline phase lag. Move time-aware, symmetric smoothing into Core and test peak timing at four frame rates. |
| R4 | **Partially** | `PoseEstimationService.swift:140–174` estimates only address/top/impact and lacks confidence/handedness. However onset uses both wrist x and y, and impact uses downward velocity; it is not solely mean height. Averaging both wrists is left/right invariant, so the specific assertion that left-handed golfers receive mirrored logic is not demonstrated. Explicit lead/trail selection is still needed for future directional rules. |
| R5 | **Agree** | `CameraService.swift:58–74` configures video input only. Preserve video-only capture if audio permission is denied. Audio transients are useful evidence, but without acoustic ground truth they cannot establish that a particular golfer hit a ball; reject ambiguous peaks and document sync/distance limitations. |
| R6 | **Agree** | `SwingRecording.swift:33–39` decodes the external JSON for each analysis/tempo read; `PerformanceView.swift` builds snapshots by reading that payload. Add stored summaries with an explicit, tested versioned migration; list/chart reads must avoid decoding pose. |
| R7 | **Agree** | `SwingRecording.swift:13–14,73,108–110` uses strings for metadata and provenance. Introduce stable Core enums, legacy decoding, a typed numeric value, and shared badges/readouts. Keep legacy store columns compatible until the schema migration. |
| R8 | **Agree** | `SwingDetailView.swift:232–234` replaces every new estimate when even one manual marker exists. Merge by phase, manual wins; reject conflicting inferred chronology rather than moving a manual marker. |
| R9 | **Partially** | `ClubRecommendation.swift:26–29` already incorporates lateral mean and both carry/lateral variances, so “carry vs. target distance only” is inaccurate. It does lack total-distance profiles, hazard geometry, aim search, and supported wind/elevation inputs. These remain WP6 scope. |
| R10 | **Agree** | The polygon integration is tested in Core but there is no course polygon editor/import path. Existing manual point references cannot establish hazard area probabilities. Keep probabilities unavailable until actual geometry exists. |
| R11 | **Partially** | `Theme.swift:24–48` already defines `SLEmptyState` and `SLSectionHeader`; the design system is not colors only. There is no shared spacing/type scale. `HomeView.swift:13–27` is a marketing hero, which v7 explicitly removes. v6 §5 rejects generic banners, not that exact quoted sentence; the product direction is nevertheless clear. |
| R12 | **Partially** | Dynamic keys and concatenated counts (`HomeView.swift:64`) prevent complete static verification and correct plurals. English source keys themselves are valid localization keys and are not inherently defective. `build_localizations.py` does inspect literal branches and sentence-like strings, but that heuristic does not prove dynamic coverage. Replace dynamic dispatch with auditable typed helpers and full format strings. |
| R13 | **Agree** | No `PracticeSession` model or baseline/statistical engine exists. `SwingComparisonView.swift` has a two-recording duration observation, which is limited feedback, not consistency or personalized baseline coaching. Implement a minimum-sample rule and same-club/angle baseline before statements. |
| R14 | **Partially** | `CameraService.swift:87–103` sorts display choices deterministically by dimensions/fps, but deduplicates formats in device order, retaining the first variant. The underlying variant selection is indeed not deliberate. Binning/HDR impact has not been measured; document a capability-based tie-break and leave physical quality claims unverified. |

## Implementation results

WP1: typed Core values, legacy wire decoding, metadata normalization and metric presentation are implemented. `Scripts/verify.sh` passed with 20 portable Core test groups; native build remains unverified. See the Round 2 milestone report for executed commands and limitations.

## Feedback for the reviewer

To be completed at the final work-package boundary of this execution.
