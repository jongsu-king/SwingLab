import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import SwingLabCore

/// Saved camera launches, newest first, with a per-club average once there are enough shots.
/// Carry and total are not stored with a shot: they are simulated here from each club's average
/// launch, and say so.
struct LaunchLogView: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LaunchShot.date, order: .reverse) private var shots: [LaunchShot]
    @State private var error: LocalizationKey?
    @State private var clubReadouts: [ReferenceClub: LaunchReadout] = [:]

    var body: some View {
        List {
            Section {
                Label(prefs.text("Experimental: launch values come from video and have not been checked against a launch monitor."),
                      systemImage: "flask").font(.caption).foregroundStyle(.secondary)
            }.listRowBackground(Color.clear)
            if shots.isEmpty {
                Section {
                    Text(prefs.text("No launch shots yet. Turn on Live readout in launch mode, or measure a clip recorded at 200 fps or more."))
                        .font(.subheadline).foregroundStyle(.secondary)
                }.listRowBackground(SLTheme.surface)
            } else {
                Section(prefs.text("Average by club")) {
                    ForEach(summaries, id: \.club) { summary in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(prefs.text(summary.club.localizationKey)).font(.headline)
                                Spacer()
                                Text(prefs.format("count.launchShots", Int64(summary.count))).font(.caption).foregroundStyle(.secondary)
                            }
                            HStack(alignment: .top, spacing: 24) {
                                SLMetricReadout(metric: summary.speed, label: prefs.text("Ball speed"), fractionDigits: 1, alignment: .leading)
                                SLMetricReadout(metric: summary.angle, label: prefs.text("Launch angle"), fractionDigits: 1, alignment: .leading)
                                if let spread = summary.speedSpread {
                                    SLMetricReadout(metric: spread, label: prefs.text("Standard deviation"), fractionDigits: 1, alignment: .leading)
                                }
                            }
                            if let readout = clubReadouts[summary.club] {
                                HStack(alignment: .top, spacing: 24) {
                                    SLRangeReadout(range: readout.carry, label: prefs.text("Carry"), alignment: .leading)
                                    SLRangeReadout(range: readout.total, label: prefs.text("Total"), alignment: .leading)
                                    SLRangeReadout(range: readout.clubSpeed, label: prefs.text("Club speed"), alignment: .leading)
                                }
                            }
                        }.padding(.vertical, 4)
                    }
                    Text(prefs.text("Carry and total are simulated from the club's average launch across its published spin bracket; club speed is estimated from published smash factors. They are not stored with the shots."))
                        .font(.caption).foregroundStyle(.secondary)
                }.listRowBackground(SLTheme.surface)
                Section(prefs.text("Shots")) {
                    ForEach(shots) { shot in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(shot.date.formatted(.dateTime.locale(prefs.locale).month().day().hour().minute())).font(.subheadline)
                                Spacer()
                                if let club = shot.referenceClub { Text(prefs.text(club.localizationKey)).font(.caption).foregroundStyle(.secondary) }
                            }
                            HStack(spacing: 24) {
                                SLMetricReadout(metric: shot.ballSpeed, label: prefs.text("Ball speed"), fractionDigits: 1, alignment: .leading)
                                SLMetricReadout(metric: shot.launchAngle, label: prefs.text("Launch angle"), fractionDigits: 1, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions {
                            Button(prefs.text("Delete shot"), role: .destructive) { delete(shot) }
                        }
                    }
                }.listRowBackground(SLTheme.surface)
            }
        }
        .scrollContentBackground(.hidden).background(SLTheme.background)
        .task(id: shots.count) { await buildClubReadouts() }
        .navigationTitle(prefs.text("Launch log"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // Measured values only, in SI with a provenance column; nothing simulated is exported.
                ShareLink(item: LaunchLogCSVFile(csv: LaunchLogExport.csv(shots.map(\.exportRow))),
                          preview: SharePreview(prefs.text("Launch log"))) {
                    Label(prefs.text("Export CSV"), systemImage: "square.and.arrow.up")
                }
                .disabled(shots.isEmpty)
                .accessibilityIdentifier("launchLog.export")
            }
        }
        // Inline like Hypothetical flight: a large title truncates in Spanish and Portuguese.
        .navigationBarTitleDisplayMode(.inline)
        .alert(prefs.text("Launch log"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button(prefs.text("OK"), role: .cancel) { error = nil }
        } message: { Text(prefs.text(error ?? "")) }
    }

    private struct Summary {
        let club: ReferenceClub
        let count: Int
        let speed: ProvenancedValue
        let angle: ProvenancedValue
        /// One standard deviation of ball speed; shown from 5 shots, the coaching threshold.
        let speedSpread: ProvenancedValue?
    }

    private var summaries: [Summary] {
        let grouped = Dictionary(grouping: shots.filter { $0.referenceClub != nil }) { $0.referenceClub! }
        return ReferenceClub.allCases.compactMap { club in
            guard let group = grouped[club], !group.isEmpty else { return nil }
            let speeds = group.map(\.ballSpeedMetersPerSecond), angles = group.map(\.launchAngleRadians)
            let mean = speeds.reduce(0, +) / Double(speeds.count)
            let spread: ProvenancedValue? = speeds.count >= 5 ? {
                let variance = speeds.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(speeds.count - 1)
                return ProvenancedValue(value: variance.squareRoot(), unit: "m/s", provenance: .visionDerived,
                                        method: "launchLog.sampleStandardDeviation.v1", sampleCount: speeds.count)
            }() : nil
            return Summary(club: club, count: group.count,
                           speed: ProvenancedValue(value: mean, unit: "m/s", provenance: .visionDerived,
                                                   method: "launchLog.mean.v1", sampleCount: speeds.count),
                           angle: ProvenancedValue(value: angles.reduce(0, +) / Double(angles.count), unit: "rad",
                                                   provenance: .visionDerived, method: "launchLog.mean.v1", sampleCount: angles.count),
                           speedSpread: spread)
        }
    }

    /// One readout per club from its mean launch: a handful of flight simulations, off the main actor.
    private func buildClubReadouts() async {
        let inputs = summaries.map { (club: $0.club, speed: $0.speed, angle: $0.angle) }
        guard !inputs.isEmpty else { clubReadouts = [:]; return }
        let built = await Task.detached(priority: .utility) { () -> [ReferenceClub: LaunchReadout] in
            var result: [ReferenceClub: LaunchReadout] = [:]
            for input in inputs {
                result[input.club] = LaunchReadoutBuilder.build(ballSpeed: input.speed, launchAngle: input.angle, club: input.club)
            }
            return result
        }.value
        clubReadouts = built
    }

    private func delete(_ shot: LaunchShot) {
        modelContext.delete(shot)
        do { try modelContext.save() } catch {
            modelContext.rollback()
            self.error = "The shot could not be deleted. Please try again."
        }
    }
}

/// The launch log as a CSV file for the share sheet.
struct LaunchLogCSVFile: Transferable {
    let csv: String
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { Data($0.csv.utf8) }
            .suggestedFileName("SwingLab-launch-log.csv")
    }
}

extension LaunchShot {
    var exportRow: LaunchLogRow {
        LaunchLogRow(date: date, club: referenceClubID, source: sourceID, ballSpeedMetersPerSecond: ballSpeedMetersPerSecond,
                     launchAngleRadians: launchAngleRadians, provenance: ballSpeed.provenance, confidence: confidence,
                     relativeSpeedUncertainty: relativeSpeedUncertainty, trackedPositions: trackedPositions, method: method)
    }
}
