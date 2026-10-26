import SwiftUI
import SwiftData
import Charts
import SwingLabCore

struct PerformanceView: View {
    @Environment(AppPreferences.self) private var preferences
    @Query(sort: \SwingRecording.createdAt) private var recordings: [SwingRecording]
    @Query(sort: \RoundSession.startedAt, order: .reverse) private var rounds: [RoundSession]
    @Query private var clubs: [GolfClub]
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]
    @State private var selection = PerformanceSection.practice

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Picker(preferences.text("Performance category"), selection: $selection) {
                    ForEach(PerformanceSection.allCases) { item in
                        Text(preferences.text(item.rawValue)).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                switch selection {
                case .practice: practice
                case .bag: bag
                case .rounds: roundPerformance
                }
            }
            .padding(24)
        }
        .background(SLTheme.background)
        .navigationTitle(preferences.text("Performance"))
    }

    private var practice: some View {
        // Stored V2 summaries avoid loading or decoding external pose JSON during list/chart rendering.
        let snapshots = recordings.map { TempoSnapshot(recording: $0) }
        let tempoPoints = snapshots.filter { $0.tempo != nil }
        return VStack(alignment: .leading, spacing: 24) {
            if recordings.isEmpty {
                SLEmptyState(title: preferences.text("Progress starts with a baseline."),
                    message: preferences.text("Record or import a swing. Your saved recordings and phase-based tempo will appear here."),
                    symbol: "chart.xyaxis.line")
                NavigationLink { SwingView() } label: {
                    Label(preferences.text("Open Swing"), systemImage: "video")
                }.buttonStyle(.borderedProminent).foregroundStyle(SLTheme.background)
            } else {
                metric(value: ProvenancedValue(value: Double(recordings.count), unit: "1", provenance: .measured,
                    method: "library.savedRecordingCount.v1", sampleCount: recordings.count), label: "Saved swings")
                if tempoPoints.count >= 2 {
                    SLSectionHeader(title: preferences.text("Tempo over time"), subtitle: preferences.text("Backswing ÷ downswing"))
                    // A mixed-source chart retains each source's count instead of implying one provenance for all points.
                    ForEach([Provenance.userEntered, .estimated], id: \.rawValue) { source in
                        let count = tempoPoints.filter { $0.provenance == source }.count
                        if count > 0 { ProvenanceBadge(provenance: source, sampleCount: count) }
                    }
                    Chart(tempoPoints) { recording in
                        if let tempo = recording.tempo {
                            PointMark(
                                x: .value(preferences.text("Date"), recording.createdAt),
                                y: .value(preferences.text("Tempo"), tempo)
                            )
                            .foregroundStyle(SLTheme.forest)
                            .symbolSize(48)
                            .accessibilityLabel(Text(recording.createdAt, format: .dateTime.month().day()))
                            .accessibilityValue(Text(SLMetricReadout.formattedValue(recording.metric,
                                preferences: preferences, fractionDigits: 2, displayAsRatio: true)))
                        }
                    }
                    .frame(height: 210)
                    Text(preferences.text("Tempo depends on address, top, and impact phase markers. Estimated or manually corrected phases are not sensor measurements."))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(preferences.text("Analyze and review phase markers on at least two recordings to compare tempo. Missing measurements stay blank."))
                        .foregroundStyle(.secondary)
                }
                Divider()
                if !sessions.isEmpty {
                    SLSectionHeader(title: preferences.text("Practice sessions"))
                    ForEach(sessions) { session in
                        NavigationLink { PracticeSessionDetailView(session: session) } label: {
                            HStack {
                                Text(session.date, format: .dateTime.month().day().hour().minute())
                                Spacer()
                                ProvenanceBadge(provenance: .measured, sampleCount: session.recordings.count)
                            }
                        }
                    }
                    Divider()
                }
                SLSectionHeader(title: preferences.text("Recent practice"))
                ForEach(Array(snapshots.reversed().prefix(5))) { recording in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recording.title).font(.headline)
                            Text(recording.createdAt, format: .dateTime.month().day().hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 12)
                        if recording.tempo != nil {
                            SLMetricReadout(metric: recording.metric, fractionDigits: 2, displayAsRatio: true)
                        }
                    }
                }
                NavigationLink(preferences.text("View recordings")) { SwingView() }
            }
        }
    }

    private var bag: some View {
        VStack(alignment: .leading, spacing: 24) {
            if carryClubs.isEmpty {
                SLEmptyState(title: preferences.text("Know the spaces between clubs."),
                    message: preferences.text("Add your own carry distances in My Bag to compare club gaps. Unknown distances stay empty."),
                    symbol: "ruler")
            } else {
                SLSectionHeader(title: preferences.text("Club gapping"), subtitle: preferences.text("User-entered average carry"))
                ClubCarryChart(clubs: carryClubs)
                if carryClubs.count >= 2 {
                    ForEach(0..<(carryClubs.count - 1), id: \.self) { index in
                        let longer = carryClubs[index]
                        let shorter = carryClubs[index + 1]
                        HStack(alignment: .firstTextBaseline) {
                            Text(longer.name + " → " + shorter.name).font(.subheadline)
                            Spacer(minLength: 12)
                            SLMetricReadout(metric: ProvenancedValue(
                                value: (longer.carryMeters ?? 0) - (shorter.carryMeters ?? 0), unit: "m",
                                provenance: .userEntered, method: "bag.carryGap.v1"))
                        }
                        Divider()
                    }
                }
                Text(preferences.text("These gaps compare your entered averages. A larger gap is not automatically a problem; consider the shots you need to play."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            NavigationLink { BagView() } label: {
                Label(preferences.text("Manage My Bag"), systemImage: "figure.golf")
            }.buttonStyle(.bordered)
        }
    }

    private var roundPerformance: some View {
        VStack(alignment: .leading, spacing: 24) {
            if rounds.isEmpty {
                SLEmptyState(title: preferences.text("Build a picture of your game."),
                    message: preferences.text("Save a round and fill in your scorecard. Scoring, putts, and penalties will come from your own entries."),
                    symbol: "flag.checkered")
                NavigationLink { CourseView() } label: {
                    Label(preferences.text("Open Course"), systemImage: "map")
                }.buttonStyle(.borderedProminent).foregroundStyle(SLTheme.background)
            } else {
                if !completed18.isEmpty {
                    metric(value: ProvenancedValue(value: scoringAverage, unit: "1", provenance: .userEntered,
                        method: "scorecard.mean18HoleScore.v1", sampleCount: completed18.count),
                        label: "Scoring average · 18 holes", fractionDigits: 1)
                }
                if completed18.count >= 2 {
                    ProvenanceBadge(provenance: .userEntered, sampleCount: completed18.count)
                    Chart(completed18.reversed()) { round in
                        PointMark(x: .value(preferences.text("Date"), round.startedAt),
                                  y: .value(preferences.text("Strokes"), round.totalScore))
                            .foregroundStyle(SLTheme.forest).symbolSize(48)
                            .accessibilityLabel(Text(round.courseName))
                            .accessibilityValue(Text(SLMetricReadout.formattedValue(
                                ProvenancedValue(value: Double(round.totalScore), unit: "1", provenance: .userEntered,
                                                 method: "scorecard.total.v1", sampleCount: round.completedHoleCount),
                                preferences: preferences)))
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 190)
                    Text(preferences.text("Gross scores from fully scored, completed 18-hole rounds. Course difficulty is not adjusted."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                SLSectionHeader(title: preferences.text("Round history"))
                ForEach(Array(rounds.prefix(10))) { round in
                    NavigationLink { ScorecardView(round: round) } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(round.courseName).font(.headline).foregroundStyle(SLTheme.ink)
                                Text(round.startedAt, format: .dateTime.month().day().year())
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(preferences.format("metric.holesScored",
                                    round.completedHoleCount.formatted(.number.locale(preferences.locale)),
                                    round.holeCount.formatted(.number.locale(preferences.locale))))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if round.completedHoleCount > 0 {
                                SLMetricReadout(metric: ProvenancedValue(value: Double(round.totalScore), unit: "1",
                                    provenance: .userEntered, method: "scorecard.total.v1", sampleCount: round.completedHoleCount),
                                    valueFont: .title2.weight(.medium))
                            }
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                }
                NavigationLink(preferences.text("All rounds")) { RoundHistoryView() }
            }
        }
    }

    private func metric(value: ProvenancedValue, label: String, fractionDigits: Int = 0) -> some View {
        SLMetricReadout(metric: value, label: preferences.text(label), fractionDigits: fractionDigits,
                        valueFont: .largeTitle.weight(.medium), alignment: .leading).padding(.vertical, 8)
    }

    private var carryClubs: [GolfClub] {
        clubs.filter { ($0.carryMeters ?? 0) > 0 }.sorted { ($0.carryMeters ?? 0) > ($1.carryMeters ?? 0) }
    }
    private var completed18: [RoundSession] {
        rounds.filter { $0.endedAt != nil && $0.holeCount == 18 && $0.completedHoleCount == 18 }
    }
    private var scoringAverage: Double {
        guard !completed18.isEmpty else { return 0 }
        return Double(completed18.reduce(0) { $0 + $1.totalScore }) / Double(completed18.count)
    }
}

private struct TempoSnapshot: Identifiable {
    let id: UUID
    let title: String
    let createdAt: Date
    let metric: ProvenancedValue
    var tempo: Double? { metric.value }
    var provenance: Provenance? { metric.value == nil ? nil : metric.provenance }

    init(recording: SwingRecording) {
        id = recording.id
        title = recording.title
        createdAt = recording.createdAt
        metric = recording.tempoMetric
    }
}

private enum PerformanceSection: String, CaseIterable, Identifiable {
    case practice = "Practice"
    case bag = "My Bag"
    case rounds = "Rounds"
    var id: String { rawValue }
}
