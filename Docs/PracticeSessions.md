# Practice sessions (WP4)

## Persistence and migration

`SwingLabSchemaV3` adds `PracticeSession`, plus optional `clubID` and `practiceSession` fields on recordings. Club identity uses the stable club UUID; renaming a club does not change its coaching baseline. A missing club is a separate unknown group, never a match to a named club.

`SchemaV2.swift` freezes all seven Round 2 model declarations, including stored field names, optionality, defaults, external storage, uniqueness, and relationship rules. V1 remains frozen in `Schema.swift`. The V1→V2 stage fetches **V2** recordings and builds their cached summaries once. The V2→V3 stage fetches current recordings, adds session associations, and does not re-encode analysis JSON or rebuild existing summary columns.

Session records store date, optional club ID, camera angle, optional handedness, and notes. Their recording relationship uses `.nullify`: deleting a session retains the recordings and their analysis. Delete All Local Data explicitly removes sessions along with recordings. Historical recordings without a handedness override keep unknown session handedness; migration does not apply today's preference to old recordings.

Grouping uses the persisted recording date. For imported clips this is the library-added date, not necessarily the original capture date. A session's date is its earliest member's recording date. The grouping adapter uses the Core 90-minute rule and saves within the migration transaction.

## Migration tests

`SwingLabTests/SchemaMigrationTests.swift` independently exercises V1→frozen V2, V1→V3, and V2→V3 disk stores. Coverage includes external analysis bytes (including corrupt JSON), cached metrics and provenance, override handedness, club/course/round relationships, a gap exactly 90 minutes versus 90 minutes plus one second, and deletion nullification. These are iOS-hosted tests; a macOS SwiftData harness is useful supplementary evidence, not a substitute for running them on an iOS simulator.
