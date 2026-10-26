import Foundation
import Observation
@preconcurrency import AVFoundation

@Observable @MainActor
final class VideoPlaybackController {
    let player = AVPlayer()
    var time = 0.0
    var playing = false
    var playbackRate: Float = 0.5
    @ObservationIgnored private var observer: Any?
    func load(_ url: URL) {
        close()
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.time = time.seconds.isFinite ? time.seconds : 0
                self.playing = self.player.rate != 0
            }
        }
    }
    func toggle() {
        if player.rate != 0 { player.pause(); playing = false }
        else {
            if let duration = player.currentItem?.duration.seconds, duration.isFinite, time >= duration - 0.05 { seek(0) }
            player.playImmediately(atRate: playbackRate)
            playing = true
        }
    }
    func seek(_ seconds: Double) {
        player.pause(); playing = false; time = max(0, seconds)
        player.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 60_000), toleranceBefore: .zero, toleranceAfter: .zero)
    }
    func step(_ count: Int) {
        player.pause(); playing = false
        // AVPlayerItem steps through real media samples instead of assuming a fixed frame rate.
        player.currentItem?.step(byCount: count)
    }
    func close() {
        player.pause(); playing = false; time = 0
        if let observer { player.removeTimeObserver(observer); self.observer = nil }
        player.replaceCurrentItem(with: nil)
    }
}
