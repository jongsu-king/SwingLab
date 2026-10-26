import SwiftUI
import SwingLabCore

/// Experimental launch readout from a face-on, high-frame-rate recording. Ball speed and launch
/// angle are vision-derived; carry is a simulated range; spin and club speed stay unavailable.
struct LaunchMeasureView: View {
    @Environment(AppPreferences.self) private var prefs
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
                GeometryReader { geometry in
                    let size = fittedSize(for: geometry.size)
                    ZStack(alignment: .topLeading) {
                        Image(decorative: frame, scale: 1).resizable().frame(width: size.width, height: size.height)
                        if let ballPoint {
                            Circle().stroke(SLTheme.sage, lineWidth: 2).frame(width: 28, height: 28)
                                .position(x: ballPoint.x * size.width, y: ballPoint.y * size.height)
                        }
                    }
                    .frame(width: size.width, height: size.height)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        ballPoint = CGPoint(x: min(1, max(0, location.x / size.width)), y: min(1, max(0, location.y / size.height)))
                        outcome = nil
                    }
                    .accessibilityLabel(prefs.text("Tap the centre of the ball at address."))
                }
                .frame(height: 360)
            }
        } else if errorKey == nil {
            ProgressView(prefs.text("Finding the impact sound…"))
        }
    }

    private func fittedSize(for available: CGSize) -> CGSize {
        guard let frame, frame.width > 0, frame.height > 0 else { return available }
        let aspect = Double(frame.width) / Double(frame.height)
        let height = min(available.height, available.width / aspect)
        return CGSize(width: height * aspect, height: height)
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
        }
        .padding(20).background(SLTheme.surface)
    }

    private func measure() {
        guard let ballPoint, let impactTime else { return }
        working = true; errorKey = nil; outcome = nil
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
