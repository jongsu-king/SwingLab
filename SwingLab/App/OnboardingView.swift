import SwiftUI
import SwingLabCore

struct OnboardingView: View {
    @Environment(AppPreferences.self) private var preferences
    private let names = ["en": "English", "ko": "한국어", "ja": "日本語", "zh-Hans": "简体中文", "zh-Hant": "繁體中文", "es": "Español", "pt-BR": "Português (Brasil)", "de": "Deutsch", "fr": "Français", "it": "Italiano", "th": "ไทย", "vi": "Tiếng Việt"]
    var body: some View {
        @Bindable var preferences = preferences
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Image(systemName: "flag.checkered").font(.system(size: 42, weight: .ultraLight)).foregroundStyle(SLTheme.forest).padding(.top, 32)
                    Text("SwingLab").font(.system(.largeTitle, design: .serif).weight(.medium))
                    Text(preferences.text("Play with precision.")).font(.title2)
                    Text(preferences.text("Record your swing. Know your distances. Plan your next shot.")).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 16) {
                        Picker(preferences.text("Language"), selection: $preferences.languageCode) {
                            Text(preferences.text("Device language")).tag("system")
                            ForEach(LanguageResolver.supported, id: \.self) { code in Text(names[code] ?? code).tag(code) }
                        }
                        Picker(preferences.text("Distance"), selection: $preferences.distanceUnit) {
                            Text(preferences.text("Yards")).tag(DistanceUnit.yards)
                            Text(preferences.text("Meters")).tag(DistanceUnit.meters)
                        }
                    }.pickerStyle(.menu)
                    Divider()
                    Label(preferences.text("Your videos and golf records stay on this iPhone."), systemImage: "iphone").font(.subheadline)
                    Text(preferences.text("Camera and location access are requested only when you use them. No account required.")).font(.footnote).foregroundStyle(.secondary)
                    Button { preferences.completedOnboarding = true } label: {
                        Text(preferences.text("Get started")).frame(maxWidth: .infinity).padding(.vertical, 10)
                    }.buttonStyle(.borderedProminent)
                }.padding(28)
            }.background(SLTheme.background)
        }
    }
}
