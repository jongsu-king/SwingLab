import Foundation
import CoreVideo
import SwingLabCore
@preconcurrency import AVFoundation

@main struct VideoAnalysisChecks {
    static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for (name, transform) in [
            ("landscape", CGAffineTransform.identity),
            ("portrait", CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 240, ty: 0)),
            ("mirrored", CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 320, ty: 0))
        ] {
            let url = folder.appendingPathComponent(name + ".mov")
            try await makeBlankVideo(url, transform: transform)
            let metadata = try await VideoLibrary.metadata(for: url)
            guard metadata.duration > 0, metadata.frameRate > 0 else { throw CheckError.invalidMetadata }
            if name == "portrait", !(metadata.width == 240 && metadata.height == 320) { throw CheckError.invalidMetadata }
            do {
                _ = try await PoseEstimationService().analyze(url: url) { _ in }
                throw CheckError.fabricatedPose
            } catch PoseAnalysisError.noPose {
                print("PASS \(name) video decoding and honest no-pose result")
            }
        }
        let invalid = folder.appendingPathComponent("invalid.mov")
        try Data("not a movie".utf8).write(to: invalid)
        do {
            _ = try await VideoLibrary.metadata(for: invalid)
            throw CheckError.invalidAccepted
        } catch CheckError.invalidAccepted { throw CheckError.invalidAccepted }
        catch { print("PASS invalid video rejected") }

        // The camera writes AAC, whose encoder priming must not shift sound against the video timeline.
        for (name, format) in [("LPCM", kAudioFormatLinearPCM), ("AAC", kAudioFormatMPEG4AAC)] {
            let url = folder.appendingPathComponent("click-\(name).mov")
            try await makeClickMovie(url, format: format, clickTime: 1.25)
            guard let audio = try await AudioImpactReader.read(asset: AVURLAsset(url: url), range: 1.0...1.6) else {
                throw CheckError.audioTiming
            }
            guard case let .success(estimate) = ImpactOnsetDetector.detect(
                samples: audio.samples, sampleRate: audio.sampleRate, startTime: audio.startTime,
                window: 1.1...1.5, poseImpact: nil), abs(estimate.time - 1.25) < 0.002 else { throw CheckError.audioTiming }
            print(String(format: "PASS %@ click read on the movie timeline (error %+.2f ms)", name, (estimate.time - 1.25) * 1000))
        }
        let silent = folder.appendingPathComponent("silent.mov")
        try await makeBlankVideo(silent, transform: .identity)
        guard try await AudioImpactReader.read(asset: AVURLAsset(url: silent), range: 0...0.4) == nil else { throw CheckError.audioTiming }
        print("PASS movie without audio reports no audio")
    }

    enum CheckError: Error { case invalidMetadata, fabricatedPose, invalidAccepted, allocation, encoding, audioTiming }

    /// Two seconds of 48 kHz mono: low noise plus a 5 kHz click decaying with τ = 2 ms.
    static func makeClickMovie(_ url: URL, format: AudioFormatID, clickTime: Double) async throws {
        let rate = 48_000.0, frames = 96_000, chunk = 1_024
        var seed: UInt64 = 7
        let pcm: [Float] = (0..<frames).map { index in
            let t = Double(index) / rate
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            var value = 0.005 * (Double(seed >> 11) / Double(1 << 53) * 2 - 1)
            if t >= clickTime { value += 0.7 * exp(-(t - clickTime) / 0.002) * sin(2 * .pi * 5_000 * (t - clickTime)) }
            return Float(value)
        }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        var settings: [String: Any] = [AVFormatIDKey: format, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1]
        if format == kAudioFormatLinearPCM {
            settings.merge([AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true, AVLinearPCMIsBigEndianKey: false,
                            AVLinearPCMIsNonInterleaved: false]) { $1 }
        } else { settings[AVEncoderBitRateKey] = 128_000 }
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        writer.add(input)
        guard writer.startWriting() else { throw CheckError.encoding }
        writer.startSession(atSourceTime: .zero)
        var description = AudioStreamBasicDescription(mSampleRate: rate, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked, mBytesPerPacket: 4, mFramesPerPacket: 1,
            mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        var formatDescription: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &description, layoutSize: 0, layout: nil,
                                             magicCookieSize: 0, magicCookie: nil, extensions: nil,
                                             formatDescriptionOut: &formatDescription) == noErr,
              let formatDescription else { throw CheckError.allocation }
        for start in stride(from: 0, to: frames, by: chunk) {
            let count = min(chunk, frames - start), bytes = count * 4
            var block: CMBlockBuffer?
            guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: bytes,
                                                     blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0,
                                                     dataLength: bytes, flags: 0, blockBufferOut: &block) == kCMBlockBufferNoErr,
                  let block else { throw CheckError.allocation }
            let copied = pcm[start..<start + count].withUnsafeBytes { source in
                CMBlockBufferReplaceDataBytes(with: source.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: bytes)
            }
            var sample: CMSampleBuffer?
            guard copied == kCMBlockBufferNoErr,
                  CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: kCFAllocatorDefault, dataBuffer: block,
                      formatDescription: formatDescription, sampleCount: count,
                      presentationTimeStamp: CMTime(value: CMTimeValue(start), timescale: CMTimeScale(rate)),
                      packetDescriptions: nil, sampleBufferOut: &sample) == noErr,
                  let sample else { throw CheckError.allocation }
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else { throw CheckError.encoding }
                try await Task.sleep(for: .milliseconds(5))
            }
            guard input.append(sample) else { throw CheckError.encoding }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw CheckError.encoding }
    }

    static func makeBlankVideo(_ url: URL, transform: CGAffineTransform) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 320, AVVideoHeightKey: 240
        ])
        input.transform = transform
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
            sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                                         kCVPixelBufferWidthKey as String: 320,
                                         kCVPixelBufferHeightKey as String: 240])
        writer.add(input)
        guard writer.startWriting() else { throw CheckError.encoding }
        writer.startSession(atSourceTime: .zero)
        var buffer: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, 320, 240, kCVPixelFormatType_32BGRA, nil, &buffer) == kCVReturnSuccess,
              let buffer else { throw CheckError.allocation }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let bytes = CVPixelBufferGetBaseAddress(buffer) {
            memset(bytes, 0, CVPixelBufferGetBytesPerRow(buffer) * CVPixelBufferGetHeight(buffer))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        for index in 0..<12 {
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else { throw CheckError.encoding }
                try await Task.sleep(for: .milliseconds(5))
            }
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: 30)) else { throw CheckError.encoding }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw CheckError.encoding }
    }
}
