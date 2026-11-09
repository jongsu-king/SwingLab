import SwiftUI
import Charts
import SwingLabCore

/// Launch values are typed by the user, never taken from video. Every output is simulated,
/// and the trajectory is dashed so it cannot be mistaken for an observed tracer.
struct HypotheticalFlightView: View {
    @Environment(AppPreferences.self) private var prefs
    /// Launch values to start from (a logged measurement); once in the form they are inputs like any other.
    var seed: LaunchConditions? = nil
    @State private var seeded = false
    @State private var ballSpeed: Double?
    @State private var launchAngle: Double?
    @State private var startDirection: Double? = 0
    @State private var spinRate: Double?
    @State private var spinAxis: Double? = 0
    @State private var tailwind: Double? = 0
    @State private var crosswind: Double? = 0
    @State private var temperature: Double?
    @State private var pressure: Double? = Atmosphere.standard.pressure / 100
    @State private var humidity: Double? = Atmosphere.standard.relativeHumidity * 100
    @State private var landingHeight: Double? = 0
    @State private var shapePreset: ShotShape?
    @State private var result: FlightResult?
    @State private var simulatedLaunch: LaunchConditions?
    @State private var run: RollResult?
    @State private var errorKey: LocalizationKey?

    var body: some View {
        Form {
            Section {
                Text(prefs.text("Simulate a ball flight from launch values you enter. SwingLab does not measure these from video."))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section(prefs.text("Launch")) {
                field("Ball speed", $ballSpeed, unit: prefs.speedUnit.symbol)
                field("Launch angle", $launchAngle, unit: "°")
                field("Start direction (right +)", $startDirection, unit: "°", signed: true)
                field("Spin rate", $spinRate, unit: "rpm")
                field("Spin axis (right curve +)", $spinAxis, unit: "°", signed: true)
                // A preset only fills the two lateral inputs above; it is a starting point to edit.
                Picker(prefs.text("Shot shape"), selection: $shapePreset) {
                    Text(prefs.text("Custom")).tag(ShotShape?.none)
                    ForEach(ShotShape.allCases) { shape in Text(prefs.text(shape.localizationKey)).tag(ShotShape?.some(shape)) }
                }.accessibilityIdentifier("flight.shapePreset")
                Button(prefs.text("Fill tour-average driver example")) {
                    ballSpeed = (prefs.speedUnit.fromSI(167 * 0.44704) * 10).rounded() / 10
                    launchAngle = 10.9; spinRate = 2686; startDirection = 0; spinAxis = 0
                }.accessibilityIdentifier("flight.driverExample")
            }
            Section(prefs.text("Conditions")) {
                field("Tailwind (headwind −)", $tailwind, unit: prefs.windUnit.symbol, signed: true)
                field("Crosswind (left to right +)", $crosswind, unit: prefs.windUnit.symbol, signed: true)
                field("Temperature", $temperature, unit: prefs.temperatureUnit.symbol, signed: true)
                field("Air pressure", $pressure, unit: "hPa")
                field("Humidity", $humidity, unit: "%")
                field("Landing height (above tee +)", $landingHeight, unit: prefs.distanceUnit.symbol, signed: true)
            }
            Section {
                Button(action: simulate) {
                    Text(prefs.text("Simulate")).frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).foregroundStyle(SLTheme.background).tint(SLTheme.forest)
                    .accessibilityIdentifier("flight.simulate")
                if let errorKey {
                    Text(prefs.text(errorKey)).font(.caption).foregroundStyle(.secondary)
                }
            }.listRowBackground(Color.clear)
            if let result { resultSection(result) }
        }
        .scrollContentBackground(.hidden).background(SLTheme.background)
        .navigationTitle(prefs.text("Hypothetical flight"))
        .keyboardDoneButton(prefs.text("Done"))
        .onChange(of: [ballSpeed, launchAngle, startDirection, spinRate, spinAxis, tailwind, crosswind,
                       temperature, pressure, humidity, landingHeight]) { _, _ in
            // A result belongs to the submitted inputs, not subsequently edited fields.
            result = nil; simulatedLaunch = nil; run = nil; errorKey = nil
            // Editing either lateral input away from the preset makes the shape custom again.
            if let shapePreset {
                let preset = shapePreset.preset(for: prefs.handedness)
                if startDirection != preset.launchDirection || spinAxis != preset.spinAxis { self.shapePreset = nil }
            }
        }
        .onChange(of: shapePreset) { _, preset in
            guard let preset else { return }
            let values = preset.preset(for: prefs.handedness)
            startDirection = values.launchDirection; spinAxis = values.spinAxis
        }
        .onAppear {
            if temperature == nil {
                temperature = (prefs.temperatureUnit.fromSI(Atmosphere.standard.temperature) * 10).rounded() / 10
            }
            if let seed, !seeded {
                seeded = true
                ballSpeed = (prefs.speedUnit.fromSI(seed.ballSpeed) * 10).rounded() / 10
                launchAngle = (seed.launchAngle * 10).rounded() / 10
                spinRate = seed.spinRate.rounded()
                startDirection = seed.launchDirection; spinAxis = seed.spinAxis
            }
        }
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

    private func resultSection(_ result: FlightResult) -> some View {
        Section(prefs.text("Result")) {
            FlightSceneView(playback: FlightPlayback(samples: result.trajectory, run: run?.run ?? 0),
                            shape: simulatedLaunch.flatMap { ShotShapeClassifier.classify(launch: $0, result: result, handedness: prefs.handedness) },
                            height: 200)
                .padding(.vertical, 6)
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 14) {
                GridRow {
                    SLMetricReadout(metric: result.carryMetric, label: prefs.text("Carry"), fractionDigits: 1, alignment: .leading)
                        .accessibilityIdentifier("flight.result.carry")
                    SLMetricReadout(metric: totalMetric(result), label: prefs.text("Total"), fractionDigits: 1, alignment: .leading)
                }
                GridRow {
                    SLMetricReadout(metric: result.lateralMetric, label: prefs.text("Lateral (right +)"), fractionDigits: 1, alignment: .leading)
                    SLMetricReadout(metric: result.apexMetric, label: prefs.text("Apex"), fractionDigits: 1, alignment: .leading)
                }
                GridRow {
                    SLMetricReadout(metric: result.flightTimeMetric, label: prefs.text("Flight time"), fractionDigits: 2, alignment: .leading)
                    SLMetricReadout(metric: result.landingAngleMetric, label: prefs.text("Landing angle"), fractionDigits: 1, alignment: .leading)
                }
            }.padding(.vertical, 6)
            trajectoryChart(result, title: "Side view", vertical: \.height, verticalLabel: "Height")
            trajectoryChart(result, title: "Top view", vertical: \.right, verticalLabel: "Lateral (right +)")
            Text(prefs.text("Experimental aerodynamic approximation. Total adds a bounce-and-roll model for an assumed fairway. Height, carry, and curve can differ substantially from real shots."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Carry plus the simulated run; unavailable when the roll model refused the landing.
    private func totalMetric(_ result: FlightResult) -> ProvenancedValue {
        ProvenancedValue(value: run.map { result.carry + $0.run }, unit: "m", provenance: run == nil ? .unavailable : .simulated,
                         method: LaunchReadoutBuilder.totalMethod)
    }

    private func trajectoryChart(_ result: FlightResult, title: LocalizationKey, vertical: KeyPath<FlightSample, Double>,
                                 verticalLabel: LocalizationKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prefs.text(title)).font(.subheadline.weight(.medium))
            Chart(result.trajectory, id: \.time) { sample in
                LineMark(x: .value(prefs.text("Carry"), prefs.distanceUnit.fromSI(sample.forward)),
                         y: .value(prefs.text(verticalLabel), prefs.distanceUnit.fromSI(sample[keyPath: vertical])))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .foregroundStyle(SLTheme.forest)
            }
            .chartXAxisLabel(prefs.text("Carry") + " (" + prefs.distanceUnit.symbol + ")")
            .chartYAxisLabel(prefs.text(verticalLabel) + " (" + prefs.distanceUnit.symbol + ")")
            .frame(height: 150)
            .accessibilityLabel(prefs.text(title))
        }.padding(.vertical, 4)
    }

    private func simulate() {
        guard let ballSpeed, let launchAngle, let startDirection, let spinRate, let spinAxis, let tailwind, let crosswind,
              let temperature, let pressure, let humidity, let landingHeight else {
            result = nil; errorKey = "Fill in every value to simulate."; return
        }
        let launch = LaunchConditions(ballSpeed: prefs.speedUnit.toSI(ballSpeed), launchAngle: launchAngle,
                                      launchDirection: startDirection, spinRate: spinRate, spinAxis: spinAxis)
        let atmosphere = Atmosphere(temperature: prefs.temperatureUnit.toSI(temperature), pressure: pressure * 100,
                                    relativeHumidity: humidity / 100)
        let wind = Wind(tailwind: prefs.windUnit.toSI(tailwind), rightward: prefs.windUnit.toSI(crosswind))
        do {
            let flight = try BallFlight.simulate(launch, atmosphere: atmosphere, wind: wind,
                                                 landingHeight: prefs.distanceUnit.toSI(landingHeight))
            result = flight
            simulatedLaunch = launch
            run = try? BallRoll.run(landingSpeed: flight.landingSpeed, landingAngleDegrees: max(0, flight.landingAngle),
                                    landingSpinRate: flight.landingSpinRate)
            errorKey = nil
        } catch ModelError.insufficientData {
            result = nil; simulatedLaunch = nil; run = nil; errorKey = "The ball does not come down to that landing height."
        } catch {
            result = nil; simulatedLaunch = nil; run = nil; errorKey = "These values are outside the model's supported range."
        }
    }
}
