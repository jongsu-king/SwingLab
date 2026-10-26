import Foundation

let now = Date(timeIntervalSince1970: 1_800_000_000)
func fix(age: Double = 0, accuracy: Double = 5) -> CourseLocationFix {
    CourseLocationFix(latitude: 37.5, longitude: 127, horizontalAccuracy: accuracy, timestamp: now.addingTimeInterval(-age))
}
precondition(fix(age: 20, accuracy: 30).isUsableForShot(at: now))
precondition(!fix(age: 20.01).isUsableForShot(at: now))
precondition(!fix(age: -5.01).isUsableForShot(at: now))
precondition(fix(age: -5).isUsableForShot(at: now))
print("PASS GPS stale/future time gates")
precondition(!fix(accuracy: 30.01).isUsableForShot(at: now))
precondition(!fix(accuracy: -1).isUsableForShot(at: now))
precondition(!fix(accuracy: .nan).isUsableForShot(at: now))
precondition(!CourseLocationFix(latitude: 91, longitude: 0, horizontalAccuracy: 1, timestamp: now).isUsableForShot(at: now))
print("PASS GPS accuracy/invalid-coordinate gates")
let empty = ScorecardEntry.validated(par: "", strokes: "", putts: "", penalties: 0)!
precondition(empty.par == nil && empty.strokes == nil && empty.putts == nil)
let score = ScorecardEntry.validated(par: " 4 ", strokes: "5", putts: "2", penalties: 1)!
precondition(score.par == 4 && score.strokes == 5 && score.putts == 2 && score.penalties == 1)
print("PASS unknown scores preserved and strokes not double counted")
precondition(ScorecardEntry.validated(par: "4", strokes: "2", putts: "2", penalties: 1) == nil)
precondition(ScorecardEntry.validated(par: "0", strokes: "4", putts: "1", penalties: 0) == nil)
precondition(ScorecardEntry.validated(par: "4", strokes: "0", putts: "0", penalties: 0) == nil)
precondition(ScorecardEntry.validated(par: "4", strokes: "four", putts: "1", penalties: 0) == nil)
precondition(ScorecardEntry.validated(par: "4", strokes: "4", putts: "-1", penalties: 0) == nil)
precondition(ScorecardEntry.validated(par: "4", strokes: "4", putts: "1", penalties: -1) == nil)
print("PASS impossible and malformed scores rejected")
let reference = CourseReferencePoint(kind: "Target", latitude: 37.501234, longitude: 127.001234)
let encoded = try JSONEncoder().encode([reference])
let decoded = try JSONDecoder().decode([CourseReferencePoint].self, from: encoded)
precondition(decoded.count == 1 && decoded[0].id == reference.id && decoded[0].latitude == reference.latitude && decoded[0].longitude == reference.longitude)
print("PASS manual reference JSON round trip")
