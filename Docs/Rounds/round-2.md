# Round 2 — verified WP1 boundary

## A. Completed functionality

WP1 introduces typed provenance and recording metadata, legacy analysis decoding, SI metric values with validation, and shared metric readouts/badges across the existing screens. Stored V1 columns retain their original names/types; startup canonicalizes legacy source/angle labels. Missing measurements remain Unavailable. Core models now live in SwingLabCore.

| WP | Status | Verified by | Remaining gap |
|---|---|---|---|
| WP1 | Done | swift build + portable harness + static provenance grep | Native UI/store validation awaits Xcode; see compile-risk ledger. |
| WP2 | Not started | none | Pose v2, cache migration, handedness. |
| WP3 | Not started | none | Audio capture and impact detection. |
| WP4 | Not started | none | Sessions, baseline coaching and consistency. |
| WP5 | Not started | none | Flight physics. |
| WP6 | Not started | none | Geometry/import and hazard-aware aim search. |
| WP7 | Not started | none | Full design tokens and data-first Home. |
| WP8 | Not started | none | Complete static localization integrity/plurals. |
| WP9 | Not started | none | Seeded tracking and tracer. |

[Round 1 response](Review/round-1-response.md) answers R1–R14. The separately supplied reviewer rebuttal was read and preserved.

## B. Changed files

- `Docs/CompileRisk.md`
- `Docs/Review/round-1-response.md`
- `Scripts/CaptureModelChecks.swift`
- `Scripts/Localization-round2.json`
- `Scripts/PortableTestHarness.swift`
- `Scripts/build_localizations.py`
- `Scripts/check_capture.sh`
- `Scripts/check_core.sh`
- `Scripts/verify.sh`
- `Sources/SwingLabCore/PoseAnalysis.swift`
- `Sources/SwingLabCore/Provenance.swift`
- `SwingLab.xcodeproj/project.pbxproj`
- `SwingLab/App/SwingLabApp.swift`
- `SwingLab/Core/DesignSystem/MetricReadout.swift`
- `SwingLab/Core/Localization/AppPreferences.swift`
- `SwingLab/Core/Models/SwingRecording.swift`
- `SwingLab/Core/Persistence/LocalDataController.swift`
- `SwingLab/Features/AICaddie/CaddieView.swift`
- `SwingLab/Features/Camera/CameraView.swift`
- `SwingLab/Features/CourseManager/CourseView.swift`
- `SwingLab/Features/Home/HomeView.swift`
- `SwingLab/Features/MyBag/BagView.swift`
- `SwingLab/Features/MyBag/ClubDetailView.swift`
- `SwingLab/Features/MyBag/ClubEditorView.swift`
- `SwingLab/Features/Performance/PerformanceView.swift`
- `SwingLab/Features/RoundTracker/RoundViews.swift`
- `SwingLab/Features/Swing/SwingComparisonView.swift`
- `SwingLab/Features/Swing/SwingDetailView.swift`
- `SwingLab/Features/Swing/SwingVideoStage.swift`
- `SwingLab/Features/Swing/SwingView.swift`
- `SwingLab/Resources/Localizable.xcstrings`
- `SwingLab/Services/PoseEstimationService.swift`
- `Tests/SwingLabCoreTests/ProvenanceTests.swift`

## C. Implementation details

Provenance uses seven stable IDs; audioDerived belongs to the measured category, but a mixed marker tempo remains estimated. Unknown origins, nonfinite values and missing metrics cannot become measured values. Confidence outside 0...1 is omitted, negative sample counts are omitted, and zero remains n=0. Labels use existing translations; new positional format strings and audio/region labels have entries in all twelve languages. Shared readouts convert SI at display time. Dates, identifiers, configuration controls and framework chart axes remain contextual metadata; measurement readouts and chart datasets carry typed provenance. No permission added.

## D. Build results

Gate 0 command, repeated at WP1 boundary:

```sh
xcode-select -p; xcodebuild -version; xcrun simctl list runtimes
```

Real output:

```text
/Library/Developer/CommandLineTools
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
xcrun: error: unable to find utility "simctl", not a developer tool or in PATH
```

Exact successful full check command:

```sh
Scripts/verify.sh > Validation/round-2/wp1-verified.log 2>&1
```

This was run with macOS media-service access after sandboxed synthetic-video encoding failed. The script executes `swift build --disable-sandbox --cache-path .build/SwiftPMCache --manifest-cache local` with compiler caches in `.build/ModuleCache`. The outer workspace sandbox is unchanged by SwiftPM's nested-sandbox flag. Initial cache-write/nested-sandbox errors and the harness deployment-target mismatch were fixed; their real logs are retained under `Validation/round-2/`. No Xcode build, simulator test, install, launch, or screenshot is claimed.

## E. Tests

20 portable Core test groups, 9 capture-model checks, 4 actual negative/control media cases, and 5 course checks passed. Shared macOS framework service typechecks, all native Swift syntax parsing, resources and project syntax passed. Fixed schema-v1 JSON decodes; new stable IDs re-encode; source grep finds no string-literal provenance comparisons/initializers. Native XCTest and UI tests are not run.

Real tail of the successful verification output (exit 0):

```text
PASS schema-v1 analysis migration
PASS typed metric SI units and origin
PASS missing and invalid pose metrics
20 test groups; 0 failed assertions. Portable harness, not XCTest.
PASS tempo uses actual timestamps
PASS manual marker provenance
PASS estimated impact propagates to tempo
PASS analysis JSON round trip
PASS out-of-order timing rejected
PASS non-finite timing rejected
PASS missing measurements remain unavailable
PASS head proxy uses normalized displacement
PASS insufficient head observations rejected
PASS shared macOS AVFoundation/Vision/Transferable service typecheck (not an iOS build)
PASS landscape video decoding and honest no-pose result
PASS portrait video decoding and honest no-pose result
PASS mirrored video decoding and honest no-pose result
PASS invalid video rejected
PASS GPS stale/future time gates
PASS GPS accuracy/invalid-coordinate gates
PASS unknown scores preserved and strokes not double counted
PASS impossible and malformed scores rejected
PASS manual reference JSON round trip
PASS shared macOS CoreLocation/MapKit services typecheck (not an iOS build)
SwingLab.xcodeproj/project.pbxproj: OK
SwingLab/Resources/Info.plist: OK
SwingLab/Resources/PrivacyInfo.xcprivacy: OK
Catalogs and project syntax validated. Parsing does not validate iOS compilation.
```

## F. Current limitations

[Compile-risk ledger](CompileRisk.md) lists every changed native Swift file. Highest risks are SwiftData private setters/computed enum bindings and opening existing stores, SwiftUI builder/actor checking, chart accessibility, and compact layout after adding badges. No positive golfer-pose, physical camera, device performance, or visual UI claim is made. Full WP8 dynamic-key/plural auditing remains outstanding.

## G. Next milestone

Recheck Gate 0, then WP2: Core pose sampling/smoothing/phase rules and tests, thin two-pass Vision adapter, handedness, per-phase merge and V2 summary migration. If full Xcode appears, make the native build green first.
