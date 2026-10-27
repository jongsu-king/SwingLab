import SwiftUI
import SwingLabCore

/// Real-time launch readout over the camera preview. Ball speed and launch angle are
/// vision-derived; carry is a simulated range; spin and club speed are never shown.
struct LiveLaunchPanel: View {
    @Environment(AppPreferences.self) private var prefs
    let camera: CameraController
    @Binding var club: ReferenceClub

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(prefs.text("Live readout"), systemImage: "dot.radiowaves.left.and.right").font(.subheadline.weight(.semibold))
                Spacer()
                if camera.liveListening {
                    Button(prefs.text("Change ball position")) { camera.engine.live.requestSnapshot() }.font(.caption)
                }
            }
            if let outcome = camera.liveOutcome { readout(outcome) }
            if camera.liveMeasuring {
                HStack(spacing: 8) { ProgressView().tint(.white); Text(prefs.text("Measuring…")).font(.caption) }
            } else if camera.liveListening {
                Text(prefs.text("Listening for the strike…")).font(.caption).foregroundStyle(.white.opacity(0.85))
            } else {
                Text(prefs.text("Set the ball position, then hit. The readout appears about a second after impact."))
                    .font(.caption).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                Button(prefs.text("Set ball position")) { camera.engine.live.requestSnapshot() }
                    .buttonStyle(.borderedProminent).tint(SLTheme.sage).foregroundStyle(SLTheme.ink)
                    .accessibilityIdentifier("camera.live.setBall")
            }
            if let message = camera.liveMessage {
                Text(prefs.text(message)).font(.caption).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
            }
            Text(prefs.text("Experimental: launch values come from video and have not been checked against a launch monitor."))
                .font(.caption2).foregroundStyle(.white.opacity(0.6)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: SLTheme.cornerRadius))
        .environment(\.colorScheme, .dark)
    }

    private func readout(_ outcome: LaunchPipeline.Outcome) -> some View {
        let measurement = outcome.measurement
        let carry = CarryRangeEstimator.estimate(ballSpeed: measurement.ballSpeed, launchAngle: measurement.launchAngle, club: club)
        let simulated = { (value: ProvenancedValue?) in
            value ?? ProvenancedValue(value: nil, unit: "m", provenance: .unavailable, method: CarryRangeEstimator.method)
        }
        return VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                GridRow {
                    SLMetricReadout(metric: measurement.ballSpeed, label: prefs.text("Ball speed"), fractionDigits: 1,
                                    valueFont: .system(size: 30, weight: .light), alignment: .leading)
                    SLMetricReadout(metric: measurement.launchAngle, label: prefs.text("Launch angle"), fractionDigits: 1,
                                    valueFont: .system(size: 30, weight: .light), alignment: .leading)
                }
                GridRow {
                    SLMetricReadout(metric: simulated(carry?.shortest), label: prefs.text("Carry (shortest)"), alignment: .leading)
                    SLMetricReadout(metric: simulated(carry?.longest), label: prefs.text("Carry (longest)"), alignment: .leading)
                }
            }
            Menu {
                Picker(prefs.text("Club"), selection: $club) {
                    ForEach(ReferenceClub.allCases) { Text(prefs.text($0.localizationKey)).tag($0) }
                }
            } label: {
                Label(prefs.text(club.localizationKey), systemImage: "chevron.up.chevron.down").font(.caption)
            }
            .accessibilityLabel(prefs.text("Club"))
        }
    }
}

/// Tap the ball on a still of the live view. Shots are measured from that spot until it changes.
struct LiveBallPositionSheet: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.dismiss) private var dismiss
    let image: CGImage
    @State var direction: Double
    let onDone: (CGPoint, Double) -> Void
    @State private var point: CGPoint?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(prefs.text("Tap the ball where it sits now. Shots are measured from this spot until you change it."))
                    .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                BallTapImage(image: image, point: $point,
                             accessibilityLabel: prefs.text("Tap the ball where it sits now. Shots are measured from this spot until you change it."))
                Picker(prefs.text("Ball direction"), selection: $direction) {
                    Text(prefs.text("Flies right")).tag(1.0)
                    Text(prefs.text("Flies left")).tag(-1.0)
                }.pickerStyle(.segmented)
            }
            .padding(20)
            .background(SLTheme.background)
            .navigationTitle(prefs.text("Set ball position"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(prefs.text("Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(prefs.text("Done")) {
                        if let point { onDone(point, direction) }
                        dismiss()
                    }.disabled(point == nil)
                }
            }
        }
    }
}
