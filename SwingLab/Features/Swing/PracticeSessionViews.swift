import SwiftUI
import SwiftData
import SwingLabCore

/// Embedded in swing detail. Every edit is saved explicitly and rolled back on failure.
struct RecordingPracticeSection: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.modelContext) private var context
    @Bindable var recording: SwingRecording
    @Query(sort: \GolfClub.createdAt) private var clubs: [GolfClub]
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]
    @State private var saveFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SLSectionHeader(title: prefs.text("Practice session"))
            Picker(prefs.text("Club"), selection: Binding(get: { recording.clubID }, set: { id in
                recording.clubID = id
                save()
            })) {
                Text(prefs.text("Unspecified")).tag(nil as UUID?)
                ForEach(clubs) { club in Text(club.name).tag(Optional(club.id)) }
                if let id = recording.clubID, !clubs.contains(where: { $0.id == id }) {
                    Text(prefs.text("Removed club")).tag(Optional(id))
                }
            }
            Picker(prefs.text("Practice session"), selection: Binding(get: { recording.practiceSession?.id }, set: { id in
                guard let session = sessions.first(where: { $0.id == id }) else { return }
                do { try PracticeSessionStore.regroup(recording: recording, to: session, context: context); try context.save() }
                catch { context.rollback(); saveFailed = true }
            })) {
                if recording.practiceSession == nil { Text(prefs.text("Unspecified")).tag(nil as UUID?) }
                ForEach(sessions) { session in
                    Text(session.date.formatted(.dateTime.year().month().day().hour().minute().locale(prefs.locale)))
                        .tag(Optional(session.id))
                }
            }
            Button(prefs.text("Move to a new session")) {
                do {
                    _ = try PracticeSessionStore.newSession(for: recording, context: context, defaultHandedness: prefs.handedness)
                    try context.save()
                } catch { context.rollback(); saveFailed = true }
            }
            if let session = recording.practiceSession {
                NavigationLink(prefs.text("Session details")) { PracticeSessionDetailView(session: session) }
            }
        }
        .padding(20).background(SLTheme.surface).padding(.horizontal, 20)
        .alert(prefs.text("Changes could not be saved."), isPresented: $saveFailed) {
            Button(prefs.text("OK"), role: .cancel) {}
        } message: { Text(prefs.text("Your changes could not be saved. Try again.")) }
    }

    private func save() {
        do { try context.save() }
        catch { context.rollback(); saveFailed = true }
    }
}

struct PracticeSessionDetailView: View {
    @Environment(AppPreferences.self) private var prefs
    @Bindable var session: PracticeSession
    @Query(sort: \GolfClub.createdAt) private var clubs: [GolfClub]
    @State private var editing = false
    @State private var comparisonClubID: UUID?
    @State private var comparisonAngle: CameraAngle = .unspecified

    private var selectedSamples: [CoachingSample] {
        guard comparisonAngle != .unspecified else { return [] }
        return session.recordings.filter { $0.clubID == comparisonClubID && $0.cameraAngleValue == comparisonAngle }
            .map(\.coachingSample)
    }
    private var summaries: [(metric: CoachedMetric, summary: MetricSummary)] {
        CoachedMetric.allCases.compactMap { metric in
            CoachingEngine.consistency(metric, in: selectedSamples).map { (metric, $0) }
        }
    }
    private var removedClubIDs: [UUID] {
        Set(session.recordings.compactMap(\.clubID)).filter { id in !clubs.contains(where: { $0.id == id }) }
            .sorted { $0.uuidString < $1.uuidString }
    }

    var body: some View {
        List {
            Section {
                Text(session.date.formatted(.dateTime.year().month().day().hour().minute().locale(prefs.locale)))
                    .font(.headline)
                if !session.notes.isEmpty { Text(session.notes).font(.body) }
                LabeledContent(prefs.text("Club"), value: clubName(session.clubID))
                LabeledContent(prefs.text("Camera angle"), value: prefs.text(session.cameraAngleValue.localizationKey))
                LabeledContent(prefs.text("Handedness"), value: prefs.text(session.handedness?.localizationKey ?? "Unspecified"))
                SLMetricReadout(metric: ProvenancedValue(value: Double(session.recordings.count), unit: "1",
                    provenance: .measured, method: "practice.savedRecordingCount.v1", sampleCount: session.recordings.count),
                    label: prefs.text("Saved swings"), alignment: .leading)
            }
            Section {
                Picker(prefs.text("Club for comparison"), selection: $comparisonClubID) {
                    Text(prefs.text("Unspecified")).tag(nil as UUID?)
                    ForEach(clubs) { club in Text(club.name).tag(Optional(club.id)) }
                    ForEach(removedClubIDs, id: \.self) { id in
                        Text(prefs.text("Removed club")).tag(Optional(id))
                    }
                }
                Picker(prefs.text("Camera angle"), selection: $comparisonAngle) {
                    ForEach(CameraAngle.allCases) { angle in Text(prefs.text(angle.localizationKey)).tag(angle) }
                }
                Text(prefs.text("Consistency uses at least five available values from the same club and camera angle."))
                    .font(.caption).foregroundStyle(.secondary)
                if summaries.isEmpty {
                    Text(prefs.text("No consistency summary is available for this group yet."))
                        .foregroundStyle(.secondary)
                }
            } header: { Text(prefs.text("Session consistency")) }
            ForEach(summaries, id: \.metric) { item in
                Section(metricLabel(item.metric)) {
                    summaryRow(item.summary.mean, key: "Mean", metric: item.metric, count: item.summary.count)
                    summaryRow(item.summary.standardDeviation, key: "Standard deviation", metric: item.metric, count: item.summary.count)
                    summaryRow(item.summary.coefficientOfVariation, key: "Coefficient of variation", metric: item.metric,
                               count: item.summary.count, isCV: true)
                }
            }
            Section(prefs.text("Practice library")) {
                ForEach(session.recordings.sorted { $0.createdAt < $1.createdAt }) { recording in
                    NavigationLink { SwingDetailView(recording: recording) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recording.title)
                            Text(recording.createdAt.formatted(.dateTime.hour().minute().locale(prefs.locale)))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).background(SLTheme.background)
        .navigationTitle(prefs.text("Practice session"))
        .toolbar { Button(prefs.text("Edit")) { editing = true } }
        .sheet(isPresented: $editing) { PracticeSessionEditorView(session: session) }
        .onAppear { comparisonClubID = session.clubID; comparisonAngle = session.cameraAngleValue }
    }

    private func clubName(_ id: UUID?) -> String {
        guard let id else { return prefs.text("Unspecified") }
        return clubs.first { $0.id == id }?.name ?? prefs.text("Removed club")
    }

    private func metricLabel(_ metric: CoachedMetric) -> String {
        switch metric {
        case .tempo: prefs.text("Tempo ratio")
        case .backswing: prefs.text("Backswing")
        case .downswing: prefs.text("Downswing")
        case .headDisplacement: prefs.text("Head displacement")
        }
    }

    private func summaryRow(_ value: Double?, key: String, metric: CoachedMetric, count: Int, isCV: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(prefs.text(key)).font(.subheadline)
            Spacer(minLength: 16)
            SLMetricReadout(metric: ProvenancedValue(value: value,
                unit: !isCV && (metric == .backswing || metric == .downswing) ? "s" : "1",
                provenance: .estimated, method: isCV ? "practice.coefficientOfVariation.v1" : "practice.sampleSummary.v1",
                sampleCount: count), fractionDigits: isCV || metric == .headDisplacement ? 1 : 3,
                displayAsPercent: isCV || metric == .headDisplacement, valueFont: .subheadline)
        }
    }
}

private struct PracticeSessionEditorView: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GolfClub.createdAt) private var clubs: [GolfClub]
    let session: PracticeSession
    @State private var date: Date
    @State private var notes: String
    @State private var clubID: UUID?
    @State private var cameraAngle: CameraAngle
    @State private var handedness: Handedness?
    @State private var saveFailed = false

    init(session: PracticeSession) {
        self.session = session
        _date = State(initialValue: session.date)
        _notes = State(initialValue: session.notes)
        _clubID = State(initialValue: session.clubID)
        _cameraAngle = State(initialValue: session.cameraAngleValue)
        _handedness = State(initialValue: session.handedness)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(prefs.text("Date"), selection: $date)
                TextField(prefs.text("Notes"), text: $notes, axis: .vertical).lineLimit(3...6)
                Picker(prefs.text("Club"), selection: $clubID) {
                    Text(prefs.text("Unspecified")).tag(nil as UUID?)
                    ForEach(clubs) { club in Text(club.name).tag(Optional(club.id)) }
                    if let id = clubID, !clubs.contains(where: { $0.id == id }) {
                        Text(prefs.text("Removed club")).tag(Optional(id))
                    }
                }
                Picker(prefs.text("Camera angle"), selection: $cameraAngle) {
                    ForEach(CameraAngle.allCases) { angle in Text(prefs.text(angle.localizationKey)).tag(angle) }
                }
                Picker(prefs.text("Handedness"), selection: $handedness) {
                    Text(prefs.text("Unspecified")).tag(nil as Handedness?)
                    ForEach(Handedness.allCases) { hand in Text(prefs.text(hand.localizationKey)).tag(Optional(hand)) }
                }
                Text(prefs.text("Session details describe the practice. Individual recording labels stay as entered."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle(prefs.text("Practice session"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(prefs.text("Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(prefs.text("Save"), action: save) }
            }
            .alert(prefs.text("Changes could not be saved."), isPresented: $saveFailed) {
                Button(prefs.text("OK"), role: .cancel) {}
            } message: { Text(prefs.text("Your changes could not be saved. Try again.")) }
        }
    }

    private func save() {
        session.date = date; session.notes = notes; session.clubID = clubID
        session.cameraAngleValue = cameraAngle; session.handedness = handedness
        do { try context.save(); dismiss() }
        catch { context.rollback(); saveFailed = true }
    }
}
