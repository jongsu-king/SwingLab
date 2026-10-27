import XCTest
import SwingLabCore
@testable import SwingLab

/// A file that is not a movie must fail with an error at every entry point, never crash or hang
/// (Acceptance A20, corrupt video).
final class CorruptVideoTests: XCTestCase {
    private func corruptMovie() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        var bytes = [UInt8](repeating: 0, count: 64 * 1024)
        for index in bytes.indices { bytes[index] = UInt8(truncatingIfNeeded: index &* 31 &+ 7) }
        try Data(bytes).write(to: url)
        return url
    }

    func testImportMetadataRejectsACorruptMovie() async throws {
        let url = try corruptMovie()
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            _ = try await VideoLibrary.metadata(for: url)
            XCTFail("A corrupt movie must not produce metadata")
        } catch {}
    }

    func testPoseAnalysisRejectsACorruptMovie() async throws {
        let url = try corruptMovie()
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            _ = try await PoseEstimationService().analyze(url: url) { _ in }
            XCTFail("A corrupt movie must not produce a pose report")
        } catch {}
    }

    func testLaunchMeasurementRejectsACorruptMovie() async throws {
        let url = try corruptMovie()
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            _ = try await LaunchVideoAnalyzer().addressFrame(url: url)
            XCTFail("A corrupt movie must not produce an address frame")
        } catch {}
    }

    func testLibraryRefusesNamesOutsideItsFolder() {
        XCTAssertThrowsError(try VideoLibrary.url(for: "../escape.mov"))
        XCTAssertThrowsError(try VideoLibrary.url(for: ""))
        XCTAssertThrowsError(try VideoLibrary.url(for: "missing-\(UUID().uuidString).mov"))
    }
}
