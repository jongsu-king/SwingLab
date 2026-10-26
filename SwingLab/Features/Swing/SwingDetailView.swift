import SwiftUI
import SwiftData
import SwingLabCore

struct SwingDetailView: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.modelContext) private var modelContext
    @Bindable var recording: SwingRecording
    @State private var playback = VideoPlaybackController()
    @State private var videoURL: URL?
    @State private var report: PoseAnalysisReport?
    @State private var showSkeleton = true
    @State private var showWristPath = true
    @State private var selectedPhase = SwingPhaseName.address
    @State private var progress = 0.0
    @State private var analysisTask: Task<Void, Never>?
    @State private var error: String?
    @State private var titleDraft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                videoSection
                recordingDetails
                analysisSection
                if let report { phaseSection(report); metricsSection(report) }
                limitations
            }.padding(.bottom, 32)
        }.background(SLTheme.background)
            .navigationTitle(recording.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let videoURL {
                    ShareLink(item: videoURL) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel(prefs.text("Export original video"))
                }
            }
            .task {
                titleDraft = recording.title
                report = recording.analysis
                do { let url = try VideoLibrary.url(for: recording.videoFileName); videoURL = url; playback.load(url) }
                catch { self.error = "The original video is no longer available." }
            }
            .onDisappear { analysisTask?.cancel(); analysisTask = nil; playback.close() }
            .alert(prefs.text("Swing review"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button(prefs.text("OK"), role: .cancel) { error = nil }
            } message: { Text(prefs.text(error ?? "")) }
    }

    private var videoSection: some View {
        VStack(spacing: 14) {
            if videoURL != nil {
                SwingVideoStage(player: playback.player, report: report, time: playback.time,
                                aspectRatio: max(0.1, recording.videoWidth / max(recording.videoHeight, 1)),
                                showSkeleton: showSkeleton, showWristPath: showWristPath)
                    .frame(height: 370).background(.black)
            } else {
                ContentUnavailableView(prefs.text("Video unavailable"), systemImage: "video.slash")
                    .frame(height: 220)
            }
            VStack(spacing: 12) {
                Slider(value: Binding(get: { min(playback.time, recording.durationSeconds) }, set: { playback.seek($0) }),
                       in: 0...max(0.01, recording.durationSeconds)).tint(SLTheme.forest)
                    .accessibilityLabel(prefs.text("Video position"))
                HStack {
                    SLMetricReadout(metric: ProvenancedValue(value: playback.time, unit: "s", provenance: .measured,
                                                             method: "video.playbackTimestamp.v1"),
                                    fractionDigits: 3, valueFont: .caption, alignment: .leading)
                        .frame(minWidth: 60, alignment: .leading)
                    Spacer()
                    Button { playback.step(-1) } label: { Image(systemName: "backward.end").frame(width: 44, height: 44) }
                        .accessibilityLabel(prefs.text("Previous frame"))
                    Button { playback.toggle() } label: {
                        Image(systemName: playback.playing ? "pause.fill" : "play.fill")
                            .frame(width: 48, height: 44).font(.title3)
                    }.accessibilityLabel(prefs.text(playback.playing ? "Pause" : "Play"))
                    Button { playback.step(1) } label: { Image(systemName: "forward.end").frame(width: 44, height: 44) }
                        .accessibilityLabel(prefs.text("Next frame"))
                    Spacer()
                    Menu {
                        ForEach([0.25, 0.5, 1.0], id: \.self) { rate in
                            Button(rate.formatted(.number.precision(.fractionLength(0...2)).locale(prefs.locale)) + "×") {
                                playback.playbackRate = Float(rate)
                                if playback.playing { playback.player.playImmediately(atRate: Float(rate)) }
                            }
                        }
                    } label: { Text(Double(playback.playbackRate).formatted(.number.locale(prefs.locale)) + "×").font(.subheadline.monospacedDigit()) }
                }.tint(SLTheme.forest).disabled(videoURL == nil)
                if report != nil {
                    HStack {
                        Toggle(prefs.text("Skeleton"), isOn: $showSkeleton)
                        Toggle(prefs.text("Wrist path"), isOn: $showWristPath)
                    }.toggleStyle(.button).font(.caption).tint(SLTheme.forest)
                }
            }.padding(.horizontal, 20)
        }
    }

    private var recordingDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField(prefs.text("Recording name"), text: $titleDraft).font(.headline)
                Button(prefs.text("Save")) {
                    let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let old = recording.title
                    recording.title = trimmed
                    do { try modelContext.save() } catch { recording.title = old; self.error = "Changes could not be saved." }
                }.disabled(titleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || titleDraft == recording.title)
            }
            Picker(prefs.text("Camera angle"), selection: $recording.cameraAngleValue) {
                ForEach(CameraAngle.allCases, id: \.self) { Text(prefs.text($0.localizationKey)).tag($0) }
            }.pickerStyle(.segmented)
                .onChange(of: recording.cameraAngleValue) { _, _ in
                    do { try modelContext.save() } catch { self.error = "Changes could not be saved." }
                }
            Picker(prefs.text("Handedness"), selection: $recording.handednessOverride) {
                Text(prefs.text("Use default handedness")).tag(Optional<Handedness>.none)
                ForEach(Handedness.allCases, id: \.self) { hand in
                    Text(prefs.text(hand.localizationKey)).tag(Optional(hand))
                }
            }.onChange(of: recording.handednessOverride) { _, _ in
                do { try modelContext.save() }
                catch { modelContext.rollback(); self.error = "Changes could not be saved." }
            }
            if let analyzedHandedness = report?.analyzedHandedness,
               analyzedHandedness != recording.effectiveHandedness(default: prefs.handedness) {
                Text(prefs.text("Handedness changed. Analyze again to update lead and trail joints."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text(prefs.text(recording.sourceValue.localizationKey))
                Spacer()
                SLMetricReadout(metric: recording.frameRateMetric, label: prefs.text("nominal fps"),
                                fractionDigits: 2, valueFont: .caption)
            }.font(.caption).foregroundStyle(.secondary)
        }.padding(.horizontal, 20)
    }

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SLSectionHeader(title: prefs.text("Understand the movement"), subtitle: prefs.text("On-device body pose"))
            if analysisTask != nil {
                ProgressView(value: progress) { Text(prefs.text("Analyzing video…")) }.tint(SLTheme.forest)
                Button(prefs.text("Cancel analysis"), role: .cancel) { analysisTask?.cancel() }
            } else {
                Button(action: analyze) {
                    Label(prefs.text((report?.sampledFrameCount ?? 0) == 0 ? "Analyze body pose" : "Analyze again"), systemImage: "figure.stand")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }.buttonStyle(.borderedProminent).tint(SLTheme.forest).disabled(videoURL == nil)
                if report == nil {
                    Button(prefs.text("Add manual phase markers")) {
                        let manual = PoseAnalysisReport(frames: [], markers: [], analyzedAt: .now,
                                                        sampledFrameCount: 0, poseFrameCount: 0, sampleRateLimit: 0, notes: [])
                        do { try persist(manual) } catch { self.error = "Changes could not be saved." }
                    }.disabled(videoURL == nil)
                }
            }
            if let report {
                HStack {
                    SLMetricReadout(metric: ProvenancedValue(value: Double(report.poseFrameCount), unit: "1",
                                                             provenance: .visionDerived, method: "pose.observationCount.v1",
                                                             sampleCount: report.sampledFrameCount),
                                    label: prefs.text("Frames with pose"), valueFont: .caption, alignment: .leading)
                    Spacer()
                    SLMetricReadout(metric: ProvenancedValue(value: report.poseFrameRate, unit: "Hz", provenance: .measured,
                                                             method: "pose.sampleInterval.v2"),
                                    label: prefs.text("Pose frame rate"), fractionDigits: 1, valueFont: .caption)
                }.font(.caption).foregroundStyle(.secondary)
            }
            Text(prefs.text("Analysis first scans the clip, then samples the swing window at up to 240 frames per second."))
                .font(.caption).foregroundStyle(.secondary)
            Text(prefs.text("Short interpolated gaps are dashed. Longer gaps are not connected."))
                .font(.caption).foregroundStyle(.secondary)
        }.padding(20).background(SLTheme.surface).padding(.horizontal, 20)
    }

    private func phaseSection(_ report: PoseAnalysisReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SLSectionHeader(title: prefs.text("Review the phases"), subtitle: prefs.text("Move to a frame, then set a marker."))
            Text(prefs.text("Automatic markers are unvalidated estimates. Wrist motion does not establish ball impact. Correct the markers before interpreting tempo."))
                .font(.caption).foregroundStyle(.secondary)
            ForEach(SwingPhaseName.allCases) { phase in
                HStack {
                    Button {
                        selectedPhase = phase
                        if let marker = report.marker(phase) { playback.seek(marker.time) }
                    } label: {
                        HStack {
                            Image(systemName: selectedPhase == phase ? "circle.inset.filled" : "circle")
                            Text(prefs.text(phase.localizationKey)).font(.subheadline)
                            Spacer()
                            if let marker = report.marker(phase) {
                                SLMetricReadout(metric: marker.metric,
                                                fractionDigits: 3, valueFont: .subheadline)
                            } else { Text(prefs.text("Unset")).font(.caption).foregroundStyle(.secondary) }
                        }.frame(minHeight: 40).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                Divider()
            }
            HStack {
                Button(prefs.text("Set at current frame")) { setMarker() }.buttonStyle(.borderedProminent).tint(SLTheme.forest)
                Button(prefs.text("Clear")) { clearMarker() }.buttonStyle(.bordered)
                    .disabled(report.marker(selectedPhase) == nil)
            }.disabled(analysisTask != nil || videoURL == nil)
        }.padding(.horizontal, 20)
    }

    private func metricsSection(_ report: PoseAnalysisReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SLSectionHeader(title: prefs.text("Timing & movement"), subtitle: prefs.text("Set address, top, and impact markers."))
            if report.tempoRatio != nil {
                HStack(alignment: .firstTextBaseline) {
                    SLMetricReadout(metric: report.tempoMetric, label: prefs.text("Tempo ratio"), fractionDigits: 2, displayAsRatio: true,
                                    valueFont: .system(size: 44, weight: .light), alignment: .leading)
                    Spacer()
                    Text(prefs.text("Backswing / downswing")).font(.caption).foregroundStyle(.secondary)
                }
            }
            SLMetricReadout(metric: report.backswingMetric, label: prefs.text("Backswing"), fractionDigits: 3,
                            valueFont: .subheadline, alignment: .leading)
            SLMetricReadout(metric: report.downswingMetric, label: prefs.text("Downswing"), fractionDigits: 3,
                            valueFont: .subheadline, alignment: .leading)
            SLMetricReadout(metric: report.headDisplacementMetric, label: prefs.text("Head displacement"), fractionDigits: 1,
                            displayAsPercent: true, valueFont: .subheadline, alignment: .leading)
            if report.headMovementPercent != nil {
                Text(prefs.text("Vision-derived maximum nose displacement from address to impact in normalized image coordinates. Camera motion and perspective affect this proxy."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(prefs.text("Compare recordings from the same camera angle and position. These are 2D projections, not anatomical 3D measurements."))
                .font(.caption).foregroundStyle(.secondary)
        }.padding(20).background(SLTheme.surface).padding(.horizontal, 20)
    }

    private var limitations: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(prefs.text("Measurement boundaries")).font(.headline)
            Text(prefs.text("Club-head speed, ball speed, launch angle, carry, and spin are unavailable. No trained club or ball detector is included. Body pose does not measure these values."))
                .font(.caption).foregroundStyle(.secondary)
        }.padding(.horizontal, 20)
    }

    private func analyze() {
        guard let videoURL else { return }
        playback.player.pause(); progress = 0
        analysisTask = Task { @MainActor in
            defer { analysisTask = nil }
            do {
                var result = try await PoseEstimationService().analyze(url: videoURL,
                    handedness: recording.effectiveHandedness(default: prefs.handedness)) { value in
                    Task { @MainActor in progress = value }
                }
                try Task.checkCancellation()
                result.markers = SwingPhaseDetector.merge(estimated: result.markers, existing: report?.markers ?? [])
                try persist(result)
            } catch is CancellationError { }
            catch { self.error = (error as? PoseAnalysisError)?.errorDescription ?? "Analysis could not be completed. Please try another video." }
        }
    }

    private func setMarker() {
        guard var updated = report, let index = SwingPhaseName.allCases.firstIndex(of: selectedPhase) else { return }
        let time = playback.time
        let ordered = SwingPhaseName.allCases
        let earlier = updated.markers.filter { (ordered.firstIndex(of: $0.phase) ?? 0) < index }.map(\.time).max()
        let later = updated.markers.filter { (ordered.firstIndex(of: $0.phase) ?? 0) > index }.map(\.time).min()
        guard time >= 0, time <= recording.durationSeconds, earlier.map({ time > $0 }) ?? true,
              later.map({ time < $0 }) ?? true else {
            error = "Phase markers must follow chronological order. Clear a conflicting marker or choose another frame."; return
        }
        updated.markers.removeAll { $0.phase == selectedPhase }
        updated.markers.append(SwingPhaseMarker(phase: selectedPhase, time: time, provenance: .userEntered,
                                               rule: "phase.manual.v1"))
        do { try persist(updated) } catch { self.error = "Changes could not be saved." }
    }

    private func clearMarker() {
        guard var updated = report else { return }
        updated.markers.removeAll { $0.phase == selectedPhase }
        do { try persist(updated) } catch { self.error = "Changes could not be saved." }
    }

    private func persist(_ result: PoseAnalysisReport) throws {
        try recording.applyAnalysis(result)
        do { try modelContext.save(); report = result }
        catch { modelContext.rollback(); throw error }
    }
}
