import SwiftUI
import SwingLabCore

/// The optional sensor inputs are the integration boundary for the reviewer's shot log.
/// Until that log is available, a saved carry or body-motion metric is never substituted.
struct ClubProfileView: View {
    @Environment(AppPreferences.self) private var preferences
    let club: GolfClub
    var measuredBallSpeed: ProvenancedValue? = nil
    var measuredLaunch: ProvenancedValue? = nil
    @State private var referenceClub: ReferenceClub?
    @State private var population: ReferencePopulation = .pga2023

    init(club: GolfClub, measuredBallSpeed: ProvenancedValue? = nil, measuredLaunch: ProvenancedValue? = nil) {
        self.club = club
        self.measuredBallSpeed = measuredBallSpeed
        self.measuredLaunch = measuredLaunch
        let initial: ReferenceClub? = switch club.category {
        case ClubCategory.driver.rawValue: .driver
        case ClubCategory.hybrid.rawValue: .hybrid
        default: nil
        }
        _referenceClub = State(initialValue: initial)
    }

    private var rows: [ReferenceLaunchRow] {
        ReferenceLaunchData.rows.filter { $0.club == referenceClub && $0.population == population }
    }

    private var clubOptions: [ReferenceClub] {
        switch ClubCategory(rawValue: club.category) {
        case .driver: [.driver]
        case .fairwayWood: [.wood3, .wood5, .wood7]
        case .hybrid: [.hybrid]
        case .iron: [.iron3, .iron4, .iron5, .iron6, .iron7, .iron8, .iron9]
        case .wedge: [.pitchingWedge]
        case .utilityIron, .putter, nil: []
        }
    }

    private var match: ReferenceSpeedMatch? {
        guard let referenceClub, let measuredBallSpeed else { return nil }
        return ReferenceLaunchData.match(club: referenceClub, population: population, ballSpeed: measuredBallSpeed)
    }

    var body: some View {
        List {
            Section(preferences.text("Your saved values")) {
                ownMetric("Average carry distance", value: ProvenancedValue(value: club.carryMeters, unit: "m",
                    provenance: .userEntered, method: "bag.averageCarry.v1"))
                ownMetric("Ball speed", value: measuredBallSpeed ?? unavailable(unit: "m/s"))
                ownMetric("Launch angle", value: measuredLaunch ?? unavailable(unit: "rad"))
                Text(preferences.text("Reference values never become your measurements."))
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section(preferences.text(ReferenceLaunchData.label)) {
                Picker(preferences.text("Reference club"), selection: $referenceClub) {
                    Text(preferences.text("Choose a club")).tag(Optional<ReferenceClub>.none)
                    ForEach(clubOptions) { item in
                        Text(preferences.text(item.localizationKey)).tag(Optional(item))
                    }
                }
                Picker(preferences.text("Reference population"), selection: $population) {
                    ForEach(ReferencePopulation.allCases) { item in
                        Text(preferences.text(item.localizationKey)).tag(item)
                    }
                }
                Text(preferences.text("Published groups describe other golfers. They are context, not targets or personal predictions."))
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section(preferences.text("At your measured ball speed")) {
                if let match {
                    Text(preferences.text(match.isInterpolated
                        ? "Interpolated between published averages" : "Published average at this ball speed"))
                        .font(.footnote)
                    ForEach(ReferenceMetric.allCases) { metric in
                        if let value = match.values[metric] {
                            LabeledContent(preferences.text(metric.localizationKey)) {
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(formatted(value.valueSI, metric: metric)).monospacedDigit()
                                    if value.isInterpolated {
                                        Text(preferences.format("reference.bracket", formatted(value.bracket.lowerSI, metric: metric),
                                                                formatted(value.bracket.upperSI, metric: metric)))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    Text(preferences.text("The bracket contains published averages, not a personal confidence interval."))
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text(preferences.text("No matching measured ball-speed reference is available."))
                    Text(preferences.text("A saved carry distance cannot establish ball speed. Values outside the published speed range are not extrapolated."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            if rows.isEmpty {
                Section { Text(preferences.text("No published values for this selection.")) }
            }
            ForEach(rows) { row in
                Section {
                    ForEach(ReferenceMetric.allCases) { metric in
                        LabeledContent(preferences.text(metric.localizationKey)) {
                            if let value = row.values[metric] {
                                Text(formatted(value.siValue, metric: metric)).monospacedDigit()
                            } else {
                                Text(preferences.text("Unavailable")).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let context = ReferenceLaunchData.gappingContext(row: row) {
                        Text(preferences.format("reference.gappingContext",
                            formatted(context.smash.siValue, metric: .smashFactor),
                            formatted(context.launch.siValue, metric: .launch)))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(sourceIDs(for: row), id: \.self) { id in
                        if let source = ReferenceLaunchData.sources.first(where: { $0.id == id }) {
                            Link(source.title, destination: source.url).font(.caption)
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.text(ReferenceLaunchData.label))
                        if let group = row.skillGroup {
                            Text(preferences.format("reference.skillGroup", group))
                        }
                        if let count = row.sampleCount {
                            Text(preferences.format("metric.sampleCount", count.formatted(.number.locale(preferences.locale))))
                        }
                    }
                }
            }
        }
        .navigationTitle(preferences.text("Club profile"))
        .scrollContentBackground(.hidden)
        .background(SLTheme.background)
    }

    private func ownMetric(_ key: LocalizationKey, value: ProvenancedValue) -> some View {
        LabeledContent(preferences.text(key)) { SLMetricReadout(metric: value, fractionDigits: 1) }
    }

    private func unavailable(unit: String) -> ProvenancedValue {
        ProvenancedValue(value: nil, unit: unit, provenance: .unavailable, method: "reference.noPersonalLaunchLog.v1")
    }

    private func sourceIDs(for row: ReferenceLaunchRow) -> [String] {
        Array(Set(row.values.values.map { $0.citation.sourceID })).sorted()
    }

    private func formatted(_ siValue: Double, metric: ReferenceMetric) -> String {
        let value: Double
        let unit: String
        let digits: Int
        switch metric {
        case .clubSpeed, .ballSpeed:
            value = preferences.speedUnit.fromSI(siValue); unit = preferences.speedUnit.symbol; digits = 1
        case .carry, .apex:
            value = preferences.distanceUnit.fromSI(siValue); unit = preferences.distanceUnit.symbol; digits = 1
        case .launch: value = siValue * 180 / .pi; unit = "°"; digits = 1
        case .spin: value = siValue * 60 / (2 * .pi); unit = "rpm"; digits = 0
        case .smashFactor: value = siValue; unit = ""; digits = 2
        }
        let number = value.formatted(.number.precision(.fractionLength(digits)).locale(preferences.locale))
        return unit.isEmpty ? number : preferences.format("metric.valueUnit", number, unit)
    }
}
