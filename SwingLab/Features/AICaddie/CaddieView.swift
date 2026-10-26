import SwiftUI
import SwingLabCore

enum CaddieStrategy: String, CaseIterable, Identifiable {
    case conservative = "Conservative"
    case balanced = "Balanced"
    case aggressive = "Aggressive"
    var id: String { rawValue }
    var variabilityWeight: Double {
        switch self {
        case .conservative: 2
        case .balanced: 1
        case .aggressive: 0.5
        }
    }
}

struct CaddieCandidate: Identifiable {
    let club: GolfClub
    let errorScore: Double
    let remainingMeters: Double
    var id: UUID { club.id }
}

@MainActor
enum CaddieRules {
    /// Lower score means a smaller target error with the selected variance penalty.
    /// The score is not a probability, strokes-gained value, or hazard-risk assessment.
    static func rank(clubs: [GolfClub], targetDistance: Double, strategy: CaddieStrategy) -> [CaddieCandidate] {
        let profiles = clubs.compactMap { club -> ClubProfile? in
            guard let carry = club.carryMeters, let forwardSD = club.carryStdDevMeters,
                  let rightSD = club.lateralStdDevMeters else { return nil }
            return ClubProfile(id: club.id, carry: carry, lateralMean: club.lateralMeanMeters,
                               carrySD: forwardSD, lateralSD: rightSD)
        }
        return RecommendationEngine.rank(profiles: profiles, targetDistance: targetDistance,
                                         varianceWeight: strategy.variabilityWeight).compactMap { result in
            guard let club = clubs.first(where: { $0.id == result.id }) else { return nil }
            return CaddieCandidate(club: club, errorScore: result.score, remainingMeters: result.remaining)
        }
    }
}

struct CaddieView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    let clubs: [GolfClub]
    let targetDistance: Double
    let selectClub: (GolfClub) -> Void
    @State private var strategy: CaddieStrategy = .balanced

    private var candidates: [CaddieCandidate] { CaddieRules.rank(clubs: clubs, targetDistance: targetDistance, strategy: strategy) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(preferences.text("Strategy"), selection: $strategy) {
                        ForEach(CaddieStrategy.allCases) { strategy in Text(preferences.text(strategy.rawValue)).tag(strategy) }
                    }
                    LabeledContent(preferences.text("Target distance"), value: preferences.distance(targetDistance))
                }
                if candidates.isEmpty {
                    SLEmptyState(title: preferences.text("Build your club profile"),
                                 message: preferences.text("Add carry and both variability values in My Bag to compare clubs."), symbol: "figure.golf")
                } else {
                    Section(preferences.text("Club recommendations")) {
                        ForEach(Array(candidates.prefix(3).enumerated()), id: \.element.id) { index, candidate in
                            Button {
                                selectClub(candidate.club)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(candidate.club.name).font(.headline)
                                        Spacer()
                                        if index == 0 { Text(preferences.text("Recommended")).font(.caption).foregroundStyle(SLTheme.forest) }
                                    }
                                    Text(preferences.text("Expected distance from target") + ": " + preferences.distance(candidate.remainingMeters))
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 5)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Section(preferences.text("How this works")) {
                    Text(preferences.text("Clubs are ranked by squared distance from the target plus carry and lateral variability. Conservative gives variability more weight; aggressive gives it less."))
                    Text(preferences.text("This is a statistical estimate from your entered club profile. Wind, elevation, lie, roll and hazard geometry are unavailable. Check the landing area before choosing a shot."))
                    Text(preferences.text("Hazard probabilities and safer aim points require verified course geometry and are unavailable."))
                }.font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle(preferences.text("Caddie"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(preferences.text("Done")) { dismiss() } } }
        }
    }
}
