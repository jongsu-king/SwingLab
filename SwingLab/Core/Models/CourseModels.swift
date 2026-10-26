import Foundation
import SwiftData
import SwingLabCore

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

    var references: [CourseReferencePoint] {
        get { (try? JSONDecoder().decode([CourseReferencePoint].self, from: referenceData ?? Data())) ?? [] }
        set { referenceData = try? JSONEncoder().encode(newValue) }
    }
}

struct CourseReferencePoint: Codable, Identifiable {
    var id = UUID()
    var kind: String
    var latitude: Double
    var longitude: Double
    var coordinate: GeoCoordinate { GeoCoordinate(latitude: latitude, longitude: longitude) }
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

/// Validated score input. Empty values remain unknown; a zero score is never invented.
struct ScorecardEntry {
    let par: Int?
    let strokes: Int?
    let putts: Int?
    let penalties: Int

    static func validated(par: String, strokes: String, putts: String, penalties: Int) -> ScorecardEntry? {
        let par = par.trimmingCharacters(in: .whitespacesAndNewlines)
        let strokes = strokes.trimmingCharacters(in: .whitespacesAndNewlines)
        let putts = putts.trimmingCharacters(in: .whitespacesAndNewlines)
        let parValue = Int(par), strokesValue = Int(strokes), puttsValue = Int(putts)
        guard (0...30).contains(penalties),
              (par.isEmpty || (parValue.map { (1...9).contains($0) } ?? false)),
              (strokes.isEmpty || (strokesValue.map { (1...99).contains($0) } ?? false)),
              (putts.isEmpty || (puttsValue.map { (0...99).contains($0) } ?? false)),
              strokesValue.map({ (puttsValue ?? 0) + penalties <= $0 }) ?? true else { return nil }
        return ScorecardEntry(par: parValue, strokes: strokesValue, putts: puttsValue, penalties: penalties)
    }
}
