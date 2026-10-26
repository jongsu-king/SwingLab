import Foundation
import SwiftData
import SwingLabCore

struct RecordingAnalysisSnapshot {
    let data: Data?
    let summary: AnalysisSummary
}

protocol AnalysisRestorable: AnyObject {
    var analysisSnapshot: RecordingAnalysisSnapshot { get }
    func applyAnalysis(_ report: PoseAnalysisReport) throws
    func restoreAnalysis(_ snapshot: RecordingAnalysisSnapshot)
}

/// Explicit snapshots restore visible model values on iOS 26.4 as well as iOS 27.1.
/// Raw SwiftData rollback alone leaves retained objects edited on the older runtime.
enum AnalysisPersistence {
    static func save(_ report: PoseAnalysisReport, to recording: some AnalysisRestorable,
                     context: ModelContext, save: (() throws -> Void)? = nil) throws {
        let snapshot = recording.analysisSnapshot
        try recording.applyAnalysis(report)
        do { if let save { try save() } else { try context.save() } }
        catch {
            context.rollback()
            recording.restoreAnalysis(snapshot)
            throw error
        }
    }
}
