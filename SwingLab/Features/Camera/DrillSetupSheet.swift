import SwiftUI
import SwingLabCore

/// Chooses a target or ladder drill. Distances are typed in the display unit and stored in metres.
struct DrillSetupSheet: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.dismiss) private var dismiss
    let onStart: (DrillSession) -> Void
    @State private var kind = DrillKind.target
    @State private var targetDistance: Double? = 150
    @State private var tolerance: Double? = 10
    @State private var ladderStart: Double? = 60
    @State private var ladderStep: Double? = 20
    @State private var rungs = 5

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(prefs.text("Drill"), selection: $kind) {
                        ForEach(DrillKind.allCases) { kind in Text(prefs.text(kind.localizationKey)).tag(kind) }
                    }.pickerStyle(.segmented)
                }
                Section {
                    if kind == .target {
                        field("Target distance", $targetDistance)
                    } else {
                        field("Start distance", $ladderStart)
                        field("Step", $ladderStep)
                        Stepper(value: $rungs, in: 2...12) {
                            HStack { Text(prefs.text("Rungs")); Spacer(); Text(rungs.formatted(.number.locale(prefs.locale))).monospacedDigit() }
                        }
                    }
                    field("Tolerance (±)", $tolerance)
                } footer: {
                    Text(prefs.text("Drills are scored on the simulated carry bracket for the chosen club. They are a practice game, not a measurement of where the ball landed."))
                }
            }
            .scrollContentBackground(.hidden).background(SLTheme.background)
            .navigationTitle(prefs.text("Start a drill"))
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton(prefs.text("Done"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(prefs.text("Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(prefs.text("Start")) {
                        if let session { onStart(session); dismiss() }
                    }.disabled(session == nil)
                }
            }
        }
    }

    private func field(_ key: LocalizationKey, _ value: Binding<Double?>) -> some View {
        HStack {
            Text(prefs.text(key))
            Spacer(minLength: 12)
            TextField(prefs.text("Unset"), value: value, format: .number.locale(prefs.locale))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).monospacedDigit().frame(maxWidth: 96)
            Text(prefs.distanceUnit.symbol).font(.subheadline).foregroundStyle(.secondary).frame(minWidth: 34, alignment: .leading)
        }
    }

    /// nil until the inputs make a valid drill.
    private var session: DrillSession? {
        guard let tolerance, tolerance >= 0 else { return nil }
        let unit = prefs.distanceUnit
        switch kind {
        case .target:
            guard let targetDistance, targetDistance > 0 else { return nil }
            return DrillSession(target: DrillTarget(distance: unit.toSI(targetDistance), tolerance: unit.toSI(tolerance)))
        case .ladder:
            guard let ladderStart, let ladderStep,
                  let ladder = LadderDrill(start: unit.toSI(ladderStart), step: unit.toSI(ladderStep), rungs: rungs, tolerance: unit.toSI(tolerance)) else { return nil }
            return DrillSession(ladder: ladder)
        }
    }
}
