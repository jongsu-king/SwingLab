import Foundation
import CoreTransferable
import UniformTypeIdentifiers
@preconcurrency import AVFoundation

enum VideoLibraryError: LocalizedError {
    case invalidVideo, tooLong, missingFile, insufficientStorage
    var errorDescription: String? {
        switch self {
        case .invalidVideo: "This file does not contain a readable video."
        case .tooLong: "Choose a video shorter than three minutes."
        case .missingFile: "The original video is no longer available."
        case .insufficientStorage: "There is not enough free storage to save this video."
        }
    }
}

struct VideoMetadata: Sendable {
    var duration: Double
    var frameRate: Double
    var width: Double
    var height: Double
}

enum VideoLibrary {
    static func directory() throws -> URL {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                appropriateFor: nil, create: true)
            .appendingPathComponent("SwingVideos", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func newURL(extension suffix: String = "mov") throws -> URL {
        try directory().appendingPathComponent(UUID().uuidString).appendingPathExtension(suffix)
    }

    static func url(for fileName: String) throws -> URL {
        guard !fileName.isEmpty, (fileName as NSString).lastPathComponent == fileName else {
            throw VideoLibraryError.missingFile
        }
        let url = try directory().appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { throw VideoLibraryError.missingFile }
        return url
    }

    static func remove(_ fileName: String) throws { try FileManager.default.removeItem(at: url(for: fileName)) }

    static func copyImport(_ source: URL) throws -> URL {
        let destination = try newURL(extension: source.pathExtension.isEmpty ? "mov" : source.pathExtension)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    static func metadata(for url: URL) async throws -> VideoMetadata {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoLibraryError.invalidVideo
        }
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw VideoLibraryError.invalidVideo }
        guard duration <= 180 else { throw VideoLibraryError.tooLong }
        let size = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let displayed = size.applying(transform)
        let frameRate = try await track.load(.nominalFrameRate)
        return VideoMetadata(duration: duration, frameRate: Double(frameRate),
                             width: abs(displayed.width), height: abs(displayed.height))
    }
}

struct ImportedSwingMovie: Transferable, Sendable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            // The picker URL is temporary. Copy it before this transfer closure returns.
            ImportedSwingMovie(url: try VideoLibrary.copyImport(received.file))
        }
    }
}
