import SwiftUI
import SwiftData
import SwingLabCore

struct RoundHistoryView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.modelContext) private var context
    @Query(sort: \RoundSession.startedAt, order: .reverse) private var rounds: [RoundSession]
    @State private var errorKey: LocalizationKey?

    var body: some View {
        List {
            if rounds.isEmpty {
                SLEmptyState(title: preferences.text("Your rounds, recorded"),
                             message: preferences.text("Start a round from Course to keep a scorecard and record GPS shots."), symbol: "flag.checkered")
            }
            ForEach(rounds) { round in
                NavigationLink {
                    ScorecardView(round: round)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(round.courseName).font(.headline)
                        Text(round.startedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Text(preferences.text(round.endedAt == nil ? "In progress" : "Finished"))
                            Spacer()
                            SLMetricReadout(metric: ProvenancedValue(
                                value: round.completedHoleCount > 0 ? Double(round.totalScore) : nil,
                                unit: "1", provenance: .userEntered, method: "scorecard.total.v1",
                                sampleCount: round.completedHoleCount),
                                label: preferences.format("metric.holesScored",
                                    round.completedHoleCount.formatted(.number.locale(preferences.locale)),
                                    round.holeCount.formatted(.number.locale(preferences.locale))))
                        }.font(.subheadline)
                    }
                }
            }
            .onDelete { offsets in
                let selected = offsets.map { rounds[$0] }
                for round in selected { context.delete(round) }
                do { try context.save() }
                catch { context.rollbackPendingChanges(); errorKey = "Your changes could not be saved. Try again." }
            }
            if let errorKey { Text(preferences.text(errorKey)).foregroundStyle(.red) }
        }
        .navigationTitle(preferences.text("Round history"))
    }
}

struct ScorecardView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.modelContext) private var context
    let round: RoundSession
    @State private var errorKey: LocalizationKey?

    var body: some View {
        List {
            Section {
                Text(round.courseName).font(.title2.weight(.semibold))
                LabeledContent(preferences.text("Recorded score")) {
                    SLMetricReadout(metric: ProvenancedValue(
                        value: round.completedHoleCount > 0 ? Double(round.totalScore) : nil,
                        unit: "1", provenance: .userEntered, method: "scorecard.total.v1", sampleCount: round.completedHoleCount),
                        label: preferences.format("metric.holesScored",
                            round.completedHoleCount.formatted(.number.locale(preferences.locale)),
                            round.holeCount.formatted(.number.locale(preferences.locale))))
                }
                Text(preferences.text("Strokes include putts and penalties. GPS shot logs do not automatically change your score."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section(preferences.text("Scorecard")) {
                ForEach(round.holeScores.sorted { $0.number < $1.number }) { score in
                    NavigationLink {
                        HoleScoreEditor(score: score)
                    } label: {
                        HStack {
                            Text(preferences.format("metric.hole", score.number.formatted(.number.locale(preferences.locale))))
                            Spacer()
                            SLMetricReadout(metric: ProvenancedValue(value: score.par.map(Double.init), unit: "1",
                                provenance: .userEntered, method: "scorecard.par.v1"), label: preferences.text("Par"))
                            SLMetricReadout(metric: ProvenancedValue(value: score.strokes.map(Double.init), unit: "1",
                                provenance: .userEntered, method: "scorecard.strokes.v1"),
                                label: preferences.text("Strokes"), valueFont: .headline)
                        }
                    }
                }
            }
            Section(preferences.text("GPS shot log")) {
                if round.shots.isEmpty {
                    Text(preferences.text("No shots recorded.")).foregroundStyle(.secondary)
                }
                ForEach(round.shots.sorted { $0.startedAt < $1.startedAt }) { shot in
                    NavigationLink {
                        ShotEditor(shot: shot)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preferences.format("metric.holeClub",
                                shot.holeNumber.formatted(.number.locale(preferences.locale)), shot.clubName))
                            SLMetricReadout(metric: ProvenancedValue(value: shot.groundDisplacementMeters, unit: "m",
                                provenance: .measured, method: "gps.groundDisplacement.v1",
                                sampleCount: shot.groundDisplacementMeters == nil ? nil : 2), alignment: .leading)
                            if shot.groundDisplacementMeters == nil {
                                Text(preferences.text("Waiting for the next ball position")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            if round.endedAt == nil {
                Section {
                    Button(preferences.text("Finish round")) {
                        guard round.pendingShot == nil else {
                            errorKey = "Complete or delete the pending shot before finishing the round."
                            return
                        }
                        round.endedAt = .now
                        do { try context.save() }
                        catch { context.rollbackPendingChanges(); errorKey = "Your changes could not be saved. Try again." }
                    }
                    Text(preferences.text("You can finish an incomplete round. Unscored holes remain empty."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            if let errorKey { Text(preferences.text(errorKey)).foregroundStyle(.red) }
        }
        .navigationTitle(preferences.text("Scorecard"))
    }
}

private struct HoleScoreEditor: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let score: HoleScore
    @State private var par = ""
    @State private var strokes = ""
    @State private var putts = ""
    @State private var penalties = 0
    @State private var fairway = -1
    @State private var green = -1
    @State private var errorKey: LocalizationKey?

    var body: some View {
        Form {
            Section {
                numericField("Par", text: $par)
                numericField("Strokes", text: $strokes)
                numericField("Putts", text: $putts)
                Stepper(value: $penalties, in: 0...30) {
                    SLMetricReadout(metric: ProvenancedValue(value: Double(penalties), unit: "1", provenance: .userEntered,
                        method: "scorecard.penalties.v1"), label: preferences.text("Penalties"), alignment: .leading)
                }
                outcomePicker("Fairway hit", selection: $fairway)
                outcomePicker("Green in regulation", selection: $green)
            } footer: {
                Text(preferences.text("Leave unrecorded values empty. Total strokes include putts and penalties."))
            }
            if let errorKey { Text(preferences.text(errorKey)).foregroundStyle(.red) }
            Button(preferences.text("Save"), action: save).fontWeight(.semibold)
        }
        .navigationTitle(preferences.format("metric.hole", score.number.formatted(.number.locale(preferences.locale))))
        .keyboardDoneButton(preferences.text("Done"))
        .onAppear {
            par = score.par.map(String.init) ?? ""
            strokes = score.strokes.map(String.init) ?? ""
            putts = score.putts.map(String.init) ?? ""
            penalties = score.penalties
            fairway = score.fairwayHit.map { $0 ? 1 : 0 } ?? -1
            green = score.greenInRegulation.map { $0 ? 1 : 0 } ?? -1
        }
    }

    private func numericField(_ key: LocalizationKey, text: Binding<String>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(preferences.text(key))
                ProvenanceBadge(provenance: text.wrappedValue.isEmpty ? .unavailable : .userEntered)
            }
            TextField(preferences.text("Not recorded"), text: text)
                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                .accessibilityLabel(preferences.text(key))
        }
    }

    private func outcomePicker(_ key: LocalizationKey, selection: Binding<Int>) -> some View {
        Picker(preferences.text(key), selection: selection) {
            Text(preferences.text("Not recorded")).tag(-1)
            Text(preferences.text("Yes")).tag(1)
            Text(preferences.text("No")).tag(0)
        }
    }

    private func save() {
        guard let entry = ScorecardEntry.validated(par: par, strokes: strokes, putts: putts, penalties: penalties) else {
            errorKey = "Check the score. Putts and penalties cannot exceed total strokes."
            return
        }
        score.par = entry.par
        score.strokes = entry.strokes
        score.putts = entry.putts
        score.penalties = entry.penalties
        score.fairwayHit = fairway < 0 ? nil : fairway == 1
        score.greenInRegulation = green < 0 ? nil : green == 1
        if let course = score.round?.course {
            if let hole = course.holes.first(where: { $0.number == score.number }) {
                hole.par = entry.par
            } else if entry.par != nil {
                let hole = CourseHole(number: score.number, par: entry.par)
                context.insert(hole)
                course.holes.append(hole)
            }
        }
        do { try context.save(); dismiss() }
        catch { context.rollbackPendingChanges(); errorKey = "Your changes could not be saved. Try again." }
    }
}

private struct ShotEditor: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let shot: ShotRecord
    @State private var clubName = ""
    @State private var lie = "Unknown"
    @State private var shape = "Unknown"
    @State private var penalties = 0
    @State private var notes = ""
    @State private var errorKey: LocalizationKey?
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section(preferences.text("Shot details")) {
                TextField(preferences.text("Club"), text: $clubName)
                Picker(preferences.text("Lie"), selection: $lie) {
                    ForEach(["Unknown", "Tee", "Fairway", "Rough", "Bunker", "Green", "Other"] as [LocalizationKey], id: \.self) { (key: LocalizationKey) in Text(preferences.text(key)).tag(key.rawValue) }
                }
                Picker(preferences.text("Shot shape"), selection: $shape) {
                    ForEach(["Unknown", "Straight", "Draw", "Fade", "Hook", "Slice", "Other"] as [LocalizationKey], id: \.self) { (key: LocalizationKey) in Text(preferences.text(key)).tag(key.rawValue) }
                }
                Stepper(value: $penalties, in: 0...10) {
                    SLMetricReadout(metric: ProvenancedValue(value: Double(penalties), unit: "1", provenance: .userEntered,
                        method: "shot.penalties.v1"), label: preferences.text("Penalties"), alignment: .leading)
                }
                TextField(preferences.text("Notes"), text: $notes, axis: .vertical)
            }
            Section(preferences.text("GPS provenance")) {
                if let distance = shot.groundDisplacementMeters {
                    LabeledContent(preferences.text("Ground displacement")) {
                        SLMetricReadout(metric: ProvenancedValue(value: distance, unit: "m", provenance: .measured,
                            method: "gps.groundDisplacement.v1", sampleCount: 2))
                    }
                }
                LabeledContent(preferences.text("Start accuracy")) {
                    SLMetricReadout(metric: ProvenancedValue(value: shot.startAccuracyMeters, unit: "m", provenance: .measured,
                        method: "gps.horizontalAccuracy.v1", sampleCount: 1))
                }
                Text(shot.startedAt, format: .dateTime.year().month().day().hour().minute().second())
                if let accuracy = shot.endAccuracyMeters {
                    LabeledContent(preferences.text("End accuracy")) {
                        SLMetricReadout(metric: ProvenancedValue(value: accuracy, unit: "m", provenance: .measured,
                            method: "gps.horizontalAccuracy.v1", sampleCount: 1))
                    }
                }
                if let date = shot.endedAt { Text(date, format: .dateTime.year().month().day().hour().minute().second()) }
                Text(preferences.text("GPS records the distance between two positions. It includes roll and GPS uncertainty, and is not measured airborne carry."))
                    .font(.footnote).foregroundStyle(.secondary)
                if let distance = shot.groundDisplacementMeters, let endAccuracy = shot.endAccuracyMeters,
                   distance <= shot.startAccuracyMeters + endAccuracy {
                    Text(preferences.text("This displacement is small relative to the reported GPS uncertainty."))
                        .font(.footnote).foregroundStyle(.orange)
                }
            }
            if let errorKey { Text(preferences.text(errorKey)).foregroundStyle(.red) }
            Button(preferences.text("Save")) {
                guard !clubName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                // Preserve the club identifier only while its recorded name is unchanged.
                if clubName != shot.clubName { shot.clubID = nil }
                shot.clubName = clubName
                shot.lie = lie
                shot.shape = shape
                shot.penalties = penalties
                shot.notes = notes
                do { try context.save(); dismiss() }
                catch { context.rollbackPendingChanges(); errorKey = "Your changes could not be saved. Try again." }
            }
            Button(preferences.text("Delete shot"), role: .destructive) { confirmDelete = true }
        }
        .navigationTitle(preferences.format("metric.shot", shot.shotNumber.formatted(.number.locale(preferences.locale))))
        .onAppear { clubName = shot.clubName; lie = shot.lie; shape = shot.shape; penalties = shot.penalties; notes = shot.notes }
        .confirmationDialog(preferences.text("Delete this shot?"), isPresented: $confirmDelete) {
            Button(preferences.text("Delete shot"), role: .destructive) {
                context.delete(shot)
                do { try context.save(); dismiss() }
                catch { context.rollbackPendingChanges(); errorKey = "Your changes could not be saved. Try again." }
            }
        }
    }
}
