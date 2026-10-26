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

    init(club: GolfClub? = nil) { self.club = club }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(preferences.text("Club name"), text: $draft.name)
                        .textInputAutocapitalization(.words)
                    Picker(preferences.text("Category"), selection: $draft.category) {
                        ForEach(ClubCategory.allCases) { category in
                            Text(preferences.text(category.rawValue)).tag(category.rawValue)
                        }
                    }
                    TextField(preferences.text("Brand"), text: $draft.brand)
                    TextField(preferences.text("Model"), text: $draft.modelName)
                    decimalField("Loft", value: $draft.loft, suffix: "°")
                    TextField(preferences.text("Shaft"), text: $draft.shaft)
                    TextField(preferences.text("Flex"), text: $draft.flex)
                } header: { Text(preferences.text("Equipment")) }

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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(preferences.text("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(preferences.text("Save"), action: save).fontWeight(.semibold)
                }
            }
            .alert(preferences.text("Could not save club"), isPresented: $showingError) {
                Button(preferences.text("OK"), role: .cancel) {}
            } message: {
                if let inputError {
                    Text("\(preferences.text(inputError.field)): \(preferences.text(inputError.message))")
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

    private func decimalField(_ title: String, value: Binding<String>, suffix: String? = nil, signed: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(preferences.text(title))
                ProvenanceBadge(provenance: value.wrappedValue.isEmpty ? .unavailable : .userEntered)
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
