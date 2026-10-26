import SwiftUI
import SwingLabCore

struct CaddieView: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.dismiss) private var dismiss
    let clubs: [GolfClub]
    let origin: GeoCoordinate?
    let target: GeoCoordinate?
    let areas: [CourseArea]
    let selectAim: (GolfClub, AimCandidate) -> Void
    @State private var strategy: AimStrategy = .balanced
    @State private var shot: CaddieShotKind = .approach
    @State private var forwardAdjustment = ""
    @State private var rightAdjustment = ""
    @State private var recommendation: AimRecommendation?
    @State private var calculating = false

    private var calculationID: String { "\(strategy.rawValue):\(shot.rawValue):\(forwardAdjustment):\(rightAdjustment)" }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(prefs.text("Strategy"), selection: $strategy) {
                        ForEach(AimStrategy.allCases, id: \.self) { Text(prefs.text($0.localizationKey)).tag($0) }
                    }
                    Picker(prefs.text("Shot type"), selection: $shot) {
                        Text(prefs.text("Approach · carry")).tag(CaddieShotKind.approach)
                        Text(prefs.text("Tee shot · total")).tag(CaddieShotKind.tee)
                    }
                    if let origin, let target {
                        SLMetricReadout(metric: .init(value: Geo.distance(from: origin, to: target), unit: "m", provenance: .estimated,
                            method: "map.targetDistance.v1"), label: prefs.text("Target distance"), alignment: .leading)
                    }
                }
                Section(prefs.text("Optional landing adjustments")) {
                    adjustmentField("Elevation distance adjustment", value: $forwardAdjustment)
                    adjustmentField("Wind drift · right positive", value: $rightAdjustment)
                    Text(prefs.text("Enter expected landing shifts in your distance unit. These assumptions are not a wind or elevation measurement."))
                        .font(.caption).foregroundStyle(.secondary)
                    ProvenanceBadge(provenance: .userEntered)
                }
                if calculating { ProgressView() }
                else if let recommendation {
                    candidateSection("Recommended", candidate: recommendation.recommended)
                    candidateSection("Safer alternative", candidate: recommendation.safer)
                    candidateSection("Aggressive alternative", candidate: recommendation.aggressive)
                } else {
                    SLEmptyState(title: prefs.text("Build your club profile"),
                        message: prefs.text("Add carry or total and both variability values in My Bag to compare aims."), symbol: "figure.golf")
                }
                Section(prefs.text("How this works")) {
                    Text(prefs.text("Aim search balances target error, variability and supplied hazard areas. Strategy weights are preferences, not predicted scores."))
                    Text(prefs.text("Hazard risk is conditional on your entered dispersion and mapped boundaries. Missing geometry means unavailable risk, not zero risk."))
                    Text(prefs.text("Tee shots use entered total distance; approaches use carry. Variability is assumed unchanged by roll and entered adjustments."))
                    if areas.contains(where: { $0.sourceURL != nil }) {
                        Link(prefs.text("© OpenStreetMap contributors · ODbL"), destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                    }
                }.font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle(prefs.text("Caddie"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(prefs.text("Done")) { dismiss() } } }
            .task(id: calculationID) { await calculate() }
        }
    }
    private func adjustmentField(_ title: LocalizationKey, value: Binding<String>) -> some View {
        HStack { Text(prefs.text(title)); TextField(prefs.distanceUnit.symbol, text: value).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing) }
    }
    private func candidateSection(_ title: LocalizationKey, candidate: AimCandidate) -> some View {
        Section(prefs.text(title)) {
            if let club = clubs.first(where: { $0.id == candidate.clubID }) {
                Button { selectAim(club, candidate); dismiss() } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(club.name).font(.headline)
                        Text(prefs.format(candidate.aimOffsetMeters < 0 ? "Aim %1$@ left of the target." : "Aim %1$@ right of the target.",
                            prefs.distance(abs(candidate.aimOffsetMeters))))
                        SLMetricReadout(metric: .init(value: candidate.expectedDistanceError, unit: "m", provenance: .estimated,
                            method: "caddie.expectedRemaining.v2"), label: prefs.text("Expected distance from target"), alignment: .leading)
                        if candidate.hazards.isEmpty { Text(prefs.text("Hazard risk unavailable — no supplied hazard areas.")) }
                        ForEach(candidate.hazards, id: \.areaID) { risk in
                            SLMetricReadout(metric: risk.metric, label: prefs.text(risk.kind.localizationKey), displayAsPercent: true, alignment: .leading)
                        }
                    }
                }.buttonStyle(.plain)
            }
        }
    }
    @MainActor private func calculate() async {
        recommendation = nil
        guard let origin, let target else { return }
        func meters(_ string: String) -> Double? {
            if string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return 0 }
            let formatter = NumberFormatter(); formatter.locale = prefs.locale
            return formatter.number(from: string).map { prefs.distanceUnit.toSI($0.doubleValue) }
        }
        guard let forward = meters(forwardAdjustment), let right = meters(rightAdjustment) else { return }
        let profiles = clubs.compactMap { club -> AimClubProfile? in
            guard let forwardSD = club.carryStdDevMeters, let lateralSD = club.lateralStdDevMeters else { return nil }
            return .init(id: club.id, carry: club.carryMeters, total: club.totalMeters, forwardSD: forwardSD,
                         lateralSD: lateralSD, lateralMean: club.lateralMeanMeters, correlation: club.dispersionCorrelation)
        }
        let areas = areas, strategy = strategy, shot = shot
        calculating = true
        let worker = Task.detached(priority: .userInitiated) {
            CaddieAimSearch.recommend(profiles: profiles, origin: origin, target: target, areas: areas,
                strategy: strategy, shot: shot, forwardAdjustment: forward, rightAdjustment: right)
        }
        let result = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
        guard !Task.isCancelled else { return }
        recommendation = result; calculating = false
    }
}
