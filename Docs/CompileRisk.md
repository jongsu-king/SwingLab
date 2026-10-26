# Round 2 compile-risk ledger

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
