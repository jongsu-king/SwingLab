# Implementation milestone — 26 October 2026

## A. Completed functionality

Created a native SwiftUI iPhone project from an empty Git workspace. The initial deliverables are implemented in source: feature architecture, semantic design tokens, four tabs, Home/Swing/Course/Performance, Settings, independent language and unit preferences, all twelve language resources, SwiftData models, real local bag CRUD, MapKit/manual course tools, AVFoundation capture foundation, and camera/location permission handling.

Continued into the roadmap with local video import/playback/export, on-device Vision pose processing, phase review and manual markers, tempo, skeleton/wrist overlays, swing comparison and timing feedback, GPS shot recording, editable scorecards, history charts, user-profile landing regions, and explainable club ranking. All production screens start from actual saved data. Ball/club/spin measurements remain explicitly unavailable.

These are integrated source implementations, not a claim of a running or production-validated iOS application. Full Xcode is absent, so the milestone's native build-and-test gate is still open.

## B. Changed files

Every file was created in this milestone because the workspace contained only an empty Git repository. `FileManifest.txt` lists the exact repository-relative paths. Principal entry points:

- `SwingLab.xcodeproj/project.pbxproj` and shared scheme
- `SwingLab/App/SwingLabApp.swift`, `AppRouter.swift`, `OnboardingView.swift`
- `SwingLab/Core/Models/`, `Persistence/`, `Localization/`, `DesignSystem/`
- `SwingLab/Features/`, `SwingLab/Services/`
- `Sources/SwingLabCore/`, `Tests/SwingLabCoreTests/`
- `SwingLabTests/`, `SwingLabUITests/`
- `SwingLab/Resources/Localizable.xcstrings`, `InfoPlist.xcstrings`, permission plist, privacy manifest, app icon
- `Scripts/verify.sh`, project/catalog generators, numerical/media/course validation harnesses

The localization audit reports **425 UI keys plus 2 permission descriptions across all 12 languages, with zero missing locale entries**. This is resource coverage; native-speaker and visual QA remain pending.

## C. Implementation details

SwiftUI and Observation drive feature state. SwiftData stores seven live model types in a versioned schema; Codable pose and reference-point payloads sit alongside their owning records. Videos remain in Application Support, referenced by relative filenames. A separate Swift package holds calculations and language resolution. There are no third-party runtime dependencies or remote AI services.

The camera mutates its session on a dedicated serial queue; offline Vision analysis does not compete synchronously with capture. Analysis reads actual video sample presentation timestamps, handles standard orientation/mirroring transforms, filters low-confidence joints, preserves missing frames, and labels phase candidates as estimates. Timing comes from ordered phase timestamps, never a nominal-frame-count assumption.

Distances use a spherical geodesic model. Dispersion uses a correlated bivariate Gaussian in the aim-relative forward/right plane, with chi-square(2) contours for the requested probability mass. Conditional regions depend on user-entered statistics and are not calibrated guarantees. Caddie ranking compares target error and variance under an explicit risk preference. No hazard probabilities are shown without verified polygons.

Deletion stages files before a database commit. Startup reconciles interrupted staging using saved recording references. Active import/save operations block full deletion. Language switches preserve the library; a deletion-result acknowledgment resets retained navigation references.

## D. Build results

Development environment observed: macOS, Apple Swift **6.1.2**, developer directory `/Library/Developer/CommandLineTools`; no Xcode application or iOS simulator runtime available.

- `swift build`: **passed** for `SwingLabCore`.
- Swift 6 macOS SDK type-check: **passed** for shared Vision/AVFoundation/Transferable/playback and CoreLocation/MapKit services. This is not an iOS build.
- Native app/test source syntax parsing, Xcode project plist, Info.plist, privacy manifest, asset JSON, scheme XML, and catalog validation: **passed**.
- `xcodebuild -project SwingLab.xcodeproj -scheme SwingLab -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`: **blocked before compilation**, with the actual diagnostic:

```text
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

An attempted native-model type-check was also blocked by the missing `SwiftDataMacros` plugin. No native app compilation, simulator launch, signed build, archive, or deployment is claimed.

## E. Tests

Final `Scripts/verify.sh` completed successfully. Exact output is in `Validation/command-line-checks.log`.

- **13 core test groups passed**, including units, localization fallback, geodesics, projected angles, timestamp timing, 50/80/95% region mass, hazard-kernel integration, invalid inputs, recommendations, and interrupted-media recovery.
- **9 capture model checks passed** for Codable round trips, timing/provenance, invalid phases, missing measurements, and the head-displacement proxy.
- **4 real media pipeline cases passed**: generated landscape, portrait, and mirrored clips were decoded and correctly returned no reliable pose; corrupt video was rejected. These are negative/control cases, not validation of golfer tracking or orientation overlay accuracy.
- **5 course test groups passed** for GPS freshness/accuracy, malformed/impossible score rejection, unknown score preservation, and manual-reference serialization.
- Direct `swift test` was attempted and failed because XCTest is absent. Core tests subsequently ran through the included portable harness. Native XCTest persistence, preference, club-editor, GPS, localization-bundle, and UI-navigation tests are present but **not executed**.
- No physical iPhone camera, GPS, thermal, battery, positive-pose accuracy, screen-layout, or calibration tests were run.

## F. Current limitations

The app still needs an actual iOS compile and simulator/device QA. Future phases remain: full practice-session grouping and consistency analytics; validated phase classification and expanded biomechanics; manual club/ball annotation and licensed/trained detection; observed ball tracking/tracer export; defensible launch/flight/spin research; licensed detailed course/hazard geometry; weather; broader strategy; StoreKit; and distribution preparation.

Capture is portrait and silent, limited to 60 seconds. Imports are limited to three minutes; pose sampling is capped at 30 Hz. Only address/top/impact have heuristic candidate suggestions; all eight markers can be entered manually. No detector/model weights, fabricated demo measurements, club-head speed, ball speed, carry-from-video, spin RPM, or full-flight reconstruction are included.

App signing, public policy/support identity and URLs, localized App Store media, TestFlight, review submission, and acceptance are not complete. See `ReleaseChecklist.md` for current official requirements and device validation work.

## G. Next milestone

Install/select full Xcode, open the checked-in project, and resolve native build or runtime issues before adding more features. Run the included simulator tests and validate the camera/import/pose/round workflow on an actual iPhone. Then validate and extend coaching and consistency in roadmap order, while keeping unobservable ball/spin values unavailable.
