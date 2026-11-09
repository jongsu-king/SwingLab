import SwiftUI
import SwingLabCore

/// The same source label accompanies readouts, charts, and editable numeric inputs.
@MainActor
struct ProvenanceBadge: View {
    @Environment(AppPreferences.self) private var preferences
    let provenance: Provenance
    var sampleCount: Int? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(preferences.text(provenance.localizationKey))
            if let sampleCount {
                Text(String(format: preferences.text("metric.sampleCount"), locale: preferences.locale,
                            sampleCount.formatted(.number.locale(preferences.locale))))
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// Presentation converts SI units only at this boundary. Missing values never render as zero.
@MainActor
struct SLMetricReadout: View {
    @Environment(AppPreferences.self) private var preferences
    let metric: ProvenancedValue
    var label: String? = nil
    var fractionDigits: Int = 0
    var displayAsPercent = false
    var displayAsRatio = false
    var valueFont: Font = .body
    var alignment: HorizontalAlignment = .trailing

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            if let label { Text(label).font(.caption).foregroundStyle(.secondary) }
            Text(Self.formattedValue(metric, preferences: preferences, fractionDigits: fractionDigits,
                                     displayAsPercent: displayAsPercent, displayAsRatio: displayAsRatio))
                .font(valueFont).monospacedDigit().foregroundStyle(SLTheme.ink)
            // The value already reads "Unavailable"; a second badge saying so (and a sample count) adds nothing.
            if metric.value != nil, metric.provenance != .unavailable {
                ProvenanceBadge(provenance: metric.provenance, sampleCount: metric.sampleCount)
            }
        }
        .accessibilityElement(children: .combine)
    }

    static func formattedValue(_ metric: ProvenancedValue, preferences: AppPreferences,
                               fractionDigits: Int = 0, displayAsPercent: Bool = false,
                               displayAsRatio: Bool = false) -> String {
        guard let value = metric.value, value.isFinite, metric.provenance != .unavailable,
              let parts = displayParts(metric, preferences: preferences, fractionDigits: fractionDigits) else {
            return preferences.text("Unavailable")
        }
        if displayAsPercent {
            return value.formatted(.percent.precision(.fractionLength(fractionDigits)).locale(preferences.locale))
        }
        if displayAsRatio {
            return String(format: preferences.text("metric.ratio"), locale: preferences.locale, parts.number)
        }
        guard !parts.unit.isEmpty else { return parts.number }
        return String(format: preferences.text("metric.valueUnit"), locale: preferences.locale, parts.number, parts.unit)
    }

    /// The display number and unit symbol of a value, converted from SI at this boundary only.
    /// Nil when the value is unavailable, so a missing number can never render as zero.
    static func displayParts(_ metric: ProvenancedValue, preferences: AppPreferences,
                             fractionDigits: Int = 0) -> (number: String, unit: String)? {
        guard let value = metric.value, value.isFinite, metric.provenance != .unavailable else { return nil }
        let displayValue: Double
        let displayUnit: String
        switch metric.unit {
        case "m":
            displayValue = preferences.distanceUnit.fromSI(value)
            displayUnit = preferences.distanceUnit.symbol
        case "m/s":
            displayValue = preferences.speedUnit.fromSI(value)
            displayUnit = preferences.speedUnit.symbol
        case "rad":
            displayValue = value * 180 / .pi
            displayUnit = "°"
        case "deg":
            displayValue = value
            displayUnit = "°"
        case "K":
            displayValue = preferences.temperatureUnit.fromSI(value)
            displayUnit = preferences.temperatureUnit.symbol
        case "1":
            displayValue = value
            displayUnit = ""
        default:
            displayValue = value
            displayUnit = metric.unit
        }
        return (displayValue.formatted(.number.precision(.fractionLength(fractionDigits)).locale(preferences.locale)), displayUnit)
    }
}

/// Shortest and longest value of a bracket (a simulated carry, an estimated club speed, a
/// published spin range) with one badge for both ends. Missing ends never render as zero.
@MainActor
struct SLRangeReadout: View {
    @Environment(AppPreferences.self) private var preferences
    let range: ReadoutRange?
    var label: String? = nil
    var fractionDigits: Int = 0
    var valueFont: Font = .body
    var alignment: HorizontalAlignment = .trailing

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            if let label { Text(label).font(.caption).foregroundStyle(.secondary) }
            Text(Self.formattedValue(range, preferences: preferences, fractionDigits: fractionDigits))
                .font(valueFont).monospacedDigit().foregroundStyle(SLTheme.ink)
            if let range, range.isAvailable {
                // The spin-sample count explains a simulated bracket; published rows need no count.
                ProvenanceBadge(provenance: range.provenance, sampleCount: range.provenance == .simulated ? range.low.sampleCount : nil)
            }
        }
        .accessibilityElement(children: .combine)
    }

    static func formattedValue(_ range: ReadoutRange?, preferences: AppPreferences, fractionDigits: Int = 0) -> String {
        guard let range,
              let low = SLMetricReadout.displayParts(range.low, preferences: preferences, fractionDigits: fractionDigits),
              let high = SLMetricReadout.displayParts(range.high, preferences: preferences, fractionDigits: fractionDigits) else {
            return preferences.text("Unavailable")
        }
        if low.number == high.number {
            guard !high.unit.isEmpty else { return high.number }
            return String(format: preferences.text("metric.valueUnit"), locale: preferences.locale, high.number, high.unit)
        }
        guard !high.unit.isEmpty else {
            return String(format: preferences.text("metric.range"), locale: preferences.locale, low.number, high.number)
        }
        return String(format: preferences.text("metric.rangeUnit"), locale: preferences.locale, low.number, high.number, high.unit)
    }
}
