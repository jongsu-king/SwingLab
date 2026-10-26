# SwingLab

**Play with precision.** Native iPhone golf recording, pose review, personal club profiles, and course planning. This repository contains real SwiftUI/AVFoundation/Vision/MapKit/SwiftData implementations, not a web prototype.

**Status:** integrated development milestone; not a verified iOS build or App Store release. The development Mac has Swift 6.1.2 command-line tools but no Xcode application, iOS SDK, simulator runtime, XCTest module, or SwiftData macro plugin. The shared Swift library builds; portable numerical and capture model checks run. Native compilation, runtime behavior, and physical-device performance still need validation.

## Open and run

1. Install the current stable full Xcode and its iOS platform support. Select it in Xcode → Settings → Locations → Command Line Tools. Apple's current release guidance is linked in `Docs/ReleaseChecklist.md`.
2. Open `SwingLab.xcodeproj`. The app uses the local `SwingLabCore` Swift package in this repository. There are no third-party dependencies or API keys.
3. Select the **SwingLab** scheme and an iPhone simulator. Minimum deployment target is **iOS 17.0**; the source uses Swift 6 mode.
4. For a physical iPhone, set your development team in Signing & Capabilities and choose an available bundle identifier. No signing identity is configured in this repository.
5. Build and run. Complete onboarding, add your actual clubs in **Home → My Bag**, then record/import a swing or open **Course**. The first launch contains no sample measurements.

```sh
# On this Mac, or any compatible Apple-silicon Mac with Swift command-line tools:
Scripts/verify.sh

# With full Xcode selected:
swift test
xcodebuild -project SwingLab.xcodeproj -scheme SwingLab \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

# Discover an installed simulator, then substitute its identifier:
xcrun simctl list devices available
xcodebuild -project SwingLab.xcodeproj -scheme SwingLab \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_ID' test
```

The command-line checks deliberately do not claim that a syntax parse or a macOS framework type-check validates iOS compilation.

## Implemented in source

- Four tabs: Home, Swing, Course, Performance. Chalk/pine native design tokens with light/dark colors, system typography, accessible labels, and honest empty states.
- Onboarding and independent language, distance, speed, wind-speed, and temperature preferences. String catalogs for twelve languages; localized camera/location permission messages. SI storage, with temperature conversion in kelvin.
- Local SwiftData records for clubs, recordings, courses, hole references, rounds, scores, and GPS shots. Versioned schema and migration-plan entry point. Large videos remain separate files. No required account, advertising, analytics SDK, or upload backend.
- Bag creation/editing/deletion with detached validation, localized decimal entry, carry/total separation, variability/correlation inputs, and genuine club-gapping charts.
- AVFoundation front/rear capture, hardware-derived resolution/FPS choices, focus/exposure controls, framing grid, timer, interruption state, and free-storage checks. Capture is portrait-only and records sound when microphone access is granted (used on-device to time impact). PhotosPicker import makes a durable local copy; playback supports slow motion and actual frame stepping. Original-video sharing is available.
- Offline Vision 2D pose analysis with actual sample timestamps, orientation/mirroring handling, confidence filtering, temporal smoothing, cancellation, progress, and a thermal stop. Toggleable skeleton and wrist paths. Estimated phase candidates plus manually editable eight-phase markers, tempo, and image-space head-displacement proxy.
- Two-swing comparison with phase alignment, manual time offset, side-by-side/opacity overlay, slow motion, frame navigation, and optional localized speech for grounded timing observations.
- MapKit course-place search and manual reference editing. Map tap/target drag, fresh foreground GPS requests with visible age/accuracy, and geographic distance calculations. No assumption of surveyed course geometry.
- Offline 9/18-hole rounds, manually entered scorecards, GPS shot start/end capture, editable shot metadata, and round history. GPS displacement is never treated as airborne carry.
- Landing mean and 50%/80% conditional Gaussian regions based on entered club averages and deviations. Explainable conservative/balanced/aggressive club ranking, with unsupported wind, terrain, and hazard calculations disclosed.
- Performance charts from saved swings, entered club distances, and fully scored completed rounds. Full-data deletion plus individual deletion controls.

## Boundaries

This milestone does **not** include a trained ball/club detector, automatic shot tracer, traced-video export, spin measurement, calibrated launch reconstruction, physics simulation UI, validated 3D biomechanics, licensed hole/hazard polygons, weather integration, or StoreKit. No measurement is invented to fill these gaps. Phase detection and landing models are unvalidated estimates; manual inputs do not become sensor measurements.

The full acceptance criteria in the master prompt remain a roadmap. In particular, native build/test, real-device camera and GPS QA, statistical calibration, translation review on actual screens, signing, public policy/support hosting, TestFlight, and App Store submission are outstanding.

## Repository map

- `SwingLab/App`: app lifecycle, tab routing, onboarding.
- `SwingLab/Core`: design, preferences, versioned persistence models.
- `SwingLab/Features`: native screens grouped by feature.
- `SwingLab/Services`: capture, video library/player, pose, location, course repository.
- `Sources/SwingLabCore`: framework-independent units, geometry, dispersion, timing, language resolution, and recommendations.
- `Tests`: XCTest unit suite; the same core test methods run under a small portable harness when XCTest is absent.
- `SwingLabTests`, `SwingLabUITests`: native persistence/integration and navigation tests awaiting Xcode.
- `Scripts`: deterministic Xcode project/catalog generation and verification.
- `Docs`: milestone report, file manifest, capture/course notes, localization coverage, privacy, and release work.

After adding a source file, run `python3 Scripts/generate_project.py`. After editing translations, run `python3 Scripts/build_localizations.py`. Commit generated project/catalog changes alongside their source fragments. Version 1 has no migration stages; define a new versioned schema and a tested migration before changing shipped storage layouts.
