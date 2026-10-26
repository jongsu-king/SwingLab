import SwiftUI
import SwingLabCore

struct ClubDetailView: View {
    @Environment(AppPreferences.self) private var preferences
    let club: GolfClub
    @State private var editing = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 9) {
                    Text(preferences.text("AVERAGE CARRY"))
                        .font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(.secondary)
                    SLMetricReadout(metric: ProvenancedValue(value: club.carryMeters, unit: "m", provenance: .userEntered,
                        method: "bag.averageCarry.v1"), valueFont: .largeTitle.weight(.medium), alignment: .leading)
                }
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }
            Section(preferences.text("Equipment")) {
                if let category = ClubCategory(rawValue: club.category) {
                    row("Category", preferences.text(category.localizationKey))
                } else {
                    row("Category", club.category)
                }
                if !club.brand.isEmpty { row("Brand", club.brand) }
                if !club.modelName.isEmpty { row("Model", club.modelName) }
                if let loft = club.loftDegrees {
                    metricRow("Loft", value: loft * .pi / 180, unit: "rad", method: "bag.loft.v1", fractionDigits: 1)
                }
                if !club.shaft.isEmpty { row("Shaft", club.shaft) }
                if !club.flex.isEmpty { row("Flex", club.flex) }
            }
            Section {
                NavigationLink { ClubProfileView(club: club) } label: {
                    Label(preferences.text("Club profile"), systemImage: "chart.xyaxis.line")
                }
            }
            Section {
                if let total = club.totalMeters { metricRow("Average total distance", value: total, method: "bag.averageTotal.v1") }
                if let deviation = club.carryStdDevMeters { metricRow("Carry standard deviation", value: deviation, method: "bag.carrySD.v1") }
                if let deviation = club.lateralStdDevMeters { metricRow("Lateral standard deviation", value: deviation, method: "bag.lateralSD.v1") }
                if club.lateralMeanMeters != 0 { metricRow("Typical lateral offset", value: club.lateralMeanMeters, method: "bag.lateralMean.v1") }
                if club.dispersionCorrelation != 0 {
                    metricRow("Carry / lateral correlation", value: club.dispersionCorrelation, unit: "1",
                              method: "bag.correlation.v1", fractionDigits: 2)
                }
            } header: { Text(preferences.text("Distance & dispersion")) }
            footer: { Text(preferences.text("Personal estimates remain separate from recorded GPS displacement and camera analysis.")) }
            if !club.notes.isEmpty {
                Section(preferences.text("Notes")) { Text(club.notes) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(SLTheme.background)
        .navigationTitle(club.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(preferences.text("Edit")) { editing = true }
            }
        }
        .sheet(isPresented: $editing) { ClubEditorView(club: club) }
    }

    private func row(_ label: LocalizationKey, _ value: String) -> some View {
        LabeledContent(preferences.text(label)) {
            Text(value).monospacedDigit().multilineTextAlignment(.trailing)
        }
    }

    private func metricRow(_ label: LocalizationKey, value: Double, unit: String = "m", method: String,
                           fractionDigits: Int = 0) -> some View {
        LabeledContent(preferences.text(label)) {
            SLMetricReadout(metric: ProvenancedValue(value: value, unit: unit, provenance: .userEntered, method: method),
                            fractionDigits: fractionDigits)
        }
    }
}
