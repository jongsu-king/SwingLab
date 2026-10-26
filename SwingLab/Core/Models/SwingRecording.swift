import Foundation
import SwiftData
import SwingLabCore

@Model
final class SwingRecording {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var title: String
    var videoFileName: String
    var durationSeconds: Double
    var nominalFrameRate: Double
    var videoWidth: Double
    var videoHeight: Double
    // Preserve the Round 1 store columns. Only the typed accessors are used by UI.
    private(set) var cameraAngle: String
    private(set) var source: String
    @Attribute(.externalStorage) var analysisData: Data?

    init(title: String, videoFileName: String, durationSeconds: Double,
         nominalFrameRate: Double, videoWidth: Double, videoHeight: Double,
         cameraAngle: CameraAngle = .faceOn, source: RecordingSource = .recorded) {
        id = UUID()
        createdAt = .now
        self.title = title
        self.videoFileName = videoFileName
        self.durationSeconds = durationSeconds
        self.nominalFrameRate = nominalFrameRate
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.cameraAngle = cameraAngle.rawValue
        self.source = source.rawValue
    }

    var analysis: PoseAnalysisReport? {
        guard let analysisData else { return nil }
        return try? JSONDecoder().decode(PoseAnalysisReport.self, from: analysisData)
    }

    var tempoRatio: Double? { analysis?.tempoRatio }
    var tempoProvenance: Provenance? { analysis?.timingProvenance }

    var cameraAngleValue: CameraAngle {
        get { CameraAngle(legacyValue: cameraAngle) }
        set { cameraAngle = newValue.rawValue }
    }

    var sourceValue: RecordingSource {
        get { RecordingSource(legacyValue: source) }
        set { source = newValue.rawValue }
    }

    /// Normalize legacy labels to stable IDs without changing the SwiftData schema.
    @discardableResult func normalizeMetadata() -> Bool {
        let angle = cameraAngleValue.rawValue
        let origin = sourceValue.rawValue
        guard cameraAngle != angle || source != origin else { return false }
        cameraAngle = angle
        source = origin
        return true
    }

    var durationMetric: ProvenancedValue {
        ProvenancedValue(value: durationSeconds, unit: "s", provenance: .measured,
                         method: "video.assetDuration.v1", sampleCount: 1)
    }

    var frameRateMetric: ProvenancedValue {
        ProvenancedValue(value: nominalFrameRate > 0 ? nominalFrameRate : nil, unit: "Hz", provenance: .measured,
                         method: "video.nominalFrameRate.v1", sampleCount: 1)
    }
}
