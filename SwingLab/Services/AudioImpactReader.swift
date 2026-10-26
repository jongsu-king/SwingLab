import Foundation
import SwingLabCore
// The asset, track, reader, and sample buffers stay confined to the calling actor.
@preconcurrency import AVFoundation

/// Reads only the kinematic window of a movie's first audio track as mono Float32 PCM.
/// Audio and video share the movie's timeline, so buffer timestamps are video times.
enum AudioImpactReader {
    struct Window {
        var samples: [Float]
        var sampleRate: Double
        var startTime: Double
    }

    /// Nil when the movie has no audio track (mic denied, or an imported silent clip).
    static func read(asset: AVAsset, range: ClosedRange<Double>) async throws -> Window? {
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return nil }
        let formats = try await track.load(.formatDescriptions)
        guard let format = formats.first,
              let description = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee,
              description.mSampleRate >= 8_000 else { return nil }
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: range.lowerBound, preferredTimescale: 600_000),
                                      end: CMTime(seconds: range.upperBound, preferredTimescale: 600_000))
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: description.mSampleRate
        ])
        guard reader.canAdd(output) else { return nil }
        reader.add(output)
        guard reader.startReading() else { return nil }
        defer { reader.cancelReading() }
        var samples: [Float] = []
        var startTime: Double?
        while let buffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            if startTime == nil {
                let time = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
                if time.isFinite { startTime = time }
            }
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let count = CMBlockBufferGetDataLength(block) / MemoryLayout<Float>.size
            guard count > 0 else { continue }
            var chunk = [Float](repeating: 0, count: count)
            let byteCount = count * MemoryLayout<Float>.size
            let status = chunk.withUnsafeMutableBytes { bytes in
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: byteCount, destination: bytes.baseAddress!)
            }
            guard status == kCMBlockBufferNoErr else { return nil }
            samples += chunk
        }
        guard reader.status == .completed, let startTime, !samples.isEmpty else { return nil }
        return Window(samples: samples, sampleRate: description.mSampleRate, startTime: startTime)
    }
}
