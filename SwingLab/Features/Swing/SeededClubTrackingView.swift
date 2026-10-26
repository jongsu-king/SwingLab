import SwiftUI
import UIKit
import SwingLabCore

struct SeededClubTrackingView: View {
    @Environment(AppPreferences.self) private var prefs
    let url: URL
    let address: Double?
    let top: Double?
    let aspectRatio: Double
    @State private var imageData: Data?
    @State private var seed: CGPoint?
    @State private var track: SeededClubTrack?
    @State private var playback = VideoPlaybackController()
    @State private var task: Task<Void, Never>?
    @State private var working = false
    @State private var error: LocalizationKey?
    private let service = SeededClubTrackingService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(prefs.text("Tap the club head at address. Tracking stops at the top or at the first loss of confidence."))
                    .font(.subheadline)
                if address == nil || top == nil || (top ?? 0) <= (address ?? 0) {
                    Text(prefs.text("Set Address and Top markers before tracking."))
                } else if let data = imageData, let image = UIImage(data: data) {
                    GeometryReader { geometry in
                        ZStack(alignment: .topLeading) {
                            Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
                            if let seed {
                                Circle().stroke(SLTheme.forest, lineWidth: 3).frame(width: 26, height: 26)
                                    .position(x: seed.x * geometry.size.width, y: (1 - seed.y) * geometry.size.height)
                            }
                        }.contentShape(Rectangle())
                            .onTapGesture { point in
                                seed = CGPoint(x: min(1, max(0, point.x / geometry.size.width)), y: min(1, max(0, 1 - point.y / geometry.size.height)))
                                track = nil
                            }
                    }.aspectRatio(image.size.width / image.size.height, contentMode: .fit)
                    Button(prefs.text("Track backswing"), action: run).buttonStyle(.borderedProminent)
                        .disabled(seed == nil || working)
                } else if error == nil { ProgressView() }
                if working { ProgressView() }
                if let track {
                    ProvenanceBadge(provenance: .visionDerived)
                    SwingVideoStage(player: playback.player, report: nil, time: playback.time, aspectRatio: aspectRatio,
                                    showSkeleton: false, showWristPath: false, clubTrack: track)
                        .frame(height: 320).background(.black)
                    Slider(value: Binding(get: { max(address ?? 0, min(playback.time, top ?? 1)) }, set: { playback.seek($0) }),
                           in: (address ?? 0)...max((address ?? 0) + 0.01, top ?? 1))
                        .accessibilityLabel(prefs.text("Video position"))
                    Button(prefs.text(playback.playing ? "Pause" : "Play")) { playback.toggle() }
                    if let lost = track.lostAt {
                        SLMetricReadout(metric: .init(value: lost, unit: "s", provenance: .visionDerived, method: "clubTrack.loss.v1"),
                                        label: prefs.text("Tracking lost"), fractionDigits: 3, alignment: .leading)
                    } else { Text(prefs.text("Tracking ended at the top marker.")) }
                }
                if let error { Text(prefs.text(error)).foregroundStyle(.red) }
                Text(prefs.text("The trace is image-space motion of the selected region. It does not measure club speed, ball launch or impact. Nothing is drawn after tracking loss."))
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }
        .navigationTitle(prefs.text("Club trace"))
        .task {
            guard let address, let top, top > address else { return }
            do { imageData = try await service.addressImage(url: url, time: address) }
            catch { self.error = "This video could not be decoded for analysis." }
        }
        .onDisappear { task?.cancel(); playback.close() }
    }
    private func run() {
        guard let seed, let address, let top else { return }
        working = true; error = nil
        task = Task { @MainActor in
            defer { working = false }
            do {
                let result = try await service.track(url: url, seedX: seed.x, seedY: seed.y, address: address, top: top)
                try Task.checkCancellation()
                track = result; playback.load(url); playback.seek(address)
            } catch is CancellationError { }
            catch { self.error = "This video could not be decoded for analysis." }
        }
    }
}
