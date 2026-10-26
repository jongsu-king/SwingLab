import SwiftUI
import SwiftData
import SwingLabCore
// AVSpeechSynthesizer and AVPlayer stay on the SwiftUI main actor; no framework objects cross actors.
@preconcurrency import AVFoundation

struct SwingComparisonView: View {
    @Environment(AppPreferences.self) private var prefs
    @Query(sort: \SwingRecording.createdAt, order: .reverse) private var recordings: [SwingRecording]
    @State private var leftID: UUID?
    @State private var rightID: UUID?
    @State private var left = VideoPlaybackController()
    @State private var right = VideoPlaybackController()
    @State private var firstReport: PoseAnalysisReport?
    @State private var secondReport: PoseAnalysisReport?
    @State private var offset = 0.0
    @State private var opacity = 0.5
    @State private var overlay = false
    @State private var showPose = true
    @State private var running = false
    @State private var error: String?
    @State private var speaker = AVSpeechSynthesizer()

    private var first: SwingRecording? { recordings.first { $0.id == leftID } }
    private var second: SwingRecording? { recordings.first { $0.id == rightID } }
    private var selectionKey: String { (leftID?.uuidString ?? "") + (rightID?.uuidString ?? "") }
    private var shift: Double {
        (secondReport?.marker(.impact)?.time ?? 0) - (firstReport?.marker(.impact)?.time ?? 0) + offset
    }
    private var start: Double { max(0, -shift) }
    private var end: Double { min(first?.durationSeconds ?? 0, (second?.durationSeconds ?? 0) - shift) }
    private var sameAngle: Bool { first?.cameraAngleValue == second?.cameraAngleValue && first?.cameraAngleValue != .unspecified }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if recordings.count < 2 {
                    SLEmptyState(title: prefs.text("Two swings, one perspective"),
                                 message: prefs.text("Record or import two swings to compare their movement and timing."), symbol: "rectangle.split.2x1")
                } else {
                    selection
                    if let first, let second {
                        if !sameAngle {
                            Label(prefs.text("Different or unspecified camera angles. Movement comparisons may be misleading."), systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if (firstReport?.analyzedHandedness ?? first.effectiveHandedness(default: prefs.handedness)) !=
                            (secondReport?.analyzedHandedness ?? second.effectiveHandedness(default: prefs.handedness)) {
                            Label(prefs.text("Different handedness. Movement comparisons may be misleading."), systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if abs(first.nominalFrameRate - second.nominalFrameRate) > 0.5 {
                            Label(prefs.text("Different frame rates. Timing precision may differ."), systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Group {
                            if overlay {
                                ZStack {
                                    stage(first, playback: left)
                                    stage(second, playback: right).opacity(opacity)
                                }
                            } else {
                                HStack(spacing: 2) { stage(first, playback: left); stage(second, playback: right) }
                            }
                        }.frame(height: 320).background(.black)
                        HStack {
                            Toggle(prefs.text("Overlay"), isOn: $overlay)
                            Toggle(prefs.text("Skeleton"), isOn: $showPose)
                        }.toggleStyle(.button).tint(SLTheme.forest)
                        if overlay { Slider(value: $opacity, in: 0...1).accessibilityLabel(prefs.text("Overlay opacity")) }
                        playbackControls
                        alignment
                        coaching
                    }
                }
            }.padding(20)
        }.background(SLTheme.background)
            .navigationTitle(prefs.text("Compare swings")).navigationBarTitleDisplayMode(.inline)
            .onAppear { if leftID == nil { leftID = recordings.first?.id; rightID = recordings.dropFirst().first?.id } }
            .task(id: selectionKey) { loadPlayers() }
            .onChange(of: left.time) { _, time in
                if running, time >= end - 0.02 { pause() }
                else if !running { right.seek(min(max(0, time + shift), second?.durationSeconds ?? 0)) }
            }
            .onChange(of: offset) { _, _ in seek(min(max(start, left.time), max(start, end))) }
            .onDisappear { pause(); left.close(); right.close(); speaker.stopSpeaking(at: .immediate) }
            .alert(prefs.text("Comparison"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button(prefs.text("OK"), role: .cancel) { error = nil }
            } message: { Text(prefs.text(error ?? "")) }
    }

    private var selection: some View {
        VStack(spacing: 12) {
            Picker(prefs.text("First recording"), selection: $leftID) {
                ForEach(recordings) { Text($0.title + " · " + $0.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute().locale(prefs.locale))).tag(Optional($0.id)) }
            }
            Picker(prefs.text("Second recording"), selection: $rightID) {
                ForEach(recordings.filter { $0.id != leftID }) {
                    Text($0.title + " · " + $0.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute().locale(prefs.locale))).tag(Optional($0.id))
                }
            }
        }.pickerStyle(.menu).tint(SLTheme.forest)
            .onChange(of: leftID) { _, value in if rightID == value { rightID = recordings.first { $0.id != value }?.id } }
    }

    private func stage(_ recording: SwingRecording, playback: VideoPlaybackController) -> some View {
        SwingVideoStage(player: playback.player, report: recording.id == first?.id ? firstReport : secondReport, time: playback.time,
                        aspectRatio: max(0.1, recording.videoWidth / max(recording.videoHeight, 1)),
                        showSkeleton: showPose, showWristPath: showPose)
    }

    private var playbackControls: some View {
        VStack(spacing: 10) {
            if end > start {
                Slider(value: Binding(get: { min(max(start, left.time), end) }, set: { seek($0) }), in: start...end)
                    .accessibilityLabel(prefs.text("Comparison position"))
            }
            HStack {
                Button { pause(); left.step(-1) } label: { Image(systemName: "backward.end").frame(width: 44, height: 44) }
                    .accessibilityLabel(prefs.text("Previous frame"))
                Button { if running { pause() } else { play() } } label: {
                    Image(systemName: running ? "pause.fill" : "play.fill").frame(width: 44, height: 44)
                }.accessibilityLabel(prefs.text(running ? "Pause" : "Play"))
                Button { pause(); left.step(1) } label: { Image(systemName: "forward.end").frame(width: 44, height: 44) }
                    .accessibilityLabel(prefs.text("Next frame"))
                Spacer()
                Picker(prefs.text("Playback speed"), selection: $left.playbackRate) {
                    ForEach([0.25, 0.5, 1.0], id: \.self) { rate in
                        Text(rate.formatted(.number.locale(prefs.locale)) + "×").tag(Float(rate))
                    }
                }.pickerStyle(.menu).onChange(of: left.playbackRate) { _, _ in if running { play() } }
            }.tint(SLTheme.forest).disabled(end <= start)
        }
    }

    private var alignment: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(prefs.text("Alignment")).font(.headline)
            Text(prefs.text(firstReport?.marker(.impact) != nil && secondReport?.marker(.impact) != nil
                            ? "Aligned at impact markers. Estimated markers require review."
                            : "Aligned at clip starts. Set impact markers in both reviews for phase alignment."))
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(prefs.text("Manual offset"))
                Spacer()
                SLMetricReadout(metric: ProvenancedValue(value: offset, unit: "s", provenance: .userEntered,
                                                         method: "comparison.manualOffset.v1"),
                                fractionDigits: 3, valueFont: .caption)
            }.font(.caption)
            Slider(value: $offset, in: -2...2, step: 0.001).accessibilityLabel(prefs.text("Manual offset"))
            Button(prefs.text("Reset alignment")) { offset = 0; seek(start) }.font(.caption)
        }
    }

    private var coaching: some View {
        VStack(alignment: .leading, spacing: 12) {
            SLSectionHeader(title: prefs.text("Practice observation"), subtitle: prefs.text("Based on your phase markers"))
            if sameAngle, let a = firstReport, let b = secondReport,
               a.tempoRatio != nil, b.tempoRatio != nil {
                HStack {
                    Text(prefs.text("Tempo ratio")); Spacer()
                    SLMetricReadout(metric: a.tempoMetric, fractionDigits: 2, displayAsRatio: true, valueFont: .subheadline)
                    Image(systemName: "arrow.right")
                    SLMetricReadout(metric: b.tempoMetric, fractionDigits: 2, displayAsRatio: true, valueFont: .subheadline)
                }.font(.subheadline).monospacedDigit()
                let message = coachingKey(a, b)
                Text(prefs.text(message)).font(.subheadline)
                Text(prefs.text("Timing depends on marker accuracy. This comparison does not diagnose a swing fault."))
                    .font(.caption).foregroundStyle(.secondary)
                if prefs.voiceEnabled, let voice = AVSpeechSynthesisVoice(language: prefs.resolvedLanguage) {
                    Button {
                        pause()
                        speaker.stopSpeaking(at: .immediate)
                        let utterance = AVSpeechUtterance(string: prefs.text(message))
                        utterance.voice = voice
                        utterance.rate = Float(prefs.speechRate)
                        speaker.speak(utterance)
                    } label: { Label(prefs.text("Read observation"), systemImage: "speaker.wave.2") }
                }
            } else {
                Text(prefs.text("Analyze both recordings, use the same camera angle, and set address, top, and impact markers to compare tempo."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(16).background(SLTheme.surface)
    }

    private func coachingKey(_ first: PoseAnalysisReport, _ second: PoseAnalysisReport) -> String {
        guard let a = first.backswingDuration, let b = second.backswingDuration else { return "Review both phase timelines before comparing timing." }
        if b > a { return "The second recording has a longer backswing. Repeat the same drill and compare your next recording." }
        if b < a { return "The second recording has a shorter backswing. Repeat the same drill and compare your next recording." }
        return "Both recordings have the same marked backswing duration. Repeat the drill to check consistency."
    }

    private func loadPlayers() {
        pause(); offset = 0; left.close(); right.close()
        guard let first, let second else { return }
        firstReport = first.analysis; secondReport = second.analysis
        do {
            left.load(try VideoLibrary.url(for: first.videoFileName))
            right.load(try VideoLibrary.url(for: second.videoFileName))
            left.player.isMuted = true; right.player.isMuted = true
            seek(start)
        } catch { self.error = "The original video is no longer available." }
    }
    private func pause() { running = false; left.player.pause(); right.player.pause() }
    private func seek(_ time: Double) { pause(); left.seek(time); right.seek(time + shift) }
    private func play() {
        guard end > start, left.player.currentItem?.status == .readyToPlay, right.player.currentItem?.status == .readyToPlay else { return }
        let time = left.time >= end - 0.05 ? start : min(max(start, left.time), end)
        // A shared host-clock deadline keeps both players on the same timeline, even at slow speed.
        let host = CMTimeAdd(CMClockGetTime(CMClockGetHostTimeClock()), CMTime(seconds: 0.15, preferredTimescale: 600))
        left.player.setRate(left.playbackRate, time: CMTime(seconds: time, preferredTimescale: 60_000), atHostTime: host)
        right.player.setRate(left.playbackRate, time: CMTime(seconds: time + shift, preferredTimescale: 60_000), atHostTime: host)
        running = true
    }
}
