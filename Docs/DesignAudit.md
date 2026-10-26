# Round 3 screenshot audit — WP4 boundary

This is the Task B visual audit, not completion of WP7. Real screenshots cover eight screens in English, Korean, and German, each in light and dark appearance. See the [48-image list and capture manifest](Screenshots/round-3/README.md). The installed iOS 27.1 runtime supports only iPhone Duo/arm64; it rejected an iPhone 18 Pro device as incompatible. The vertical navigation rail and its native glass treatment are operating-system chrome, not a custom decorative dashboard.

## Corrections from actual screenshots

- **Primary-button contrast:** dark Home, Swing, Course, Performance, and My Bag used white labels on Sage. Source-color contrast was only **1.80:1**. All 14 prominent-button sites now set the adaptive background color as their foreground: dark ink on Sage (**9.51:1**) and Chalk on Forest (**7.36:1**). The final dark screenshots visibly confirm the correction; the ratios describe the source colors, not an exhaustive accessibility certification.
- **German camera angle:** swing detail's segmented picker truncated the down-the-line label. It now uses a native menu, and the selected value fits in the final capture. The expanded menu itself was not part of this screenshot matrix.
- **Missing provenance translation:** Korean and German empty detail displayed English “Measured.” The key comes from Core and was completely absent from the catalog. Added real translations in all 12 languages. The targeted detail UI test checks for the localized badge before taking its screenshot. This fixes the visible key, not the outstanding WP8 extraction/checker requirement.

## Screen review against v6 §4

| Screen | Observed result | Remaining work |
|---|---|---|
| Home | Primary recording action is visible; real empty state, no invented metrics or charts; corrected dark button contrast. | Marketing hero remains. WP7 must replace it with the specified data-first Home. The custom first-recording panel still has radius 12, above WP7's token limit. |
| Swing | Clear record/import actions, actual empty library, four primary destinations; no fabricated analysis. | Promotional heading and native grouped containers remain for WP7 review. No new decorative card grid was added. |
| Swing detail, empty | Missing video is explicit; analysis remains absent, controls for unavailable playback are disabled. Camera-angle menu avoids German truncation; provenance is localized. | A visible camera-angle field label would improve the menu row; its accessibility label is present. A nonempty analyzed recording, live video, and large Dynamic Type still need visual QA. The test fixture has no video or analysis and exists only in a DEBUG in-memory launch. |
| Hypothetical flight | Result values carry simulated badges; both charts are dashed; real driver-example action and simulation are exercised. German decimal commas and Korean labels render correctly. | The model remains experimental; screenshot QA does not validate physical flight accuracy. Input keyboard editing and very large text sizes were not covered by this matrix. |
| Course | Map remains the main content, target distance is unavailable until supplied, no invented hazard probability. Map attribution is visible. | WP6 geometry and hazard-aware aim search remain unimplemented. GPS accuracy requires device testing. |
| Performance | Explicit empty practice state and a real navigation action; no fake trend or score. Corrected dark action contrast. | Populated session consistency is verified in Core/native persistence tests, not in these empty-state screenshots. |
| Settings | Language and independent units are visible. The longer German speed label wraps without overlap. Korean text and controls are readable. | Outdoor high contrast belongs to WP7; other languages, screen sizes, and large accessibility fonts remain unreviewed. |
| My Bag | Actual empty state with add-club action; corrected dark button contrast; German and Korean text fit. | Populated editor/club charts and larger text settings need their own visual pass. |

No neon gradient, robot illustration, emoji navigation, fabricated chart, unsupported score, or extra primary tab appears in this matrix. The remaining marketing hero and token work are explicit WP7 gaps; the screenshots do not justify marking that work package done.
