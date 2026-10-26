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
            ProvenanceBadge(provenance: metric.value == nil ? .unavailable : metric.provenance,
                            sampleCount: metric.sampleCount)
        }
        .accessibilityElement(children: .combine)
    }

    static func formattedValue(_ metric: ProvenancedValue, preferences: AppPreferences,
                               fractionDigits: Int = 0, displayAsPercent: Bool = false,
                               displayAsRatio: Bool = false) -> String {
        guard let value = metric.value, value.isFinite, metric.provenance != .unavailable else {
            return preferences.text("Unavailable")
        }
        if displayAsPercent {
            return value.formatted(.percent.precision(.fractionLength(fractionDigits)).locale(preferences.locale))
        }
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
        case "1":
            displayValue = value
            displayUnit = ""
        default:
            displayValue = value
            displayUnit = metric.unit
        }
        let number = displayValue.formatted(.number.precision(.fractionLength(fractionDigits)).locale(preferences.locale))
        if displayAsRatio {
            return String(format: preferences.text("metric.ratio"), locale: preferences.locale, number)
        }
        guard !displayUnit.isEmpty else { return number }
        return String(format: preferences.text("metric.valueUnit"), locale: preferences.locale, number, displayUnit)
    }
}
