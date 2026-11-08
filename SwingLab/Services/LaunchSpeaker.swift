import Foundation
import AVFoundation
import SwingLabCore

/// Reads a measured shot aloud so the phone can stay on its stand. Only the measured ball speed
/// and launch angle and the simulated carry bracket are spoken, each with its unit, in the app
/// language; spin and club speed are never read out as if they were measured.
@MainActor
final class LaunchSpeaker {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ readout: LaunchReadout, preferences: AppPreferences) {
        guard preferences.launchVoiceEnabled, let voice = AVSpeechSynthesisVoice(language: preferences.resolvedLanguage) else { return }
        let speed = SLMetricReadout.formattedValue(readout.ballSpeed, preferences: preferences, fractionDigits: 0)
        let angle = SLMetricReadout.formattedValue(readout.launchAngle, preferences: preferences, fractionDigits: 0)
        var sentence = preferences.format("launch.voice.launch", speed, angle)
        if let carry = readout.carry, carry.isAvailable {
            let shortest = SLMetricReadout.formattedValue(carry.low, preferences: preferences)
            let longest = SLMetricReadout.formattedValue(carry.high, preferences: preferences)
            sentence += " " + preferences.format("launch.voice.carry", shortest, longest)
        }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: sentence)
        utterance.voice = voice
        utterance.rate = Float(preferences.speechRate)
        synthesizer.speak(utterance)
    }

    func stop() { synthesizer.stopSpeaking(at: .immediate) }
}
