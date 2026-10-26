import Foundation

func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAIL \(name)"); exit(1) }
    print("PASS \(name)")
}
var report = PoseAnalysisReport(frames: [], markers: [
    SwingPhaseMarker(phase: .address, time: 1.3, provenance: "User-entered"),
    SwingPhaseMarker(phase: .top, time: 2.2, provenance: "User-entered"),
    SwingPhaseMarker(phase: .impact, time: 2.5, provenance: "User-entered")
], analyzedAt: .now, sampledFrameCount: 0, poseFrameCount: 0, sampleRateLimit: 30, notes: [])
check(abs((report.tempoRatio ?? 0) - 3) < 0.0001, "tempo uses actual timestamps")
check(report.timingProvenance == "User-entered", "manual marker provenance")
report.markers[2].provenance = "Estimated"
check(report.timingProvenance == "Estimated", "estimated impact propagates to tempo")
let decoded = try JSONDecoder().decode(PoseAnalysisReport.self, from: JSONEncoder().encode(report))
check(abs((decoded.tempoRatio ?? 0) - 3) < 0.0001 && decoded.schemaVersion == 1, "analysis JSON round trip")
report.markers[2].time = 1.0
check(report.tempoRatio == nil, "out-of-order timing rejected")
report.markers[2].time = 2.5
report.markers[0].time = .nan
check(report.tempoRatio == nil, "non-finite timing rejected")
report.markers = []
check(report.tempoRatio == nil && report.headMovementPercent == nil, "missing measurements remain unavailable")
report.markers = [.init(phase: .address, time: 1, provenance: "User-entered"),
                  .init(phase: .impact, time: 2, provenance: "User-entered")]
report.frames = (0..<5).map { index in
    PoseFrame(time: 1 + Double(index) * 0.2,
              joints: [.init(name: "nose", x: 0.4 + Double(index) * 0.01, y: 0.7, confidence: 0.9)])
}
check(abs((report.headMovementPercent ?? 0) - 4) < 0.0001, "head proxy uses normalized displacement")
report.frames[2].joints = []
check(report.headMovementPercent == nil, "insufficient head observations rejected")
