import SwiftUI
import SwiftData
import SwingLabCore

/// Experimental launch readout from a face-on, high-frame-rate recording. Ball speed and launch
/// angle are vision-derived; carry is a simulated range; spin and club speed stay unavailable.
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
    @State private var club = ReferenceClub.iron7
    @State private var outcome: LaunchVideoAnalyzer.Outcome?
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
                Picker(prefs.text("Club"), selection: $club) {
                    ForEach(ReferenceClub.allCases) { Text(prefs.text($0.localizationKey)).tag($0) }
                }
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
                if let outcome { readout(outcome) }
            }.padding(20)
        }
        .background(SLTheme.background)
        .navigationTitle(prefs.text("Launch"))
        .onChange(of: ballPoint) { outcome = nil; saved = false }
        .onChange(of: club) { saved = false }
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

    private func readout(_ outcome: LaunchVideoAnalyzer.Outcome) -> some View {
        let measurement = outcome.measurement
        let carry = CarryRangeEstimator.estimate(ballSpeed: measurement.ballSpeed, launchAngle: measurement.launchAngle, club: club)
        let notObserved = { (unit: String) in
            ProvenancedValue(value: nil, unit: unit, provenance: .unavailable, method: "launch.notObservable")
        }
        return VStack(alignment: .leading, spacing: 16) {
            SLSectionHeader(title: prefs.text("Launch"))
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 16) {
                GridRow {
                    SLMetricReadout(metric: measurement.ballSpeed, label: prefs.text("Ball speed"), fractionDigits: 1,
                                    valueFont: .system(size: 34, weight: .light), alignment: .leading)
                    SLMetricReadout(metric: measurement.launchAngle, label: prefs.text("Launch angle"), fractionDigits: 1,
                                    valueFont: .system(size: 34, weight: .light), alignment: .leading)
                }
                GridRow {
                    SLMetricReadout(metric: carry?.shortest ?? notObserved("m"), label: prefs.text("Carry (shortest)"), alignment: .leading)
                    SLMetricReadout(metric: carry?.longest ?? notObserved("m"), label: prefs.text("Carry (longest)"), alignment: .leading)
                }
                GridRow {
                    SLMetricReadout(metric: notObserved("rpm"), label: prefs.text("Spin rate"), alignment: .leading)
                    SLMetricReadout(metric: notObserved("m/s"), label: prefs.text("Club speed"), alignment: .leading)
                }
            }
            Text(prefs.text("Carry is simulated across published spin rates for this club; it is not measured. Spin and club speed cannot be observed with one iPhone camera."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if saved {
                Label(prefs.text("Saved to the launch log."), systemImage: "checkmark").font(.caption).foregroundStyle(.secondary)
            } else {
                Button(prefs.text("Save shot")) { save(measurement) }.buttonStyle(.bordered).tint(SLTheme.forest)
            }
        }
        .padding(20).background(SLTheme.surface)
    }

    private func save(_ measurement: LaunchMeasurement) {
        guard let shot = LaunchShot(measurement: measurement, club: club, source: .recordedVideo) else { return }
        modelContext.insert(shot)
        do { try modelContext.save(); saved = true } catch {
            modelContext.rollback()
            errorKey = "The shot could not be saved. Please try again."
        }
    }

    private func measure() {
        guard let ballPoint, let impactTime else { return }
        working = true; errorKey = nil; outcome = nil; saved = false
        Task {
            defer { working = false }
            do {
                outcome = try await analyzer.measure(url: videoURL, impactTime: impactTime, ballPoint: ballPoint,
                                                     targetDirection: direction)
            } catch let error as LaunchVideoError { errorKey = error.key }
            catch { errorKey = LaunchVideoError.unreadable.key }
        }
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
