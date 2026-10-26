import SwiftUI
import SwingLabCore

/// A deterministic hierarchy plus global search; custom entry remains available at every level.
struct CatalogPickerView: View {
    @Environment(AppPreferences.self) private var preferences
    let onSelect: (CatalogClub, String) -> Void
    let onCustom: () -> Void
    @State private var query = ""
    private let catalog = CatalogStore.catalog

    var body: some View {
        List {
            Button(preferences.text("Not in the list"), action: onCustom)
            if query.isEmpty {
                ForEach(catalog.brands) { brand in
                    NavigationLink(brand.name) {
                        CatalogCategoryPicker(brand: brand, onSelect: onSelect, onCustom: onCustom)
                    }
                }
            } else {
                ForEach(catalog.search(query)) { club in
                    CatalogModelRow(club: club, onSelect: onSelect, onCustom: onCustom)
                }
            }
        }
        .navigationTitle(preferences.text("Club catalog"))
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: preferences.text("Search equipment"))
    }
}

private struct CatalogCategoryPicker: View {
    @Environment(AppPreferences.self) private var preferences
    let brand: CatalogBrand
    let onSelect: (CatalogClub, String) -> Void
    let onCustom: () -> Void
    var body: some View {
        List {
            Button(preferences.text("Not in the list"), action: onCustom)
            ForEach(ClubCategory.allCases) { category in
                NavigationLink(preferences.text(category.localizationKey)) {
                    CatalogYearPicker(brand: brand, category: category, onSelect: onSelect, onCustom: onCustom)
                }
            }
        }.navigationTitle(brand.name)
    }
}

private struct CatalogYearPicker: View {
    @Environment(AppPreferences.self) private var preferences
    let brand: CatalogBrand
    let category: ClubCategory
    let onSelect: (CatalogClub, String) -> Void
    let onCustom: () -> Void
    private var years: [Int] {
        Array(Set(CatalogStore.catalog.search("", brandID: brand.id, category: category.rawValue).map(\.releaseYear))).sorted(by: >)
    }
    var body: some View {
        List {
            Button(preferences.text("Not in the list"), action: onCustom)
            ForEach(years, id: \.self) { year in
                NavigationLink(String(year)) {
                    List {
                        Button(preferences.text("Not in the list"), action: onCustom)
                        ForEach(CatalogStore.catalog.search("", brandID: brand.id, category: category.rawValue, year: year)) { club in
                            CatalogModelRow(club: club, onSelect: onSelect, onCustom: onCustom)
                        }
                    }.navigationTitle(String(year))
                }
            }
        }.navigationTitle(preferences.text(category.localizationKey))
    }
}

private struct CatalogModelRow: View {
    @Environment(AppPreferences.self) private var preferences
    let club: CatalogClub
    let onSelect: (CatalogClub, String) -> Void
    let onCustom: () -> Void
    var body: some View {
        NavigationLink {
            List {
                Button(preferences.text("Not in the list"), action: onCustom)
                if !club.verified { Text(preferences.text("Catalog entry not yet verified.")) }
                if let source = club.source, let url = URL(string: source) { Link(preferences.text("Source"), destination: url) }
                if club.availableClubs.isEmpty {
                    ForEach(club.variants.isEmpty ? [""] : club.variants, id: \.self) { variant in
                        Button([club.model, variant].filter { !$0.isEmpty }.joined(separator: " ")) { onSelect(club, variant) }
                            .accessibilityIdentifier("catalog.select.\(club.id).\(variant.isEmpty ? "base" : variant)")
                    }
                } else {
                    ForEach(club.availableClubs, id: \.self) { member in
                        Button(club.model + " · " + member) { onSelect(club, member) }
                    }
                }
            }.navigationTitle(club.model)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(club.model)
                Text(String(club.releaseYear)).font(.caption).foregroundStyle(.secondary)
                if !club.verified { Text(preferences.text("Unverified catalog entry")).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .accessibilityIdentifier("catalog.model.\(club.id)")
    }
}

struct ShaftCatalogPickerView: View {
    @Environment(AppPreferences.self) private var preferences
    let onSelect: (CatalogShaft) -> Void
    let onCustom: () -> Void
    @State private var query = ""
    private var shafts: [CatalogShaft] {
        CatalogStore.catalog.shafts.filter { query.isEmpty ||
            ($0.brand + " " + $0.model).range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
    var body: some View {
        List {
            Button(preferences.text("Not in the list"), action: onCustom)
            ForEach(shafts) { shaft in
            Button { onSelect(shaft) } label: {
                VStack(alignment: .leading) {
                    Text(shaft.brand + " · " + shaft.model)
                    if !shaft.verified { Text(preferences.text("Unverified catalog entry")).font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        }
        .navigationTitle(preferences.text("Shaft catalog"))
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: preferences.text("Search equipment"))
    }
}
