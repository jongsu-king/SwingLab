import SwiftUI
import SwiftData
import Charts
import SwingLabCore

struct BagView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GolfClub.createdAt) private var clubs: [GolfClub]
    @State private var addingClub = false
    @State private var pendingDeletion: GolfClub?
    @State private var showingDeleteConfirmation = false
    @State private var showingStorageError = false

    var body: some View {
        Group {
            if clubs.isEmpty {
                VStack(spacing: 24) {
                    SLEmptyState(
                        title: preferences.text("Every club has a purpose."),
                        message: preferences.text("Build your bag with the clubs you play. Add your own carry distances to make course planning personal."),
                        symbol: "figure.golf"
                    )
                    .padding(.horizontal, 28)
                    Button { addingClub = true } label: {
                        Label(preferences.text("Add your first club"), systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).foregroundStyle(SLTheme.background)
                    .controlSize(.large)
                    .padding(.horizontal, 28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !measuredClubs.isEmpty {
                        Section {
                            ClubCarryChart(clubs: measuredClubs)
                                .listRowBackground(Color.clear)
                        } header: { Text(preferences.text("Your carry distances")) }
                        footer: { Text(preferences.text("User-entered averages. Distances are not camera or GPS measurements.")) }
                    }
                    ForEach(ClubCategory.allCases) { category in
                        let members = clubs.filter { $0.category == category.rawValue }
                        if !members.isEmpty {
                            Section(preferences.text(category.localizationKey)) {
                                ForEach(members) { club in
                                    NavigationLink { ClubDetailView(club: club) } label: {
                                        clubRow(club)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            pendingDeletion = club
                                            showingDeleteConfirmation = true
                                        } label: { Label(preferences.text("Delete"), systemImage: "trash") }
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(SLTheme.background)
        .navigationTitle(preferences.text("My Bag"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { addingClub = true } label: {
                    Image(systemName: "plus").accessibilityLabel(preferences.text("Add club"))
                }.accessibilityIdentifier("bag.add")
            }
        }
        .sheet(isPresented: $addingClub) { ClubEditorView() }
        .alert(preferences.text("Delete this club?"), isPresented: $showingDeleteConfirmation) {
            Button(preferences.text("Cancel"), role: .cancel) { pendingDeletion = nil }
            Button(preferences.text("Delete"), role: .destructive, action: deleteClub)
        } message: { Text(preferences.text("This removes the club from your bag. Recorded rounds and videos are kept.")) }
        .alert(preferences.text("Could not delete club"), isPresented: $showingStorageError) {
            Button(preferences.text("OK"), role: .cancel) {}
        } message: { Text(preferences.text("Your club is still in your bag. Try again.")) }
    }

    private var measuredClubs: [GolfClub] {
        clubs.filter { ($0.carryMeters ?? 0) > 0 }
            .sorted { ($0.carryMeters ?? 0) > ($1.carryMeters ?? 0) }
    }

    private func clubRow(_ club: GolfClub) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(club.name).font(.headline)
                if !club.brand.isEmpty || !club.modelName.isEmpty {
                    Text([club.brand, club.modelName].filter { !$0.isEmpty }.joined(separator: " "))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let carry = club.carryMeters {
                SLMetricReadout(metric: ProvenancedValue(value: carry, unit: "m", provenance: .userEntered,
                                                        method: "bag.averageCarry.v1"))
            } else {
                Text(preferences.text("Add carry")).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }

    private func deleteClub() {
        guard let club = pendingDeletion else { return }
        modelContext.delete(club)
        do { try modelContext.save() }
        catch {
            modelContext.rollbackPendingChanges()
            showingStorageError = true
        }
        pendingDeletion = nil
    }
}

struct ClubCarryChart: View {
    @Environment(AppPreferences.self) private var preferences
    let clubs: [GolfClub]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProvenanceBadge(provenance: .userEntered, sampleCount: clubs.count)
            Chart(clubs) { club in
                if let carry = club.carryMeters {
                    BarMark(
                        x: .value(preferences.text("Carry"), preferences.distanceUnit.fromSI(carry)),
                        y: .value(preferences.text("Club"), club.id.uuidString)
                    )
                    .foregroundStyle(SLTheme.forest)
                    .cornerRadius(2)
                    .accessibilityLabel(Text(club.name))
                    .accessibilityValue(Text(SLMetricReadout.formattedValue(
                        ProvenancedValue(value: carry, unit: "m", provenance: .userEntered, method: "bag.averageCarry.v1"),
                        preferences: preferences)))
                }
            }
            .chartYScale(domain: clubs.map { $0.id.uuidString })
            .chartYAxis {
                AxisMarks(position: .leading, values: clubs.map { $0.id.uuidString }) { value in
                    AxisValueLabel {
                        if let id = value.as(String.self), let club = clubs.first(where: { $0.id.uuidString == id }) {
                            Text(club.name).font(.caption)
                        }
                    }
                }
            }
            .chartXAxisLabel(preferences.distanceUnit.symbol)
            .frame(height: max(150, CGFloat(clubs.count) * 32 + 40))
            .padding(.vertical, 12)
        }
    }
}
