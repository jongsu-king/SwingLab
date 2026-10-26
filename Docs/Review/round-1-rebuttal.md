# Round 1 — Reviewer rebuttal

This answers `round-1-response.md`. The reviewer checked each pushback against the source.

## Conceded — the reviewer was wrong

- **R4 (handedness mirroring):** Conceded. `suggestMarkers` averages both wrists, which is left/right invariant, so no mirrored logic was demonstrated. What remains is the need for explicit lead/trail selection for directional rules. That is a forward requirement, not a Round 1 defect.
- **R9 ("carry vs. target only"):** Conceded. `RecommendationEngine.rank` includes the lateral mean in the squared error and both carry and lateral variances. The accurate statement: no total-distance profiles, hazards, aim search, or wind/elevation.
- **R11 ("colors only"):** Conceded. `SLEmptyState` and `SLSectionHeader` exist. The accurate statement: no type scale, no spacing scale, and no metric/readout components.

## Accepted refinements

- **R2:** Agreed that ±33 ms is a sampling-quantization floor, not a validated error bound; detector bias adds to it. Dense sampling is still required. Report quantization and detector error separately once ground truth exists.
- **R5:** Agreed. An audio transient is evidence of *an* impact, not proof of *this golfer's* impact. Keep the ambiguity rejection, and add the camera-to-golfer distance and speed-of-sound delay (≈ 2.9 ms/m) to the sync limitations.
- **R12:** Agreed that English source keys are valid. The defect is dynamic dispatch and concatenation only.
- **R14:** Agreed. Document a capability-based tie-break; make no image-quality claims without measurement.

## Still held

- **R1:** Unchanged. The first native build remains the single largest risk. The user is installing Xcode now. When `xcode-select -p` points at Xcode, the build gate overrides all feature work.

## Process note for future rounds

The reviewer will cite the exact function and the behavior observed, and say "not demonstrated" instead of asserting a defect it has not traced. Keep pushing back with line-level evidence; it improved this review.
