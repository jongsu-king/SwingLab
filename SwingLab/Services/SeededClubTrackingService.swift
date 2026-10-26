import Foundation
import ImageIO
import UniformTypeIdentifiers
import SwingLabCore
// AVFoundation objects and image buffers remain confined to this actor; only Data/value points cross it.
@preconcurrency import AVFoundation
import Vision

actor SeededClubTrackingService {
    func addressImage(url: URL, time: Double) async throws -> Data {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 1280, height: 1280)
        let result = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 60000))
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { throw ModelError.invalidInput }
        CGImageDestinationAddImage(destination, result.image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ModelError.invalidInput }
        return data as Data
    }

    func track(url: URL, seedX: Double, seedY: Double, address: Double, top: Double) async throws -> SeededClubTrack {
        guard [seedX, seedY, address, top].allSatisfy(\.isFinite), (0...1).contains(seedX), (0...1).contains(seedY),
              address >= 0, top > address, top - address < 10 else { throw ModelError.invalidInput }
        let asset = AVURLAsset(url: url)
        guard let video = try await asset.loadTracks(withMediaType: .video).first else { throw ModelError.invalidInput }
        let transform = try await video.load(.preferredTransform)
        let orientation = try imageOrientation(transform)
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: address, preferredTimescale: 60000), end: CMTime(seconds: top, preferredTimescale: 60000))
        let output = AVAssetReaderTrackOutput(track: video, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw ModelError.invalidInput }
        reader.add(output)
        guard reader.startReading() else { throw ModelError.invalidInput }
        defer { reader.cancelReading() }
        let rect = CGRect(x: min(0.92, max(0, seedX - 0.04)), y: min(0.92, max(0, seedY - 0.04)), width: 0.08, height: 0.08)
        let request = VNTrackObjectRequest(detectedObjectObservation: VNDetectedObjectObservation(boundingBox: rect))
        request.trackingLevel = .accurate
        let handler = VNSequenceRequestHandler()
        var result = SeededClubTrack(endTime: top)
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            guard time >= address, time <= top else { continue }
            guard let buffer = CMSampleBufferGetImageBuffer(sample) else { result.markLost(at: time); break }
            try handler.perform([request], on: buffer, orientation: orientation)
            guard let observation = request.results?.first as? VNDetectedObjectObservation else { result.markLost(at: time); break }
            let box = observation.boundingBox
            guard result.append(.init(time: time, x: box.midX, y: box.midY, confidence: Double(observation.confidence))) else { break }
            request.inputObservation = observation
        }
        if reader.status == .failed { throw reader.error ?? ModelError.invalidInput }
        return result
    }
    private func imageOrientation(_ transform: CGAffineTransform) throws -> CGImagePropertyOrientation {
        let a = Int(transform.a.rounded()), b = Int(transform.b.rounded()), c = Int(transform.c.rounded()), d = Int(transform.d.rounded())
        return switch (a, b, c, d) {
        case (1, 0, 0, 1): .up
        case (0, 1, -1, 0): .right
        case (-1, 0, 0, -1): .down
        case (0, -1, 1, 0): .left
        case (-1, 0, 0, 1): .upMirrored
        case (1, 0, 0, -1): .downMirrored
        case (0, 1, 1, 0): .leftMirrored
        case (0, -1, -1, 0): .rightMirrored
        default: throw ModelError.invalidInput
        }
    }
}
