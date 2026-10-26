import SwiftData

enum SwingLabSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [GolfClub.self, SwingRecording.self, GolfCourse.self, CourseHole.self,
         RoundSession.self, HoleScore.self, ShotRecord.self]
    }
}
enum SwingLabMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SwingLabSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
