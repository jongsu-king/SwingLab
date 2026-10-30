import SwiftUI
import SwiftData
import SwingLabCore

struct ClubEditorView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let club: GolfClub?

    @State private var draft = ClubDraft()
    @State private var inputUnit = DistanceUnit.yards
    @State private var didLoad = false
    @State private var inputError: ClubInputError?
    @State private var showingError = false
    @State private var choosingClub = false
    @State private var choosingShaft = false

    init(club: GolfClub? = nil) { self.club = club }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(preferences.text("Choose from catalog")) { choosingClub = true }.accessibilityIdentifier("bag.catalog")
                    Button(preferences.text("Not in the list")) {
                        draft.catalogClubID = nil; draft.catalogVariant = nil
                        draft.equipment.hoselSystemID = nil; draft.equipment.hoselPositionID = nil
                        draft.equipment.baseLoftFromCatalog = false
                    }
                    // The selected model already fills the locked Brand and Model fields below.
                    if let selectedClub, !selectedClub.verified {
                        Text(preferences.text("Catalog entry not yet verified.")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    TextField(preferences.text("Club name"), text: $draft.name)
                        .textInputAutocapitalization(.words)
                    Picker(preferences.text("Category"), selection: $draft.category) {
                        ForEach(ClubCategory.allCases) { category in
                            Text(preferences.text(category.localizationKey)).tag(category.rawValue)
                        }
                    }.disabled(draft.catalogClubID != nil)
                    TextField(preferences.text("Brand"), text: $draft.brand).disabled(draft.catalogClubID != nil)
                    TextField(preferences.text("Model"), text: $draft.modelName).disabled(draft.catalogClubID != nil)
                    decimalField("Loft", value: Binding(get: { draft.loft }, set: {
                        draft.loft = $0; draft.equipment.baseLoftFromCatalog = false
                    }), suffix: "°")
                    if let selectedClub, !selectedClub.stockLoftsDegrees.isEmpty {
                        Picker(preferences.text("Catalog loft"), selection: Binding(get: { draft.loft }, set: {
                            draft.loft = $0; draft.equipment.baseLoftFromCatalog = true
                        })) {
                            Text(preferences.text("Optional")).tag("")
                            ForEach(selectedClub.stockLoftsDegrees, id: \.self) { value in
                                Text(value.formatted() + "°").tag(value.formatted(.number.locale(preferences.locale).grouping(.never)))
                            }
                        }
                    }
                } header: { Text(preferences.text("Equipment")) }

                shaftSection
                configurationSection
                hoselSection

                Section {
                    decimalField("Average carry", value: $draft.carry)
                    decimalField("Average total distance", value: $draft.total)
                } header: { Text(preferences.text("Personal distances")) }
                footer: {
                    Text(preferences.text("User-entered. Carry is the distance through the air; total includes roll. Leave unknown values blank."))
                }

                Section {
                    decimalField("Carry standard deviation", value: $draft.carryDeviation)
                    decimalField("Lateral standard deviation", value: $draft.lateralDeviation)
                    decimalField("Typical lateral offset", value: $draft.lateralMean, signed: true)
                    decimalField("Carry / lateral correlation", value: $draft.correlation, suffix: "", signed: true)
                } header: { Text(preferences.text("Dispersion · optional")) }
                footer: {
                    Text(preferences.text("Use known values. Lateral offset: negative is left, positive is right. Standard deviation is not full width. Correlation must be greater than −1 and less than 1; blank uses zero."))
                }

                Section {
                    TextField(preferences.text("Personal notes"), text: $draft.notes, axis: .vertical)
                        .lineLimit(3...8)
                } header: { Text(preferences.text("Notes")) }
            }
            .scrollContentBackground(.hidden)
            .background(SLTheme.background)
            .navigationTitle(preferences.text(club == nil ? "Add club" : "Edit club"))
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton(preferences.text("Done"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(preferences.text("Cancel")) { dismiss() }
                }
                // Long Cancel/Save labels (German) leave little room; shrink the title rather than truncate it.
                ToolbarItem(placement: .principal) {
                    Text(preferences.text(club == nil ? "Add club" : "Edit club")).font(.headline)
                        .lineLimit(1).minimumScaleFactor(0.75)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(preferences.text("Save"), action: save).fontWeight(.semibold).accessibilityIdentifier("bag.save")
                }
            }
            .alert(preferences.text("Could not save club"), isPresented: $showingError) {
                Button(preferences.text("OK"), role: .cancel) {}
            } message: {
                if let inputError {
                    Text(preferences.format("club.inputError", preferences.text(inputError.field), preferences.text(inputError.message)))
                }
            }
            .sheet(isPresented: $choosingClub) {
                NavigationStack {
                    CatalogPickerView(onSelect: selectClub, onCustom: {
                        draft.catalogClubID = nil; draft.catalogVariant = nil
                        draft.equipment.hoselSystemID = nil; draft.equipment.hoselPositionID = nil
                        draft.equipment.baseLoftFromCatalog = false
                        choosingClub = false
                    })
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(preferences.text("Cancel")) { choosingClub = false } } }
                }
            }
            .sheet(isPresented: $choosingShaft) {
                NavigationStack {
                    ShaftCatalogPickerView(onSelect: { shaft in
                        draft.catalogShaftID = shaft.id; draft.equipment.shaftBrand = shaft.brand
                        draft.shaft = shaft.model; draft.flex = ""; draft.shaftWeight = ""
                        choosingShaft = false
                    }, onCustom: {
                        draft.catalogShaftID = nil; draft.equipment.shaftMode = "custom"
                        choosingShaft = false
                    })
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(preferences.text("Cancel")) { choosingShaft = false } } }
                }
            }
            .onAppear {
                guard !didLoad else { return }
                inputUnit = preferences.distanceUnit
                if let club {
                    draft = ClubDraft(club: club, unit: inputUnit, locale: preferences.locale)
                }
                didLoad = true
            }
        }
    }

    private var selectedClub: CatalogClub? {
        CatalogStore.catalog.clubs.first { $0.id == draft.catalogClubID }
    }
    private var selectedShaft: CatalogShaft? {
        CatalogStore.catalog.shafts.first { $0.id == draft.catalogShaftID }
    }
    private var hosel: CatalogHoselSystem? {
        CatalogStore.catalog.hoselSystems.first { $0.id == draft.equipment.hoselSystemID }
    }
    private var selectedPosition: CatalogHoselPosition? {
        hosel?.positions.first { $0.id == draft.equipment.hoselPositionID }
    }
    private var baseLoft: Double? {
        Double(draft.loft.replacingOccurrences(of: preferences.locale.decimalSeparator ?? ".", with: "."))
    }

    private func selectClub(_ selection: CatalogClub, _ variant: String) {
        draft.catalogClubID = selection.id; draft.catalogVariant = variant
        draft.brand = CatalogStore.catalog.brands.first { $0.id == selection.brandID }?.name ?? selection.brandID
        draft.category = selection.category; draft.modelName = selection.model
        draft.name = [selection.model, variant].filter { !$0.isEmpty }.joined(separator: " ")
        draft.loft = ""; draft.equipment.baseLoftFromCatalog = false
        draft.equipment.hoselSystemID = selection.hoselSystemID; draft.equipment.hoselPositionID = nil
        choosingClub = false
    }

    private var shaftSection: some View {
        Section {
            Picker(preferences.text("Shaft selection"), selection: $draft.equipment.shaftMode) {
                Text(preferences.text("Stock shaft")).tag("stock")
                Text(preferences.text("Catalog shaft")).tag("catalog")
                Text(preferences.text("Custom shaft")).tag("custom")
            }
            if draft.equipment.shaftMode == "catalog" {
                Button(preferences.text("Choose shaft")) { choosingShaft = true }
                if let selectedShaft {
                    if !selectedShaft.verified { Text(preferences.text("Catalog entry not yet verified.")).font(.caption) }
                    if !selectedShaft.flexes.isEmpty {
                        Picker(preferences.text("Flex"), selection: $draft.flex) {
                            Text(preferences.text("Optional")).tag("")
                            ForEach(selectedShaft.flexes, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    if !selectedShaft.weightClassesGrams.isEmpty {
                        Picker(preferences.text("Shaft weight"), selection: $draft.shaftWeight) {
                            Text(preferences.text("Optional")).tag("")
                            ForEach(selectedShaft.weightClassesGrams, id: \.self) { weight in
                                Text(weight.formatted() + " g").tag(weight.formatted(.number.locale(preferences.locale).grouping(.never)))
                            }
                        }
                    }
                }
            }
            TextField(preferences.text("Shaft brand"), text: $draft.equipment.shaftBrand).disabled(draft.catalogShaftID != nil)
            TextField(preferences.text("Shaft"), text: $draft.shaft).disabled(draft.catalogShaftID != nil)
            TextField(preferences.text("Flex"), text: $draft.flex)
            decimalField("Shaft weight", value: $draft.shaftWeight, suffix: "g")
            decimalField("Shaft torque", value: $draft.shaftTorque, suffix: "°")
            TextField(preferences.text("Kick point"), text: $draft.equipment.shaftKickPoint)
            decimalField("Tip trimming", value: $draft.tipTrimming, suffix: "in")
        } header: { Text(preferences.text("Shaft")) }
        footer: { Text(preferences.text("Stock shaft details remain blank until you identify your build.")) }
        .onChange(of: draft.equipment.shaftMode) { _, mode in
            if mode != "catalog" { draft.catalogShaftID = nil }
        }
    }

    private var configurationSection: some View {
        Section {
            Toggle(preferences.text("Enter club length"), isOn: Binding(get: { draft.equipment.lengthMeters != nil }, set: {
                draft.equipment.lengthMeters = $0 ? ClubEquipmentConfiguration.meters(inches: 37) : nil
            }))
            if let meters = draft.equipment.lengthMeters {
                Stepper(value: Binding(get: { ClubEquipmentConfiguration.inches(meters: draft.equipment.lengthMeters ?? meters) }, set: {
                    draft.equipment.lengthMeters = ClubEquipmentConfiguration.meters(inches: $0)
                }), in: 20...50, step: 0.25) {
                    VStack(alignment: .leading) {
                        Text(preferences.format("Club length: %@ in", ClubEquipmentConfiguration.inches(meters: meters).formatted(.number.locale(preferences.locale).precision(.fractionLength(2)))))
                        ProvenanceBadge(provenance: .userEntered)
                    }
                }
            }
            TextField(preferences.text("Swing weight"), text: $draft.equipment.swingWeight)
            TextField(preferences.text("Grip"), text: $draft.equipment.grip)
            decimalField("Lie angle", value: $draft.lie, suffix: "°")
            Picker(preferences.text("Sleeve system"), selection: Binding(get: { draft.equipment.hoselSystemID ?? "" }, set: {
                draft.equipment.hoselSystemID = $0.isEmpty ? nil : $0
                draft.equipment.hoselPositionID = nil
            })) {
                Text(preferences.text("Unavailable")).tag("")
                ForEach(CatalogStore.catalog.hoselSystems) { system in Text(system.name).tag(system.id) }
            }
        } header: { Text(preferences.text("Club configuration")) }
    }

    @ViewBuilder private var hoselSection: some View {
        if let hosel {
            Section {
                Text(hosel.name)
                if hosel.handedness == "right" { Text(preferences.text("Right-handed settings only.")).font(.caption.weight(.semibold)) }
                if hosel.positions.isEmpty {
                    Text(preferences.text("Sleeve positions are not yet verified."))
                } else {
                    Picker(preferences.text("Sleeve position"), selection: Binding(get: { draft.equipment.hoselPositionID ?? "" }, set: {
                        draft.equipment.hoselPositionID = $0.isEmpty ? nil : $0
                    })) {
                        Text(preferences.text("Unavailable")).tag("")
                        ForEach(hosel.positions) { position in
                            Text(positionLabel(position)).tag(position.id)
                        }
                    }
                    if let position = selectedPosition {
                        Text(positionLabel(position)).font(.caption)
                    }
                    LabeledContent(preferences.text("Effective loft")) {
                        if let loft = draft.equipment.effectiveLoft(baseDegrees: baseLoft, position: selectedPosition), selectedPosition != nil {
                            VStack(alignment: .trailing) {
                                Text(loft.formatted(.number.locale(preferences.locale).precision(.fractionLength(0...2))) + "°")
                                Text(preferences.text(draft.equipment.baseLoftFromCatalog ? "Catalog base loft" : "User-entered base loft")).font(.caption)
                            }
                        } else { Text(preferences.text("Unavailable")) }
                    }
                }
                if let source = hosel.source, let url = URL(string: source) { Link(preferences.text("Source"), destination: url) }
            } header: { Text(preferences.text("Adjustable hosel")) }
        }
    }

    private func positionLabel(_ position: CatalogHoselPosition) -> String {
        func delta(_ value: Double?) -> String {
            value.map { $0.formatted(.number.locale(preferences.locale).precision(.fractionLength(0...2))) + "°" } ?? preferences.text("Unavailable")
        }
        return preferences.format("catalog.hoselDeltas", position.label + (position.label == "—" ? " (\(position.index))" : ""),
                                  delta(position.loftDeltaDegrees), delta(position.lieDeltaDegrees))
    }

    private func decimalField(_ title: LocalizationKey, value: Binding<String>, suffix: String? = nil, signed: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(preferences.text(title))
                // An empty input is not a missing measurement; the placeholder already says it is optional.
                if !value.wrappedValue.isEmpty { ProvenanceBadge(provenance: .userEntered) }
            }
            Spacer(minLength: 12)
            TextField(preferences.text("Optional"), text: value)
                .multilineTextAlignment(.trailing)
                .keyboardType(signed ? .numbersAndPunctuation : .decimalPad)
                .monospacedDigit()
                .frame(minWidth: 68, maxWidth: 110)
                .accessibilityLabel(preferences.text(title))
            if !(suffix ?? inputUnit.symbol).isEmpty {
                Text(suffix ?? inputUnit.symbol).foregroundStyle(.secondary)
            }
        }
    }

    private func save() {
        do {
            let values = try draft.validated(unit: inputUnit, locale: preferences.locale)
            let record = club ?? GolfClub(name: values.name, category: values.category)
            let previous = club.map { ClubDraft(club: $0, unit: inputUnit, locale: preferences.locale) }
            values.apply(to: record)
            if club == nil { modelContext.insert(record) }
            do {
                try modelContext.save()
            } catch {
                // Restore persisted model values while keeping every edited field in the form.
                if let previous, let oldValues = try? previous.validated(unit: inputUnit, locale: preferences.locale) {
                    oldValues.apply(to: record)
                } else if club == nil {
                    modelContext.delete(record)
                }
                throw error
            }
            dismiss()
        } catch let error as ClubInputError {
            inputError = error
            showingError = true
        } catch {
            inputError = ClubInputError(field: "Storage", message: "Your changes could not be saved. Your entries are still here; try again.")
            showingError = true
        }
    }
}
