import Foundation
import SwiftData
import SwingLabCore

/// Frozen V4 persisted declarations (catalog equipment fields on GolfClub). Keep every stored field
/// and relationship unchanged. V5 adds only the `LaunchShot` log.
enum SwingLabSchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(4, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [GolfClub.self, SwingRecording.self, GolfCourse.self, CourseHole.self,
         RoundSession.self, HoleScore.self, ShotRecord.self, PracticeSession.self]
    }

    /// Distances are stored in meters. Values are entered by the golfer, not measured by a sensor.
    @Model
    final class GolfClub {
        @Attribute(.unique) var id: UUID
        var name: String
        var category: String
        var brand: String
        var modelName: String
        var loftDegrees: Double?
        var shaft: String
        var flex: String
        var carryMeters: Double?
        var totalMeters: Double?
        var carryStdDevMeters: Double?
        var lateralStdDevMeters: Double?
        var lateralMeanMeters: Double
        var dispersionCorrelation: Double
        var notes: String
        var createdAt: Date
        // V4. Stable catalog IDs survive catalog refreshes. nil preserves fully custom clubs.
        var catalogClubID: String?
        var catalogVariant: String?
        var catalogShaftID: String?
        var equipmentData: Data?

        var equipment: ClubEquipmentConfiguration {
            get { (try? JSONDecoder().decode(ClubEquipmentConfiguration.self, from: equipmentData ?? Data())) ?? .init() }
            set { equipmentData = try? JSONEncoder().encode(newValue) }
        }

        init(name: String, category: String) {
            id = UUID()
            self.name = name
            self.category = category
            brand = ""
            modelName = ""
            loftDegrees = nil
            shaft = ""
            flex = ""
            carryMeters = nil
            totalMeters = nil
            carryStdDevMeters = nil
            lateralStdDevMeters = nil
            lateralMeanMeters = 0
            dispersionCorrelation = 0
            notes = ""
            createdAt = .now
        }
    }

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

    @Model
    final class GolfCourse {
        @Attribute(.unique) var id: UUID
        var name: String
        var latitude: Double
        var longitude: Double
        /// A point-of-interest is never interpreted as surveyed hole geometry.
        var source: String
        @Relationship(deleteRule: .cascade, inverse: \CourseHole.course) var holes: [CourseHole] = []

        init(name: String, latitude: Double, longitude: Double, source: String = "userEntered") {
            id = UUID()
            self.name = name
            self.latitude = latitude
            self.longitude = longitude
            self.source = source
        }
    }

    @Model
    final class CourseHole {
        @Attribute(.unique) var id: UUID
        var number: Int
        var par: Int?
        var course: GolfCourse?
        /// Versioned JSON with point references and supplied polygons; legacy point arrays still decode.
        var referenceData: Data?

        init(number: Int, par: Int? = nil) {
            id = UUID()
            self.number = number
            self.par = par
        }

        var references: [CourseReferencePoint] {
            get { geometryDocument.references }
            set { var document = geometryDocument; document.references = newValue; referenceData = try? JSONEncoder().encode(document) }
        }
        var areas: [CourseArea] {
            get { geometryDocument.areas }
            set { var document = geometryDocument; document.areas = newValue; referenceData = try? JSONEncoder().encode(document) }
        }
        private var geometryDocument: CourseGeometryDocument {
            guard let data = referenceData else { return .init() }
            if let document = try? JSONDecoder().decode(CourseGeometryDocument.self, from: data) { return document }
            return .init(references: (try? JSONDecoder().decode([CourseReferencePoint].self, from: data)) ?? [])
        }
    }

    @Model
    final class RoundSession {
        @Attribute(.unique) var id: UUID
        var startedAt: Date
        var endedAt: Date?
        var courseName: String
        var holeCount: Int
        var currentHole: Int
        var course: GolfCourse?
        @Relationship(deleteRule: .cascade, inverse: \HoleScore.round) var holeScores: [HoleScore] = []
        @Relationship(deleteRule: .cascade, inverse: \ShotRecord.round) var shots: [ShotRecord] = []

        init(courseName: String, holeCount: Int, course: GolfCourse? = nil) {
            id = UUID()
            startedAt = .now
            self.courseName = courseName
            self.holeCount = holeCount == 9 ? 9 : 18
            currentHole = 1
            self.course = course
        }

        var totalScore: Int { holeScores.compactMap(\.strokes).reduce(0, +) }
        var completedHoleCount: Int { holeScores.filter { $0.strokes != nil }.count }
        var totalPutts: Int { holeScores.compactMap(\.putts).reduce(0, +) }
        var totalPenalties: Int { holeScores.reduce(0) { $0 + $1.penalties } }
        var pendingShot: ShotRecord? { shots.first { $0.endLatitude == nil } }
    }

    @Model
    final class HoleScore {
        @Attribute(.unique) var id: UUID
        var number: Int
        var par: Int?
        var strokes: Int?
        var putts: Int?
        var penalties: Int
        var fairwayHit: Bool?
        var greenInRegulation: Bool?
        var round: RoundSession?

        init(number: Int, par: Int? = nil) {
            id = UUID()
            self.number = number
            self.par = par
            penalties = 0
        }
    }

    @Model
    final class ShotRecord {
        @Attribute(.unique) var id: UUID
        var holeNumber: Int
        var shotNumber: Int
        var clubID: UUID?
        var clubName: String
        var startLatitude: Double
        var startLongitude: Double
        var startAccuracyMeters: Double
        var startedAt: Date
        var endLatitude: Double?
        var endLongitude: Double?
        var endAccuracyMeters: Double?
        var endedAt: Date?
        var lie: String
        var shape: String
        var penalties: Int
        var notes: String
        var round: RoundSession?

        init(holeNumber: Int, shotNumber: Int, clubID: UUID?, clubName: String,
             startLatitude: Double, startLongitude: Double, startAccuracyMeters: Double, startedAt: Date) {
            id = UUID()
            self.holeNumber = holeNumber
            self.shotNumber = shotNumber
            self.clubID = clubID
            self.clubName = clubName
            self.startLatitude = startLatitude
            self.startLongitude = startLongitude
            self.startAccuracyMeters = startAccuracyMeters
            self.startedAt = startedAt
            lie = "Unknown"
            shape = "Unknown"
            penalties = 0
            notes = ""
        }

        var groundDisplacementMeters: Double? {
            guard let endLatitude, let endLongitude else { return nil }
            return Geo.distance(from: GeoCoordinate(latitude: startLatitude, longitude: startLongitude),
                                to: GeoCoordinate(latitude: endLatitude, longitude: endLongitude))
        }
    }

    /// Session metadata is user-entered context, never a claim about measured swing conditions.
    @Model
    final class PracticeSession {
        @Attribute(.unique) var id: UUID
        var date: Date
        var clubID: UUID?
        var cameraAngleID: String
        /// Historical recordings without an explicit override keep unknown handedness.
        var handednessID: String?
        var notes: String
        @Relationship(deleteRule: .nullify, inverse: \SwingRecording.practiceSession)
        var recordings: [SwingRecording] = []

        init(date: Date, clubID: UUID? = nil, cameraAngle: CameraAngle = .unspecified,
             handedness: Handedness? = nil, notes: String = "") {
            id = UUID()
            self.date = date
            self.clubID = clubID
            cameraAngleID = cameraAngle.rawValue
            handednessID = handedness?.rawValue
            self.notes = notes
        }

        var cameraAngleValue: CameraAngle {
            get { CameraAngle(rawValue: cameraAngleID) ?? .unspecified }
            set { cameraAngleID = newValue.rawValue }
        }

        var handedness: Handedness? {
            get { handednessID.flatMap(Handedness.init(rawValue:)) }
            set { handednessID = newValue?.rawValue }
        }
    }
}
