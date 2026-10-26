import Foundation
import SwiftData
import SwingLabCore

@Model
final class SwingRecording: AnalysisRestorable {
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
    @Attribute(.externalStorage) private(set) var analysisData: Data?


    // V3 associations. A missing club remains unknown, separate from any named club baseline.
    var clubID: UUID?
    var practiceSession: PracticeSession?

    // V2 queryable summary columns. nil is unavailable; no pose JSON is decoded by these getters.
    private(set) var analysisVersion: Int = 0
    private(set) var poseFrameRate: Double?
    private var handednessOverrideID: String?
    private(set) var tempoValue: Double?
    private var tempoProvenanceID: String = "unavailable"
    private var tempoConfidence: Double?
    private var tempoMethod: String = "phase.tempoRatio.v1"
    private var tempoSampleCount: Int?
    private(set) var backswingValue: Double?
    private var backswingProvenanceID: String = "unavailable"
    private var backswingConfidence: Double?
    private var backswingMethod: String = "phase.backswingDuration.v1"
    private var backswingSampleCount: Int?
    private(set) var downswingValue: Double?
    private var downswingProvenanceID: String = "unavailable"
    private var downswingConfidence: Double?
    private var downswingMethod: String = "phase.downswingDuration.v1"
    private var downswingSampleCount: Int?
    private(set) var headDisplacementValue: Double?
    private var headDisplacementProvenanceID: String = "unavailable"
    private var headDisplacementConfidence: Double?
    private var headDisplacementMethod: String = "pose.noseDisplacement.v1"
    private var headDisplacementSampleCount: Int?

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

    var tempoRatio: Double? { tempoValue }
    var tempoProvenance: Provenance? { tempoValue == nil ? nil : tempoMetric.provenance }

    var handednessOverride: Handedness? {
        get { handednessOverrideID.flatMap(Handedness.init(rawValue:)) }
        set { handednessOverrideID = newValue?.rawValue }
    }
    func effectiveHandedness(default fallback: Handedness) -> Handedness { handednessOverride ?? fallback }

    /// Encoding may throw before any model field changes. Persist the context after this call;
    /// on save failure roll back the context so JSON and every summary column stay in agreement.
    func applyAnalysis(_ report: PoseAnalysisReport) throws {
        let encoded = try JSONEncoder().encode(report)
        let summary = AnalysisSummary(report: report)
        analysisData = encoded
        applySummary(summary)
    }

    /// Used by the V1→V2 migration only, or an explicit future repair action.
    func rebuildAnalysisSummary() {
        applySummary(AnalysisSummary.migrating(analysisData: analysisData))
    }

    var analysisSnapshot: RecordingAnalysisSnapshot {
        .init(data: analysisData, summary: .init(tempo: tempoMetric, backswing: backswingMetric,
            downswing: downswingMetric, headDisplacement: headDisplacementMetric,
            analysisVersion: analysisVersion, poseFrameRate: poseFrameRate))
    }

    func restoreAnalysis(_ snapshot: RecordingAnalysisSnapshot) {
        analysisData = snapshot.data
        applySummary(snapshot.summary)
    }

    private func applySummary(_ summary: AnalysisSummary) {
        analysisVersion = summary.analysisVersion
        poseFrameRate = summary.poseFrameRate
        tempoValue = summary.tempo.value
        tempoProvenanceID = summary.tempo.provenance.rawValue
        tempoConfidence = summary.tempo.confidence
        tempoMethod = summary.tempo.method
        tempoSampleCount = summary.tempo.sampleCount
        backswingValue = summary.backswing.value
        backswingProvenanceID = summary.backswing.provenance.rawValue
        backswingConfidence = summary.backswing.confidence
        backswingMethod = summary.backswing.method
        backswingSampleCount = summary.backswing.sampleCount
        downswingValue = summary.downswing.value
        downswingProvenanceID = summary.downswing.provenance.rawValue
        downswingConfidence = summary.downswing.confidence
        downswingMethod = summary.downswing.method
        downswingSampleCount = summary.downswing.sampleCount
        headDisplacementValue = summary.headDisplacement.value
        headDisplacementProvenanceID = summary.headDisplacement.provenance.rawValue
        headDisplacementConfidence = summary.headDisplacement.confidence
        headDisplacementMethod = summary.headDisplacement.method
        headDisplacementSampleCount = summary.headDisplacement.sampleCount
    }

    var tempoMetric: ProvenancedValue {
        ProvenancedValue(value: tempoValue, unit: "1", provenance: Provenance(rawValue: tempoProvenanceID) ?? .unavailable,
                         confidence: tempoConfidence, method: tempoMethod, sampleCount: tempoSampleCount)
    }

    var backswingMetric: ProvenancedValue {
        ProvenancedValue(value: backswingValue, unit: "s", provenance: Provenance(rawValue: backswingProvenanceID) ?? .unavailable,
                         confidence: backswingConfidence, method: backswingMethod, sampleCount: backswingSampleCount)
    }

    var downswingMetric: ProvenancedValue {
        ProvenancedValue(value: downswingValue, unit: "s", provenance: Provenance(rawValue: downswingProvenanceID) ?? .unavailable,
                         confidence: downswingConfidence, method: downswingMethod, sampleCount: downswingSampleCount)
    }

    var headDisplacementMetric: ProvenancedValue {
        ProvenancedValue(value: headDisplacementValue, unit: "1", provenance: Provenance(rawValue: headDisplacementProvenanceID) ?? .unavailable,
                         confidence: headDisplacementConfidence, method: headDisplacementMethod, sampleCount: headDisplacementSampleCount)
    }

    var cameraAngleValue: CameraAngle {
        get { CameraAngle(legacyValue: cameraAngle) }
        set { cameraAngle = newValue.rawValue }
    }

    /// Cached columns only; stable club identity and camera angle define comparable swings.
    var coachingSample: CoachingSample {
        CoachingSample(id: id, date: createdAt, club: clubID?.uuidString, cameraAngle: cameraAngleValue,
                       metrics: [.tempo: tempoMetric, .backswing: backswingMetric,
                                 .downswing: downswingMetric, .headDisplacement: headDisplacementMetric])
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
