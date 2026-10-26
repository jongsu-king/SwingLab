import Foundation
import SwiftData
import SwingLabCore

/// Frozen Round 1 persisted declarations, copied from HEAD before adding V2 fields.
/// Keep every stored name, optionality, uniqueness, relationship and delete rule intact.
/// Computed presentation helpers are intentionally omitted: they are not part of the schema.
/// The disk migration tests exercise this snapshot independently of later schema versions.
enum SwingLabSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [GolfClub.self, SwingRecording.self, GolfCourse.self, CourseHole.self,
         RoundSession.self, HoleScore.self, ShotRecord.self]
    }

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
        var cameraAngle: String
        var source: String
        @Attribute(.externalStorage) var analysisData: Data?

        init(title: String, videoFileName: String, durationSeconds: Double,
             nominalFrameRate: Double, videoWidth: Double, videoHeight: Double,
             cameraAngle: String = "Face-on", source: String = "Recorded") {
            id = UUID()
            createdAt = .now
            self.title = title
            self.videoFileName = videoFileName
            self.durationSeconds = durationSeconds
            self.nominalFrameRate = nominalFrameRate
            self.videoWidth = videoWidth
            self.videoHeight = videoHeight
            self.cameraAngle = cameraAngle
            self.source = source
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
        /// JSON-encoded, explicitly user-entered point references, not hazard polygons.
        var referenceData: Data?

        init(number: Int, par: Int? = nil) {
            id = UUID()
            self.number = number
            self.par = par
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
    }
}

/// Current models. V1 and V2 are immutable snapshots, never aliases to these types.
enum SwingLabSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(3, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [GolfClub.self, SwingRecording.self, GolfCourse.self, CourseHole.self,
         RoundSession.self, HoleScore.self, ShotRecord.self, PracticeSession.self]
    }
}

typealias SwingLabCurrentSchema = SwingLabSchemaV3

enum SwingLabMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SwingLabSchemaV1.self, SwingLabSchemaV2.self, SwingLabSchemaV3.self]
    }
    static var stages: [MigrationStage] { [migrateV1ToV2, migrateV2ToV3] }

    static var migrateV1ToV2: MigrationStage {
        .custom(fromVersion: SwingLabSchemaV1.self, toVersion: SwingLabSchemaV2.self,
                willMigrate: nil, didMigrate: { context in
            // Fetch the frozen V2 model, not the current V3 type. Preserve external JSON
            // byte-for-byte while filling summary columns once, including corrupt payloads.
            for recording in try context.fetch(FetchDescriptor<SwingLabSchemaV2.SwingRecording>()) {
                recording.normalizeMetadata()
                recording.rebuildAnalysisSummary()
            }
            try context.save()
        })
    }

    static var migrateV2ToV3: MigrationStage {
        .custom(fromVersion: SwingLabSchemaV2.self, toVersion: SwingLabSchemaV3.self,
                willMigrate: nil, didMigrate: { context in
            // V3 adds optional associations. Existing payload/cache columns are untouched.
            // Imported recordings use their saved library-added date, not an invented capture date.
            try PracticeSessionStore.groupUngroupedRecordings(context: context)
            try context.save()
        })
    }
}
