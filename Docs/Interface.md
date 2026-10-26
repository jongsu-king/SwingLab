# Home, bag, performance, and settings

Implemented as native SwiftUI views using the shared semantic colors, app preferences, SwiftData container, and Swift Charts. No placeholder statistics are seeded.

- Home leads to recording/review, course planning, My Bag, and Settings. Recent practice and round summaries are queries of saved records.
- My Bag supports creating, editing, and deleting clubs. A detached draft prevents partially typed or invalid input from leaking into persisted records. Invalid entries remain editable. Distances are converted to SI only at the input boundary; unchanged numerical fields preserve their exact stored values through edits. Carry, total, standard deviations, and loft must be finite and nonnegative; loft is at most 90°, total cannot be below carry, and correlation must be strictly between −1 and 1 to avoid singular prediction covariance. Lateral offset accepts signed values.
- Charts display user-entered carry values. Gaps are differences between those averages. They are not claims of measured carry or recommended equipment.
- Performance queries real saved swings, clubs, and rounds. Tempo charts require two valid phase-based tempo results. The scoring average includes only complete, ended 18-hole rounds; incomplete rounds and 9-hole rounds are not mixed into it. Round history still displays all round types.
- Settings offers 12 language endonyms plus device matching, independent distance/speed/wind/temperature units, voice preferences, a local privacy explanation, measurement provenance guidance, and a destructive confirmation before calling the shared full-data deletion service. Language and unit changes preserve data.

## Verification and limits

Swift sources were checked with the locally available Swift parser. iOS compilation, simulator layout/accessibility tests, and real-device interaction tests require full Xcode and have not been performed in this environment. A parser check does not establish SwiftUI type correctness or an iOS build.

A temporary standalone Swift executable also compiled the actual club draft and units code with only SwiftData annotations removed from a temporary model copy. All 16 checks passed: comma decimal entry, yard-to-meter conversion, signed lateral offset, missing-value preservation, malformed/nonfinite/negative input rejection, total-versus-carry validation, singular correlation rejection, exact unchanged SI preservation, and isolation of invalid edits. This harness does not test SwiftData. The app test target includes additional `ClubDraftTests`; those await Xcode execution.

The interface uses Dynamic Type, native forms, text-first empty states, monospaced measurement numerals, chart accessibility labels, and semantic colors. Visual QA on small/large iPhones, light/dark modes, larger accessibility sizes, long translations, and CJK layouts remains required. Strings are routed through the shared localization API; translation coverage and linguistic QA are tracked by the app foundation.

The privacy screen describes the local implementation; it is not a substitute for a publisher-specific hosted policy and support contact before distribution. Voice output availability depends on installed system voices. Course geometry, calibrated ball/club measurements, and launch/spin observability are not inferred by these screens.
