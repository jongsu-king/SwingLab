import Foundation
import CoreGraphics
import SwingLabCore
// The asset and generator stay confined to this actor.
@preconcurrency import AVFoundation

enum LaunchVideoError: LocalizedError, Equatable {
    case lowFrameRate, noImpactSound, unreadable, scaleNotFound, launch(LaunchFailure)

    /// Localization keys (full English sentences) shown by the launch screen.
    var key: LocalizationKey {
        switch self {
        case .lowFrameRate: "Launch measurement needs a video recorded at 200 fps or more."
        case .noImpactSound: "No single clear impact sound was found, so the launch frames cannot be located."
        case .unreadable: "This video could not be read for launch measurement."
        case .scaleNotFound: "The ball was not found at the point you tapped. Tap the centre of the ball at address."
        case .launch(.exposureTooLong), .launch(.tooBlurred):
            "The ball is too blurred to measure. Record in bright light with a fast shutter."
        case .launch(.ballNotFound), .launch(.tooFewObservations):
            "The ball could not be followed after impact. Keep the first metre of flight in the frame."
        case .launch(.implausibleSpeed): "The measured motion is not plausible for a struck ball, so no value is shown."
        }
    }

    init(_ failure: LaunchPipelineFailure) {
        switch failure {
        case .scaleNotFound: self = .scaleNotFound
        case .missingFrames: self = .unreadable
        case let .launch(reason): self = .launch(reason)
        }
    }
}

/// Measures a face-on launch from a high-frame-rate movie (`Docs/Specs/LaunchMonitor.md`).
/// Experimental: no real-shot validation exists yet (Acceptance A22/A23).
actor LaunchVideoAnalyzer {
    struct Outcome: Sendable {
        let measurement: LaunchMeasurement
        let impactTime: Double
        let scale: BallScale
    }

    /// The still frame the user taps on: 0.2 s before the impact sound.
    func addressFrame(url: URL) async throws -> (image: CGImage, impactTime: Double) {
        let asset = AVURLAsset(url: url)
        let impact = try await impactTime(asset: asset)
        let generator = Self.generator(asset)
        let (image, _) = try await generator.image(at: CMTime(seconds: max(0, impact - 0.2), preferredTimescale: 600_000))
        return (image, impact)
    }

    /// `ballPoint` is in the oriented address frame, normalized with origin top-left.
    func measure(url: URL, impactTime: Double, ballPoint: CGPoint, targetDirection: Double) async throws -> Outcome {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw LaunchVideoError.unreadable }
        let fps = Double(try await track.load(.nominalFrameRate))
        guard fps >= 200 else { throw LaunchVideoError.lowFrameRate }
        let generator = Self.generator(asset)
        func grab(_ seconds: Double) async throws -> (time: Double, image: CGImage) {
            let (image, actual) = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600_000))
            return (actual.seconds, image)
        }
        var addressImages: [(time: Double, image: CGImage)] = [], flightImages: [(time: Double, image: CGImage)] = []
        for lead in LiveLaunchSession.addressLeads { addressImages.append(try await grab(max(0, impactTime - lead))) }
        for index in 1...LiveLaunchSession.flightFrameCount { flightImages.append(try await grab(impactTime + Double(index) / fps)) }
        guard let first = addressImages.first?.image else { throw LaunchVideoError.unreadable }
        let width = first.width, height = first.height
        let ball = PixelPoint(x: ballPoint.x * Double(width), y: ballPoint.y * Double(height))
        guard let region = LaunchRegion.around(ball: ball, frameWidth: width, frameHeight: height, targetDirection: targetDirection) else {
            throw LaunchVideoError.unreadable
        }
        let roi = CGRect(x: region.x, y: region.y, width: region.width, height: region.height)
        let address = addressImages.compactMap { Self.gray($0.image, roi: roi) }
        let flight = flightImages.compactMap { item in Self.gray(item.image, roi: roi).map { (time: item.time, image: $0) } }
        guard address.count == addressImages.count, flight.count == flightImages.count else { throw LaunchVideoError.unreadable }
        switch LaunchPipeline.measure(address: address, flight: flight,
                                      ball: PixelPoint(x: ball.x - Double(region.x), y: ball.y - Double(region.y)),
                                      searchRadius: LaunchRegion.searchRadius(frameWidth: width), targetDirection: targetDirection) {
        case let .success(found): return Outcome(measurement: found.measurement, impactTime: impactTime, scale: found.scale)
        case let .failure(reason): throw LaunchVideoError(reason)
        }
    }

    private func impactTime(asset: AVAsset) async throws -> Double {
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0.5 else { throw LaunchVideoError.unreadable }
        guard let audio = try await AudioImpactReader.read(asset: asset, range: 0...duration) else { throw LaunchVideoError.noImpactSound }
        switch ImpactOnsetDetector.detect(samples: audio.samples, sampleRate: audio.sampleRate, startTime: audio.startTime,
                                          window: max(0.3, audio.startTime)...duration, poseImpact: nil) {
        case let .success(estimate) where estimate.provenance == .audioDerived: return estimate.time
        default: throw LaunchVideoError.noImpactSound
        }
    }

    private static func generator(_ asset: AVAsset) -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return generator
    }

    /// Luminance of one region in 0...1, rows top to bottom.
    private static func gray(_ image: CGImage, roi: CGRect) -> GrayImage? {
        guard let cropped = image.cropping(to: roi) else { return nil }
        let width = cropped.width, height = cropped.height
        var bytes = [UInt8](repeating: 0, count: width * height)
        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        return GrayImage(width: width, height: height, pixels: bytes.map { Float($0) / 255 })
    }
}
