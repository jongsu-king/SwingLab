import SwiftUI
import SwiftData

@main
struct SwingLabApp: App {
    @State private var preferences: AppPreferences
    @State private var container: ModelContainer?
    @State private var storageError: String?
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let defaults = UserDefaults(suiteName: "SwingLabUITests")!
            defaults.removePersistentDomain(forName: "SwingLabUITests")
            let testPreferences = AppPreferences(defaults: defaults)
            if ProcessInfo.processInfo.arguments.contains("--screenshot-testing") {
                testPreferences.completedOnboarding = true
                if let language = Self.testArgument("--screenshot-language"), ["en", "ko", "de"].contains(language) {
                    testPreferences.languageCode = language
                }
            }
            _preferences = State(initialValue: testPreferences)
        } else { _preferences = State(initialValue: AppPreferences()) }
        #else
        _preferences = State(initialValue: AppPreferences())
        #endif
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    AppRouter().modelContainer(container)
                } else {
                    VStack(spacing: 20) {
                        Text("SwingLab").font(.largeTitle.weight(.semibold))
                        if storageError != nil {
                            Text(preferences.text("Your local library could not be opened. Your files have not been removed."))
                            Button(preferences.text("Try again"), action: openLibrary).buttonStyle(.borderedProminent)
                        } else { ProgressView() }
                    }.padding(32)
                }
            }
            .environment(preferences)
            .environment(\.locale, preferences.locale)
            .tint(SLTheme.forest)
            .preferredColorScheme(screenshotColorScheme)
            .task { if container == nil { openLibrary() } }
        }
    }
    private func openLibrary() {
        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                let schema = Schema(SwingLabCurrentSchema.models)
                let testContainer = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
                // This missing-video fixture exercises the actual empty detail UI. It exists only
                // in a DEBUG test launch and contains no video, pose, timings, or fabricated metrics.
                if ProcessInfo.processInfo.arguments.contains("--screenshot-testing"),
                   ProcessInfo.processInfo.arguments.contains("--screenshot-empty-recording") {
                    let recording = SwingRecording(title: preferences.text("Swing recording"),
                        videoFileName: "screenshot-empty-recording.mov", durationSeconds: 0,
                        nominalFrameRate: 0, videoWidth: 0, videoHeight: 0, cameraAngle: .unspecified, source: .unspecified)
                    recording.id = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
                    testContainer.mainContext.insert(recording)
                    try testContainer.mainContext.save()
                }
                container = testContainer
                return
            }
            #endif
            let schema = Schema(versionedSchema: SwingLabCurrentSchema.self)
            let opened = try ModelContainer(for: schema, migrationPlan: SwingLabMigrationPlan.self)
            try LocalDataController.normalizeRecordingMetadata(context: opened.mainContext)
            try LocalDataController.recoverInterruptedDeletion(context: opened.mainContext)
            container = opened
            storageError = nil
        } catch { storageError = error.localizedDescription }
    }

    private var screenshotColorScheme: ColorScheme? {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing"),
              ProcessInfo.processInfo.arguments.contains("--screenshot-testing") else { return nil }
        return Self.testArgument("--screenshot-appearance") == "dark" ? .dark : .light
        #else
        return nil
        #endif
    }

    #if DEBUG
    private static func testArgument(_ name: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
    #endif
}
