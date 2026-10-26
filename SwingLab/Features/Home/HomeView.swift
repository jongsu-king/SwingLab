import SwiftUI
import SwiftData
import Charts
import SwingLabCore

struct HomeView: View {
    @Environment(AppPreferences.self) private var preferences
    @Binding var selection: AppTab
    @Query(sort: \SwingRecording.createdAt, order: .reverse) private var recordings: [SwingRecording]
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]
    @Query(sort: \RoundSession.startedAt, order: .reverse) private var rounds: [RoundSession]
    @Query private var clubs: [GolfClub]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SLTheme.Space.lg) {
                Button { selection = .swing } label: {
                    Label(preferences.text("Record & review"), systemImage: "video")
                        .font(SLTheme.TypeScale.headline).frame(maxWidth: .infinity).padding(.vertical, SLTheme.Space.sm)
                }
                .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: SLTheme.cornerRadius))
                .foregroundStyle(SLTheme.background).controlSize(.large)
                .accessibilityIdentifier("home.record")

                if let session = sessions.first {
                    VStack(alignment: .leading, spacing: SLTheme.Space.md) {
                        SLSectionHeader(title: preferences.text("Last practice"))
                        NavigationLink { PracticeSessionDetailView(session: session) } label: {
                            SLListRow(title: session.date.formatted(date: .abbreviated, time: .shortened),
                                detail: preferences.format("count.swings", session.recordings.count), symbol: "play.rectangle")
                        }
                        if let summary = CoachingEngine.consistency(.tempo, in: session.recordings.map(\.coachingSample)) {
                            SLMetricReadout(metric: .init(value: summary.mean, unit: "1", provenance: .estimated,
                                method: "home.sessionTempoMean.v1", sampleCount: summary.count),
                                label: preferences.text("Tempo ratio"), fractionDigits: 2, displayAsRatio: true, alignment: .leading)
                        }
                    }
                    Divider()
                }
                if let round = rounds.first(where: { $0.endedAt == nil }) {
                    VStack(alignment: .leading, spacing: SLTheme.Space.md) {
                        SLSectionHeader(title: preferences.text("Current round"))
                        NavigationLink { ScorecardView(round: round) } label: {
                            SLListRow(title: round.courseName, detail: preferences.format("count.holes", round.completedHoleCount), symbol: "flag")
                        }
                        if round.completedHoleCount > 0 {
                            SLMetricReadout(metric: .init(value: Double(round.totalScore), unit: "1", provenance: .userEntered,
                                method: "scorecard.total.v1", sampleCount: round.completedHoleCount), alignment: .leading)
                        }
                    }
                    Divider()
                }
                if trend.count >= 5 {
                    VStack(alignment: .leading, spacing: SLTheme.Space.sm) {
                        SLSectionHeader(title: preferences.text("Tempo trend"), subtitle: preferences.format("count.swings", trend.count))
                        Chart(trend) { recording in
                            if let value = recording.tempoRatio {
                                LineMark(x: .value(preferences.text("Date"), recording.createdAt),
                                         y: .value(preferences.text("Tempo ratio"), value))
                                PointMark(x: .value(preferences.text("Date"), recording.createdAt),
                                          y: .value(preferences.text("Tempo ratio"), value))
                            }
                        }.frame(height: 140).foregroundStyle(SLTheme.forest)
                        SLInlineNotice(message: preferences.text("Same club and camera angle. Review estimated phase markers."), symbol: "info.circle")
                        ProvenanceBadge(provenance: .estimated, sampleCount: trend.count)
                    }
                    Divider()
                }
                if recordings.isEmpty {
                    VStack(alignment: .leading, spacing: SLTheme.Space.sm) {
                        Text(preferences.text("Your first recording")).font(SLTheme.TypeScale.headline)
                        Text(preferences.text("Record a swing to begin your practice history."))
                            .font(SLTheme.TypeScale.body).foregroundStyle(SLTheme.secondaryInk)
                    }
                }
                VStack(alignment: .leading, spacing: SLTheme.Space.md) {
                    NavigationLink { BagView() } label: {
                        SLListRow(title: preferences.text("My Bag"),
                            detail: preferences.text(clubs.isEmpty ? "Start with the clubs you trust." : "Review your distances and gaps."), symbol: "figure.golf")
                    }.accessibilityIdentifier("home.bag")
                    Divider()
                    Button { selection = .course } label: {
                        SLListRow(title: preferences.text("Plan a round"),
                            detail: preferences.text("Find a course or choose your own target."), symbol: "map")
                    }
                }
            }.padding(SLTheme.Space.lg)
        }
        .background(SLTheme.background).navigationTitle("SwingLab")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink { SettingsView() } label: {
                    Image(systemName: "gearshape").accessibilityLabel(preferences.text("Settings"))
                }.accessibilityIdentifier("home.settings")
            }
        }
    }

    // Cached columns only; never decode pose payloads for the Home trend.
    private var trend: [SwingRecording] {
        guard let latest = recordings.first(where: { $0.tempoRatio != nil && $0.cameraAngleValue != .unspecified }) else { return [] }
        return Array(recordings.filter { $0.tempoRatio != nil && $0.clubID == latest.clubID && $0.cameraAngleValue == latest.cameraAngleValue }.prefix(20).reversed())
    }
}
