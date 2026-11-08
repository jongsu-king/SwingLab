import SwiftUI
import SwingLabCore

/// Real-time launch readout over the camera preview: the setup verdict, the session count, a
/// schematic range with the launch strobe, and the six tiles. Ball speed and launch angle are
/// vision-derived; carry and total are simulated; club speed is estimated; back spin is the
/// published bracket. The phone can stay on its stand: each shot is read aloud unless muted.
struct LiveLaunchPanel: View {
    @Environment(AppPreferences.self) private var prefs
    let camera: CameraController
    let discardLast: () -> Void
    @State private var sessionExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if camera.liveListening || camera.liveReadout != nil { controls }
            if camera.liveListening { setupRow }
            if let readout = camera.liveReadout {
                if !prefs.launchNumbersOnly {
                    HStack(alignment: .top, spacing: 10) {
                        LaunchRangeView(readout: readout, height: 104)
                        if let strobe = camera.liveStrobe {
                            LaunchStrobeView(image: strobe, observations: camera.liveOutcome?.measurement.observations ?? [])
                                .frame(height: 104)
                        }
                    }
                }
                LaunchReadoutGrid(readout: readout, compact: true)
                LaunchReadoutFootnote(readout: readout)
                shotRow
            }
            if !camera.liveSessionShots.isEmpty { session }
            status
            Text(prefs.text("Experimental: launch values come from video and have not been checked against a launch monitor."))
                .font(.caption2).foregroundStyle(.white.opacity(0.6)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: SLTheme.cornerRadius))
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label(prefs.text("Live readout"), systemImage: "dot.radiowaves.left.and.right").font(.subheadline.weight(.semibold))
            Spacer()
            if !camera.liveSessionShots.isEmpty {
                pill(prefs.format("count.clubs", Int64(camera.liveSessionClubs.count)))
                pill(prefs.format("count.launchShots", Int64(camera.liveSessionShots.count)))
            }
        }
    }

    /// The change from the previous shot with the same club, and a way to drop a mis-hit.
    private var shotRow: some View {
        HStack(alignment: .top, spacing: 12) {
            if let change = LaunchSession.change(in: camera.liveSessionShots) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(prefs.text("Change from the previous shot")).font(.caption2).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Text(signed(SLMetricReadout.formattedValue(change.ballSpeed, preferences: prefs, fractionDigits: 1), change.ballSpeed.value))
                        Text(signed(SLMetricReadout.formattedValue(change.launchAngle, preferences: prefs, fractionDigits: 1), change.launchAngle.value))
                    }.font(.caption.weight(.medium)).monospacedDigit()
                }.accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
            Button(role: .destructive, action: discardLast) {
                Label(prefs.text("Discard last shot"), systemImage: "arrow.uturn.backward").font(.caption)
            }.accessibilityIdentifier("camera.live.discard")
        }
    }

    /// A leading plus for a positive difference; the formatted number already carries any minus sign.
    private func signed(_ text: String, _ value: Double?) -> String { (value ?? 0) > 0 ? "+" + text : text }

    /// Per-club averages for the shots since the stream started.
    private var session: some View {
        DisclosureGroup(isExpanded: $sessionExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(LaunchSession.summaries(camera.liveSessionShots), id: \.club) { summary in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(prefs.text(summary.club.localizationKey)).font(.caption.weight(.semibold))
                            pill(prefs.format("count.launchShots", Int64(summary.count)))
                        }
                        HStack(alignment: .top, spacing: 16) {
                            SLMetricReadout(metric: summary.ballSpeed, label: prefs.text("Ball speed"), fractionDigits: 1, valueFont: .caption, alignment: .leading)
                            SLMetricReadout(metric: summary.launchAngle, label: prefs.text("Launch angle"), fractionDigits: 1, valueFont: .caption, alignment: .leading)
                            if let spread = summary.speedSpread {
                                SLMetricReadout(metric: spread, label: prefs.text("Standard deviation"), fractionDigits: 1, valueFont: .caption, alignment: .leading)
                            }
                            if let carry = summary.carry {
                                SLRangeReadout(range: carry, label: prefs.text("Carry"), valueFont: .caption, alignment: .leading)
                            }
                        }
                    }
                }
            }.padding(.top, 6)
        } label: {
            Label(prefs.text("Session"), systemImage: "list.bullet.rectangle").font(.caption.weight(.semibold))
        }
        .tint(.white)
        .accessibilityIdentifier("camera.live.session")
    }

    private func pill(_ text: String) -> some View {
        Text(text).font(.caption2.weight(.medium)).monospacedDigit().lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.white.opacity(0.15), in: Capsule())
    }

    /// Club (or auto club), flight direction, numbers-only, and voice.
    private var controls: some View {
        HStack(spacing: 8) {
            Menu {
                Picker(prefs.text("Club"), selection: Binding(get: { camera.liveAutoClub ? nil : camera.liveClub },
                                                              set: { camera.chooseLiveClub($0) })) {
                    Text(prefs.text("Auto club")).tag(ReferenceClub?.none)
                    ForEach(ReferenceClub.allCases) { club in
                        Text(prefs.text(club.localizationKey)).tag(ReferenceClub?.some(club))
                    }
                }
            } label: {
                Label(clubLabel, systemImage: "chevron.up.chevron.down").font(.caption).lineLimit(1)
            }
            .accessibilityLabel(prefs.text("Club"))
            Spacer(minLength: 4)
            control(symbol: camera.liveDirection > 0 ? "arrow.right" : "arrow.left",
                    label: prefs.text(camera.liveDirection > 0 ? "Flies right" : "Flies left"), on: false) { camera.flipLiveDirection() }
                .accessibilityIdentifier("camera.live.direction")
            control(symbol: "textformat.123", label: prefs.text("Numbers only"), on: prefs.launchNumbersOnly) { prefs.launchNumbersOnly.toggle() }
                .accessibilityIdentifier("camera.live.numbers")
            control(symbol: prefs.launchVoiceEnabled ? "speaker.wave.2" : "speaker.slash", label: prefs.text("Read values aloud"),
                    on: prefs.launchVoiceEnabled) { prefs.launchVoiceEnabled.toggle() }
                .accessibilityIdentifier("camera.live.voice")
        }
    }

    private var clubLabel: String {
        let club = prefs.text(camera.liveClub.localizationKey)
        return camera.liveAutoClub ? String(format: prefs.text("launch.autoClub"), locale: prefs.locale, club) : club
    }

    private func control(symbol: String, label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.caption.weight(.semibold)).frame(width: 30, height: 26)
                .background(on ? SLTheme.sage.opacity(0.35) : .white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Whether the camera stands where the tracker can work, from the ball's size at address.
    private var setupRow: some View {
        HStack(alignment: .top, spacing: 8) {
            if let setup = camera.liveSetup {
                Image(systemName: setup.verdict == .ready ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(setup.verdict == .ready ? SLTheme.sage : .yellow)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(prefs.text(setup.verdict.localizationKey)).font(.caption.weight(.semibold))
                        if setup.cameraDistance.value != nil {
                            Text(SLMetricReadout.formattedValue(setup.cameraDistance, preferences: prefs, fractionDigits: 1))
                                .font(.caption).monospacedDigit()
                        }
                    }
                    Text(prefs.text(setupHint(setup.verdict))).font(.caption2).foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    if let band = setup.recommendedDistance, setup.verdict != .ready {
                        Text(prefs.format("launch.standRange", distanceText(band.lowerBound), distanceText(band.upperBound)))
                            .font(.caption2).foregroundStyle(.white.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("camera.live.setup")
            } else if camera.liveSetupPending {
                ProgressView().tint(.white).controlSize(.small)
                Text(prefs.text("Checking the ball size…")).font(.caption)
            }
            Spacer(minLength: 0)
            Button(prefs.text("Change ball position")) { camera.engine.live.requestSnapshot() }.font(.caption)
        }
    }

    private func distanceText(_ metres: Double) -> String {
        let number = prefs.distanceUnit.fromSI(metres).formatted(.number.precision(.fractionLength(1)).locale(prefs.locale))
        return String(format: prefs.text("metric.valueUnit"), locale: prefs.locale, number, prefs.distanceUnit.symbol)
    }

    private func setupHint(_ verdict: LaunchSetupCheck.Verdict) -> LocalizationKey {
        switch verdict {
        case .tooClose: "Move the camera farther from the ball so it stays in view for more frames."
        case .ready: "Camera distance is good. Hit when ready."
        case .tooFar: "Move the camera closer: the ball is too small to measure its size precisely."
        }
    }

    @ViewBuilder private var status: some View {
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
