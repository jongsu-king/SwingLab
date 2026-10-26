import SwiftUI
import SwiftData
import SwingLabCore

struct SettingsView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirmation = false
    @State private var showingDeletionResult = false
    @State private var deletionSucceeded = false

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section {
                Picker(preferences.text("App language"), selection: $preferences.languageCode) {
                    Text(preferences.text("Device language")).tag("system")
                    ForEach(AppLanguage.choices) { language in
                        Text(language.name).tag(language.id)
                    }
                }
            } header: { Text(preferences.text("Language")) }
            footer: { Text(preferences.text("Language and measurement units are independent. Changing either keeps your records.")) }

            Section {
                Picker(preferences.text("Distance"), selection: $preferences.distanceUnit) {
                    ForEach(DistanceUnit.allCases, id: \.self) { unit in
                        Text(preferences.text(distanceName(unit))).tag(unit)
                    }
                }
                Picker(preferences.text("Ball & club speed"), selection: $preferences.speedUnit) {
                    ForEach(SpeedUnit.allCases, id: \.self) { unit in Text(unit.symbol).tag(unit) }
                }
                Picker(preferences.text("Wind speed"), selection: $preferences.windUnit) {
                    ForEach(SpeedUnit.allCases, id: \.self) { unit in Text(unit.symbol).tag(unit) }
                }
                Picker(preferences.text("Temperature"), selection: $preferences.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases, id: \.self) { unit in Text(unit.symbol).tag(unit) }
                }
            } header: { Text(preferences.text("Measurement units")) }
            footer: { Text(preferences.text("Records use meters, meters per second, and kelvin internally. Display preferences never rewrite measurements.")) }

            Section {
                Picker(preferences.text("Handedness"), selection: $preferences.handedness) {
                    ForEach(Handedness.allCases, id: \.self) { hand in
                        Text(preferences.text(hand.localizationKey)).tag(hand)
                    }
                }
            } header: { Text(preferences.text("Swing")) }

            Section {
                Toggle(preferences.text("Voice coaching"), isOn: $preferences.voiceEnabled)
                VStack(alignment: .leading, spacing: 10) {
                    Text(preferences.text("Speech rate"))
                    Slider(value: $preferences.speechRate, in: 0.25...0.65, step: 0.05) {
                        Text(preferences.text("Speech rate"))
                    } minimumValueLabel: {
                        Image(systemName: "tortoise").accessibilityLabel(preferences.text("Slower"))
                    } maximumValueLabel: {
                        Image(systemName: "hare").accessibilityLabel(preferences.text("Faster"))
                    }
                }.disabled(!preferences.voiceEnabled)
            } header: { Text(preferences.text("Coaching")) }
            footer: { Text(preferences.text("Spoken feedback uses an available voice for your selected language. If a suitable voice is unavailable, feedback stays on screen.")) }

            Section {
                NavigationLink { PrivacyView() } label: {
                    Label(preferences.text("Privacy & your data"), systemImage: "hand.raised")
                }
                NavigationLink { MeasurementGuideView() } label: {
                    Label(preferences.text("Understanding measurements"), systemImage: "info.circle")
                }
                Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                    Label(preferences.text("Delete all local data"), systemImage: "trash")
                }.disabled(preferences.activeMediaWrites > 0)
            } header: { Text(preferences.text("Your data")) }
            footer: { Text(preferences.text("No account is required. You control the recordings, clubs, and rounds saved on this iPhone.")) }

            Section {
                LabeledContent(preferences.text("Version"), value: appVersion)
            } header: { Text("SwingLab") }
        }
        .scrollContentBackground(.hidden)
        .background(SLTheme.background)
        .navigationTitle(preferences.text("Settings"))
        .alert(preferences.text("Delete all local data?"), isPresented: $showingDeleteConfirmation) {
            Button(preferences.text("Cancel"), role: .cancel) {}
            Button(preferences.text("Delete everything"), role: .destructive, action: deleteAllData)
        } message: {
            Text(preferences.text("This permanently deletes saved videos, analyses, clubs, courses, and rounds from SwingLab on this device. This cannot be undone. Your language and unit preferences are kept."))
        }
        .alert(preferences.text(deletionSucceeded ? "Local data deleted" : "Could not finish deletion"), isPresented: $showingDeletionResult) {
            Button(preferences.text("OK"), role: .cancel) { preferences.libraryRevision = UUID() }
        } message: {
            Text(preferences.text(deletionSucceeded ? "Your saved SwingLab records have been removed from this device." : "Some data could not be removed. Try again before leaving this screen."))
        }
    }

    private func distanceName(_ unit: DistanceUnit) -> String {
        switch unit {
        case .yards: "Yards"
        case .meters: "Meters"
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func deleteAllData() {
        guard preferences.activeMediaWrites == 0 else {
            deletionSucceeded = false
            showingDeletionResult = true
            return
        }
        do {
            try LocalDataController.deleteAll(context: modelContext)
            deletionSucceeded = true
        } catch {
            deletionSucceeded = false
        }
        showingDeletionResult = true
    }
}

private struct AppLanguage: Identifiable {
    let id: String
    let name: String
    // Endonyms stay recognizable when the golfer is changing an unfamiliar app language.
    static let choices: [AppLanguage] = [
        .init(id: "en", name: "English"),
        .init(id: "ko", name: "한국어"),
        .init(id: "ja", name: "日本語"),
        .init(id: "zh-Hans", name: "简体中文"),
        .init(id: "zh-Hant", name: "繁體中文"),
        .init(id: "es", name: "Español"),
        .init(id: "pt-BR", name: "Português (Brasil)"),
        .init(id: "de", name: "Deutsch"),
        .init(id: "fr", name: "Français"),
        .init(id: "it", name: "Italiano"),
        .init(id: "th", name: "ไทย"),
        .init(id: "vi", name: "Tiếng Việt")
    ]
}
