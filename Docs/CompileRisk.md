# Round 2 compile-risk ledger

> **Update (26 Oct 2026, reviewer):** Full Xcode 27.1 (iOS 27.1 SDK) is now installed. The first native build
> `xcodebuild -project SwingLab.xcodeproj -scheme SwingLab -destination 'generic/platform=iOS Simulator' -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO build`
> reported **BUILD SUCCEEDED with 0 errors and 0 warnings** in Swift 6 language mode, compiling 51 app and core sources.
> `swift test` ran all 42 core tests under real XCTest, with 0 failures. Compile risk below is therefore resolved;
> the **runtime** checks listed in each row (simulator and device behaviour, layout, persistence migration) remain open.

Full Xcode and simulator tools are absent at the WP1 boundary. `swift build` and portable harnesses validate Core; frontend parsing does not validate SwiftUI or SwiftData macros. Every changed native Swift source is listed below. No new permission in WP1.

| App file | First native build / runtime check |
|---|---|
| `SwingLab/App/SwingLabApp.swift` | Startup metadata normalization before presenting the ModelContainer; rollback/error path. |
| `SwingLab/Core/DesignSystem/MetricReadout.swift` | @MainActor View isolation; Font/HorizontalAlignment initializers; localized format/percent styles; Dynamic Type layout. |
| `SwingLab/Core/Localization/AppPreferences.swift` | Positional String(format:locale:arguments:) with locale-specific number strings. |
| `SwingLab/Core/Models/SwingRecording.swift` | SwiftData @Model private(set) String columns; computed enum bindings; persistence schema hash must remain compatible with V1. |
| `SwingLab/Core/Persistence/LocalDataController.swift` | SwiftData fetch/save/rollback transaction for metadata normalization. |
| `SwingLab/Features/AICaddie/CaddieView.swift` | SwiftUI builder/type inference for shared metric components; Core import; localization, accessibility and narrow-screen layout. |
| `SwingLab/Features/Camera/CameraView.swift` | Typed callback and picker tags; elapsed-clock readout in TimelineView; contrast over camera. |
| `SwingLab/Features/CourseManager/CourseView.swift` | SwiftUI builder/type inference for shared metric components; Core import; localization, accessibility and narrow-screen layout. |
| `SwingLab/Features/Home/HomeView.swift` | SwiftUI builder/type inference for shared metric components; Core import; localization, accessibility and narrow-screen layout. |
| `SwingLab/Features/MyBag/BagView.swift` | SwiftUI builder/type inference for shared metric components; Core import; localization, accessibility and narrow-screen layout. |
| `SwingLab/Features/MyBag/ClubDetailView.swift` | SwiftUI builder/type inference for shared metric components; Core import; localization, accessibility and narrow-screen layout. |
| `SwingLab/Features/MyBag/ClubEditorView.swift` | SwiftUI builder/type inference for shared metric components; Core import; localization, accessibility and narrow-screen layout. |
| `SwingLab/Features/Performance/PerformanceView.swift` | Charts result-builder local values, typed accessibility formatting and provenance counts. |
| `SwingLab/Features/RoundTracker/RoundViews.swift` | SwiftUI builder/type inference for shared metric components; Core import; localization, accessibility and narrow-screen layout. |
| `SwingLab/Features/Swing/SwingComparisonView.swift` | SwiftUI builder/type inference for shared metric components; Core import; localization, accessibility and narrow-screen layout. |
| `SwingLab/Features/Swing/SwingDetailView.swift` | @Bindable computed metadata enum property; Core marker/metric imports and SwiftUI layout. |
| `SwingLab/Features/Swing/SwingVideoStage.swift` | Core model import for Canvas overlays. |
| `SwingLab/Features/Swing/SwingView.swift` | SwiftUI builder/type inference for shared metric components; Core import; localization, accessibility and narrow-screen layout. |
| `SwingLab/Services/PoseEstimationService.swift` | Core model import across actor return/progress; existing AVFoundation/Vision @preconcurrency imports retained, not newly added. |

Also verify project regeneration links the local Core package and compiles the new component. Metadata adapters retain the original stored column types/names; opening a real Round 1 store remains a native integration check.

The SwiftPM `--disable-sandbox` flag only avoids a nested sandbox initialization failure; the outer workspace sandbox remains active. Compiler caches stay in `.build/`. No `@preconcurrency` or `nonisolated(unsafe)` was added to hide a new warning.

## Reviewer additions (WP2–WP3, while Codex is unavailable)

WP3 adds one permission: `NSMicrophoneUsageDescription` (12 languages). Recording still works when it is declined.

| App file | First native build / runtime check |
|---|---|
| `SwingLab/Services/CameraService.swift` | Audio `AVCaptureDeviceInput` added inside the existing begin/commit block; new `CameraEvent.audio`; microphone `requestAccess` after camera access. On device: the movie has an AAC track, mic denial still records, and interruptions (calls, Siri) resume with audio. |
| `SwingLab/Services/AudioImpactReader.swift` | iOS SDK typecheck of the audio `AVAssetReaderTrackOutput` settings. It is typechecked and exercised on macOS by `check_capture.sh`, where AAC and LPCM clicks read back within 0.5 ms. On device: real camera AAC timing against a filmed clap. |
| `SwingLab/Services/PoseEstimationService.swift` | New actor method `audioImpact(asset:duration:markers:)` passes `AVAsset` to a nonisolated async helper; the `@preconcurrency` import is unchanged. Typechecked on macOS. |
| `SwingLab/Features/Camera/CameraView.swift` | Ternary localization keys for the sound caption. |
| `SwingLab/Features/Swing/SwingDetailView.swift` | `Label` with a dynamic SF Symbol name; exhaustive `switch` over `AudioImpactRejection?`. |
| `SwingLab/Features/FlightSimulation/HypotheticalFlightView.swift` (new) | `TextField(_:value:format:)` with `Double?` bindings and `.number.locale(_:)`; `Grid`/`GridRow` (iOS 16+); Swift Charts `LineMark` with a `KeyPath` value; `catch ModelError.insufficientData` pattern. Layout of long German/Thai labels next to 96 pt fields. |
| `SwingLab/Features/Swing/SwingView.swift` | New Ball Lab section; SF Symbol `point.topleft.down.to.point.bottomright.curvepath` (iOS 16+). |
| `SwingLab/Core/DesignSystem/MetricReadout.swift` | New `"deg"` unit case. |
