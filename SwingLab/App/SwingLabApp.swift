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
            _preferences = State(initialValue: AppPreferences(defaults: defaults))
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
            .task { if container == nil { openLibrary() } }
        }
    }
    private func openLibrary() {
        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                let schema = Schema(SwingLabCurrentSchema.models)
                container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
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
}
