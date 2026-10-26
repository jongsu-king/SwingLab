import SwiftUI
import SwiftData
import SwingLabCore

struct HomeView: View {
    @Environment(AppPreferences.self) private var preferences
    @Query(sort: \SwingRecording.createdAt, order: .reverse) private var recordings: [SwingRecording]
    @Query(sort: \RoundSession.startedAt, order: .reverse) private var rounds: [RoundSession]
    @Query private var clubs: [GolfClub]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(preferences.text("PLAY WITH PRECISION."))
                        .font(.caption.weight(.semibold)).tracking(2).foregroundStyle(SLTheme.forest)
                    Text(preferences.text("A better game,\none swing at a time."))
                        .font(.system(.largeTitle, design: .serif).weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(preferences.text("Record your swing. Know your distances. Give every shot a clear intention."))
                        .font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    NavigationLink { SwingView() } label: {
                        Label(preferences.text("Record & review"), systemImage: "video")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent).foregroundStyle(SLTheme.background).controlSize(.large)
                    .padding(.top, 8)
                }
                .padding(.top, 8)

                if let recent = recordings.first {
                    VStack(alignment: .leading, spacing: 14) {
                        SLSectionHeader(title: preferences.text("Last practice"))
                        NavigationLink { SwingDetailView(recording: recent) } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "play.rectangle").font(.title2).foregroundStyle(SLTheme.forest)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(recent.title).font(.headline).foregroundStyle(SLTheme.ink)
                                    Text(recent.createdAt, format: .dateTime.month(.wide).day().hour().minute())
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Divider()
                }

                if let recent = rounds.first {
                    VStack(alignment: .leading, spacing: 14) {
                        SLSectionHeader(title: preferences.text(recent.endedAt == nil ? "Current round" : "Last round"))
                        NavigationLink { ScorecardView(round: recent) } label: {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(recent.courseName).font(.headline).foregroundStyle(SLTheme.ink)
                                    Text(recent.startedAt, format: .dateTime.month(.wide).day())
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if recent.completedHoleCount > 0 {
                                    VStack(alignment: .trailing, spacing: 3) {
                                        SLMetricReadout(metric: ProvenancedValue(value: Double(recent.totalScore), unit: "1",
                                            provenance: .userEntered, method: "scorecard.total.v1", sampleCount: recent.completedHoleCount),
                                            valueFont: .title2.weight(.medium))
                                        Text(String(format: preferences.text("metric.holesScored"), locale: preferences.locale,
                                            recent.completedHoleCount.formatted(.number.locale(preferences.locale)),
                                            recent.holeCount.formatted(.number.locale(preferences.locale))))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text(preferences.text("In progress")).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Divider()
                }

                VStack(alignment: .leading, spacing: 0) {
                    SLSectionHeader(title: preferences.text("Before the next tee"))
                        .padding(.bottom, 14)
                    NavigationLink { BagView() } label: {
                        destinationRow(
                            title: "My Bag", symbol: "figure.golf",
                            detail: clubs.isEmpty ? "Start with the clubs you trust." : "Review your distances and gaps."
                        )
                    }.accessibilityIdentifier("home.bag")
                    Divider().padding(.vertical, 16)
                    NavigationLink { CourseView() } label: {
                        destinationRow(title: "Plan a round", symbol: "map", detail: "Find a course or choose your own target.")
                    }
                }

                if recordings.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Label(preferences.text("Your first recording"), systemImage: "viewfinder")
                            .font(.subheadline.weight(.semibold))
                        Text(preferences.text("Keep your whole body in view, place the iPhone safely, and record from face-on or down-the-line. Good light helps pose analysis."))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(SLTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 30)
        }
        .background(SLTheme.background)
        .navigationTitle("SwingLab")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink { SettingsView() } label: {
                    Image(systemName: "gearshape").accessibilityLabel(preferences.text("Settings"))
                }.accessibilityIdentifier("home.settings")
            }
        }
    }

    private func destinationRow(title: String, symbol: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: symbol).font(.title3).foregroundStyle(SLTheme.forest).frame(width: 26)
            VStack(alignment: .leading, spacing: 5) {
                Text(preferences.text(title)).font(.headline).foregroundStyle(SLTheme.ink)
                Text(preferences.text(detail)).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}
