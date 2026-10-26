import Foundation
import Observation
import SwingLabCore

@MainActor @Observable
final class AppPreferences {
    /// Reset navigation after destructive library changes without resetting preferences.
    var libraryRevision = UUID()
    /// File transfers keep deletion disabled until their durable-copy/save transaction ends.
    var activeMediaWrites = 0
    private let defaults: UserDefaults
    var languageCode: String { didSet { defaults.set(languageCode, forKey: "language") } }
    var distanceUnit: DistanceUnit { didSet { defaults.set(distanceUnit.rawValue, forKey: "distanceUnit") } }
    var speedUnit: SpeedUnit { didSet { defaults.set(speedUnit.rawValue, forKey: "speedUnit") } }
    var windUnit: SpeedUnit { didSet { defaults.set(windUnit.rawValue, forKey: "windUnit") } }
    var temperatureUnit: TemperatureUnit { didSet { defaults.set(temperatureUnit.rawValue, forKey: "temperatureUnit") } }
    var voiceEnabled: Bool { didSet { defaults.set(voiceEnabled, forKey: "voiceEnabled") } }
    var speechRate: Double { didSet { defaults.set(speechRate, forKey: "speechRate") } }
    var completedOnboarding: Bool { didSet { defaults.set(completedOnboarding, forKey: "onboarded") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        languageCode = defaults.string(forKey: "language") ?? "system"
        distanceUnit = DistanceUnit(rawValue: defaults.string(forKey: "distanceUnit") ?? "") ?? .yards
        speedUnit = SpeedUnit(rawValue: defaults.string(forKey: "speedUnit") ?? "") ?? .mph
        windUnit = SpeedUnit(rawValue: defaults.string(forKey: "windUnit") ?? "") ?? .metersPerSecond
        temperatureUnit = TemperatureUnit(rawValue: defaults.string(forKey: "temperatureUnit") ?? "") ?? .celsius
        voiceEnabled = defaults.bool(forKey: "voiceEnabled")
        speechRate = defaults.object(forKey: "speechRate") as? Double ?? 0.45
        completedOnboarding = defaults.bool(forKey: "onboarded")
    }
    var resolvedLanguage: String { LanguageResolver.resolve(selection: languageCode, preferred: Locale.preferredLanguages) }
    var locale: Locale { Locale(identifier: resolvedLanguage) }
    func text(_ key: String) -> String {
        let path = Bundle.main.path(forResource: resolvedLanguage, ofType: "lproj")
            ?? Bundle.main.path(forResource: "en", ofType: "lproj")
        let bundle = path.flatMap(Bundle.init(path:)) ?? .main
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }
    func distance(_ meters: Double) -> String {
        guard meters.isFinite else { return text("Unavailable") }
        return distanceUnit.fromSI(meters).formatted(.number.precision(.fractionLength(0)).locale(locale)) + " " + distanceUnit.symbol
    }
    /// Positional, full-sentence templates preserve each language's argument order.
    func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }
}
