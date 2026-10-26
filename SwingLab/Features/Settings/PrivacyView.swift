import SwiftUI
import SwingLabCore

struct PrivacyView: View {
    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        List {
            Section {
                Text(preferences.text("Your videos, club details, course notes, and round records are saved locally. Swing analysis runs on the iPhone. This version does not upload your videos or require an account."))
            } header: { Text(preferences.text("Local by design")) }
            Section {
                privacyRow("Camera", "Camera access is used when you choose to record a swing.")
                privacyRow("Location", "Location access is used for on-course positioning and GPS shot records while you use the app. GPS accuracy is shown alongside location information.")
                privacyRow("Video import", "The system picker gives SwingLab access only to videos you choose. Imported copies remain in SwingLab until you delete them.")
            } header: { Text(preferences.text("Permissions with a purpose")) }
            Section {
                Text(preferences.text("Maps and course search use Apple services and may require an internet connection. Requests to those services are governed by Apple's privacy policy. SwingLab does not add advertising or analytics SDKs."))
                Link(preferences.text("Apple privacy policy"), destination: URL(string: "https://www.apple.com/legal/privacy/")!)
            } header: { Text(preferences.text("Network services")) }
            Section {
                Text(preferences.text("Delete individual items in their lists, or use Delete all local data in Settings. Deletion removes SwingLab's copies; it does not delete original videos from Photos or files you exported. Device backups are managed by your iPhone settings."))
                Text(preferences.text("Permission access can be changed at any time in the iPhone Settings app."))
            } header: { Text(preferences.text("Retention & control")) }
        }
        .scrollContentBackground(.hidden)
        .background(SLTheme.background)
        .navigationTitle(preferences.text("Privacy & your data"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacyRow(_ title: LocalizationKey, _ detail: LocalizationKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(preferences.text(title)).font(.headline)
            Text(preferences.text(detail)).font(.subheadline).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}

struct MeasurementGuideView: View {
    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        List {
            entry("User-entered", "Club distances, scorecards, and manually placed phase markers come from your entries. Their accuracy depends on the information you provide.")
            entry("Vision-derived", "Body landmarks come from Apple's on-device Vision framework. A 2D projected angle is not a full 3D anatomical measurement.")
            entry("Estimated", "Swing phases and tempo can depend on rule-based estimates. Review phase markers before comparing swings.")
            entry("GPS displacement", "The distance between two recorded positions is ground displacement. It includes location uncertainty and is not measured airborne carry.")
            entry("Predicted", "Landing regions use the club averages and variability you enter. They are statistical predictions and are only as reliable as those inputs.")
            entry("Simulated", "Flight simulations use explicit launch and environment inputs. They describe a hypothetical flight, not a measurement from a recording.")
            entry("Unavailable", "Unknown values stay unknown. Ordinary iPhone footage does not guarantee measurable ball speed, spin RPM, or a complete 3D flight path.")
        }
        .scrollContentBackground(.hidden)
        .background(SLTheme.background)
        .navigationTitle(preferences.text("Understanding measurements"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func entry(_ title: LocalizationKey, _ detail: LocalizationKey) -> some View {
        Section {
            Text(preferences.text(detail)).foregroundStyle(.secondary)
        } header: { Text(preferences.text(title)) }
    }
}
