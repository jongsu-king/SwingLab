import SwiftUI
import SwingLabCore

/// Air and wind for the readout's simulations: temperature, altitude, humidity, and wind along and
/// across the target line, typed in the display units. Nothing here is measured by the phone; the
/// carry and total tiles stay simulated and simply adopt these entries.
struct RangeConditionsSheet: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.dismiss) private var dismiss
    @State private var temperature: Double?
    @State private var altitude: Double?
    @State private var humidity: Double?
    @State private var tailwind: Double?
    @State private var crosswind: Double?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    field("Temperature", $temperature, unit: prefs.temperatureUnit.symbol, signed: true)
                    field("Altitude", $altitude, unit: altitudeSymbol, signed: true)
                    field("Humidity", $humidity, unit: "%")
                    LabeledContent(prefs.text("Air pressure"), value: pressureText)
                } header: { Text(prefs.text("Air")) }
                footer: { Text(prefs.text("Pressure follows from the altitude with the standard atmosphere.")) }
                Section {
                    field("Tailwind (headwind −)", $tailwind, unit: prefs.windUnit.symbol, signed: true)
                    field("Crosswind (left to right +)", $crosswind, unit: prefs.windUnit.symbol, signed: true)
                } header: { Text(prefs.text("Wind")) }
                footer: { Text(prefs.text("Conditions are your own entries; the phone does not measure them. Carry and total stay simulated and adopt these values.")) }
                Section {
                    Button(prefs.text("Reset to standard conditions")) { load(.standard) }
                } footer: { Text(prefs.text("Standard: 20 °C at sea level, 50 % humidity, calm.")) }
            }
            .scrollContentBackground(.hidden).background(SLTheme.background)
            .navigationTitle(prefs.text("Conditions"))
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton(prefs.text("Done"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(prefs.text("Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(prefs.text("Save")) {
                        if let conditions { prefs.rangeConditions = conditions }
                        dismiss()
                    }.disabled(conditions == nil)
                }
            }
            .onAppear { if !loaded { load(prefs.rangeConditions); loaded = true } }
        }
    }

    private var altitudeSymbol: String { prefs.distanceUnit == .meters ? "m" : "ft" }
    private func altitudeFromSI(_ metres: Double) -> Double { prefs.distanceUnit == .meters ? metres : metres / 0.3048 }
    private func altitudeToSI(_ value: Double) -> Double { prefs.distanceUnit == .meters ? value : value * 0.3048 }

    private var pressureText: String {
        guard let altitude else { return prefs.text("Unavailable") }
        let hectopascals = Atmosphere.pressure(atAltitude: altitudeToSI(altitude)) / 100
        return String(format: prefs.text("metric.valueUnit"), locale: prefs.locale,
                      hectopascals.formatted(.number.precision(.fractionLength(0)).locale(prefs.locale)), "hPa")
    }

    /// nil until every field is filled and the model accepts the values.
    private var conditions: RangeConditions? {
        guard let temperature, let altitude, let humidity, let tailwind, let crosswind else { return nil }
        let conditions = RangeConditions(temperatureKelvin: prefs.temperatureUnit.toSI(temperature), altitudeMetres: altitudeToSI(altitude),
                                         relativeHumidity: humidity / 100, tailwind: prefs.windUnit.toSI(tailwind),
                                         crosswind: prefs.windUnit.toSI(crosswind))
        return conditions.isValid ? conditions : nil
    }

    private func load(_ conditions: RangeConditions) {
        temperature = (prefs.temperatureUnit.fromSI(conditions.temperatureKelvin) * 10).rounded() / 10
        altitude = altitudeFromSI(conditions.altitudeMetres).rounded()
        humidity = (conditions.relativeHumidity * 100).rounded()
        tailwind = (prefs.windUnit.fromSI(conditions.tailwind) * 10).rounded() / 10
        crosswind = (prefs.windUnit.fromSI(conditions.crosswind) * 10).rounded() / 10
    }

    private func field(_ key: LocalizationKey, _ value: Binding<Double?>, unit: String, signed: Bool = false) -> some View {
        HStack {
            Text(prefs.text(key))
            Spacer(minLength: 12)
            TextField(prefs.text("Unset"), value: value, format: .number.locale(prefs.locale))
                .keyboardType(signed ? .numbersAndPunctuation : .decimalPad)
                .multilineTextAlignment(.trailing).monospacedDigit().frame(maxWidth: 96)
            Text(unit).font(.subheadline).foregroundStyle(.secondary).frame(minWidth: 34, alignment: .leading)
        }
    }

    /// One line for the live panel: temperature, pressure, and wind in the display units.
    static func summary(_ conditions: RangeConditions, preferences: AppPreferences) -> String {
        let temperature = SLMetricReadout.formattedValue(
            ProvenancedValue(value: conditions.temperatureKelvin, unit: "K", provenance: .userEntered, method: "conditions.entered.v1"),
            preferences: preferences)
        let pressure = String(format: preferences.text("metric.valueUnit"), locale: preferences.locale,
                              (conditions.pressure / 100).formatted(.number.precision(.fractionLength(0)).locale(preferences.locale)), "hPa")
        let wind: String
        if conditions.tailwind == 0 && conditions.crosswind == 0 {
            wind = preferences.text("Calm")
        } else {
            let along = preferences.windUnit.fromSI(conditions.tailwind), across = preferences.windUnit.fromSI(conditions.crosswind)
            wind = preferences.format("conditions.wind", along.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always()).locale(preferences.locale)),
                                      across.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always()).locale(preferences.locale)),
                                      preferences.windUnit.symbol)
        }
        return preferences.format("conditions.summary", temperature, pressure, wind)
    }
}
