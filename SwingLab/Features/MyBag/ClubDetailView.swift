import SwiftUI

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
                    if let carry = club.carryMeters {
                        Text(preferences.distance(carry)).font(.system(.largeTitle, design: .rounded).weight(.medium)).monospacedDigit()
                    } else {
                        Text(preferences.text("Not entered")).font(.title2)
                    }
                    Text(preferences.text("User-entered")).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }
            Section(preferences.text("Equipment")) {
                row("Category", preferences.text(club.category))
                if !club.brand.isEmpty { row("Brand", club.brand) }
                if !club.modelName.isEmpty { row("Model", club.modelName) }
                if let loft = club.loftDegrees {
                    row("Loft", loft.formatted(.number.locale(preferences.locale).precision(.fractionLength(0...1))) + "°")
                }
                if !club.shaft.isEmpty { row("Shaft", club.shaft) }
                if !club.flex.isEmpty { row("Flex", club.flex) }
            }
            Section {
                if let total = club.totalMeters { row("Average total distance", preferences.distance(total)) }
                if let deviation = club.carryStdDevMeters { row("Carry standard deviation", preferences.distance(deviation)) }
                if let deviation = club.lateralStdDevMeters { row("Lateral standard deviation", preferences.distance(deviation)) }
                if club.lateralMeanMeters != 0 { row("Typical lateral offset", preferences.distance(club.lateralMeanMeters)) }
                if club.dispersionCorrelation != 0 {
                    row("Carry / lateral correlation", club.dispersionCorrelation.formatted(.number.locale(preferences.locale).precision(.fractionLength(0...2))))
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

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(preferences.text(label)) {
            Text(value).monospacedDigit().multilineTextAlignment(.trailing)
        }
    }
}
