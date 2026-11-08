import SwiftUI
import SwiftData
import SwingLabCore

/// Experimental launch readout from a face-on, high-frame-rate recording. Ball speed and launch
/// angle are vision-derived; carry and total are simulated ranges; club speed is estimated from
/// published smash factors; back spin is the published bracket the simulation runs across.
struct LaunchMeasureView: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.modelContext) private var modelContext
    let videoURL: URL
    let defaultDirection: Double
    @State private var analyzer = LaunchVideoAnalyzer()
    @State private var frame: CGImage?
    @State private var impactTime: Double?
    @State private var ballPoint: CGPoint?
    @State private var direction = 1.0
    @State private var autoClub = true
    @State private var club = ReferenceClub.iron7
    @State private var outcome: LaunchVideoAnalyzer.Outcome?
    @State private var readout: LaunchReadout?
    @State private var errorKey: LocalizationKey?
    @State private var working = false
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SLInlineNoticeRow(symbol: "flask", key: "Experimental: launch values come from video and have not been checked against a launch monitor.")
                addressFrame
                Picker(prefs.text("Ball direction"), selection: $direction) {
                    Text(prefs.text("Flies right")).tag(1.0)
                    Text(prefs.text("Flies left")).tag(-1.0)
                }.pickerStyle(.segmented)
                Toggle(prefs.text("Auto club"), isOn: $autoClub)
                Picker(prefs.text("Club"), selection: $club) {
                    ForEach(ReferenceClub.allCases) { Text(prefs.text($0.localizationKey)).tag($0) }
                }.disabled(autoClub)
                Button {
                    measure()
                } label: {
                    Text(prefs.text("Measure launch")).frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).tint(SLTheme.forest)
                    .disabled(ballPoint == nil || impactTime == nil || working)
                if working { ProgressView() }
                if let errorKey {
                    Text(prefs.text(errorKey)).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if let readout { readoutSection(readout) }
            }.padding(20)
        }
        .background(SLTheme.background)
        .navigationTitle(prefs.text("Launch"))
        .onChange(of: ballPoint) { outcome = nil; readout = nil; saved = false }
        .onChange(of: club) { saved = false; rebuild() }
        .onChange(of: autoClub) {
            saved = false
            // Leaving Auto starts the picker from the club the readout chose; the club change rebuilds.
            if !autoClub, let readout, readout.club != club { club = readout.club } else { rebuild() }
        }
        .task {
            direction = defaultDirection
            do {
                let found = try await analyzer.addressFrame(url: videoURL)
                frame = found.image; impactTime = found.impactTime
            } catch let error as LaunchVideoError { errorKey = error.key }
            catch { errorKey = LaunchVideoError.unreadable.key }
        }
    }

    @ViewBuilder private var addressFrame: some View {
        if let frame {
            VStack(alignment: .leading, spacing: 8) {
                Text(prefs.text("Tap the centre of the ball at address.")).font(.subheadline)
                BallTapImage(image: frame, point: $ballPoint, accessibilityLabel: prefs.text("Tap the centre of the ball at address."))
                    .frame(height: 360)
            }
        } else if errorKey == nil {
            ProgressView(prefs.text("Finding the impact sound…"))
        }
    }

    private func readoutSection(_ readout: LaunchReadout) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SLSectionHeader(title: prefs.text("Launch"))
            LaunchRangeView(readout: readout, height: 140)
            LaunchReadoutGrid(readout: readout)
            LaunchReadoutFootnote(readout: readout)
            if saved {
                Label(prefs.text("Saved to the launch log."), systemImage: "checkmark").font(.caption).foregroundStyle(.secondary)
            } else {
                Button(prefs.text("Save shot")) { save(readout) }.buttonStyle(.bordered).tint(SLTheme.forest)
            }
        }
        .padding(20).background(SLTheme.surface)
    }

    private func save(_ readout: LaunchReadout) {
        guard let outcome, let shot = LaunchShot(measurement: outcome.measurement, club: readout.club, source: .recordedVideo) else { return }
        modelContext.insert(shot)
        do { try modelContext.save(); saved = true } catch {
            modelContext.rollback()
            errorKey = "The shot could not be saved. Please try again."
        }
    }

    private func measure() {
        guard let ballPoint, let impactTime else { return }
        working = true; errorKey = nil; outcome = nil; readout = nil; saved = false
        Task {
            defer { working = false }
            do {
                outcome = try await analyzer.measure(url: videoURL, impactTime: impactTime, ballPoint: ballPoint,
                                                     targetDirection: direction)
                await build()
            } catch let error as LaunchVideoError { errorKey = error.key }
            catch { errorKey = LaunchVideoError.unreadable.key }
        }
    }

    private func rebuild() {
        guard outcome != nil else { return }
        Task { await build() }
    }

    /// Five flight simulations and the roll model; kept off the main actor.
    private func build() async {
        guard let measurement = outcome?.measurement else { readout = nil; return }
        let chosen: ReferenceClub? = autoClub ? nil : club
        let built = await Task.detached(priority: .userInitiated) {
            LaunchReadoutBuilder.build(measurement: measurement, club: chosen)
        }.value
        readout = built
    }
}

private struct SLInlineNoticeRow: View {
    @Environment(AppPreferences.self) private var prefs
    let symbol: String
    let key: LocalizationKey
    var body: some View {
        Label(prefs.text(key), systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
