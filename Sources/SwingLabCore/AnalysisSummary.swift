import Foundation

/// Small, framework-independent projection of one analysis report for persistent list/chart columns.
/// A legacy sampling cap is not an observed frame rate, so migration never substitutes it.
public struct AnalysisSummary: Codable, Sendable, Equatable {
    public let tempo: ProvenancedValue
    public let backswing: ProvenancedValue
    public let downswing: ProvenancedValue
    public let headDisplacement: ProvenancedValue
    public let analysisVersion: Int
    public let poseFrameRate: Double?

    public init(report: PoseAnalysisReport?) {
        tempo = report?.tempoMetric ?? .init(value: nil, unit: "1", provenance: .unavailable, method: "phase.tempoRatio.v1")
        backswing = report?.backswingMetric ?? .init(value: nil, unit: "s", provenance: .unavailable, method: "phase.backswingDuration.v1")
        downswing = report?.downswingMetric ?? .init(value: nil, unit: "s", provenance: .unavailable, method: "phase.downswingDuration.v1")
        headDisplacement = report?.headDisplacementMetric ?? .init(value: nil, unit: "1", provenance: .unavailable, method: "pose.noseDisplacement.v1")
        analysisVersion = report?.analysisVersion ?? 0
        poseFrameRate = report?.poseFrameRate.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }

    /// Decodes both schemaVersion-1 legacy JSON and current analysis JSON. Invalid payloads are
    /// deliberately non-destructive: callers retain the original data and show unavailable values.
    public static func migrating(analysisData: Data?) -> AnalysisSummary {
        let report = analysisData.flatMap { try? JSONDecoder().decode(PoseAnalysisReport.self, from: $0) }
        return AnalysisSummary(report: report)
    }
}
