import SwiftUI
import SwiftData
import MapKit
import SwingLabCore

struct CourseGeometryEditor: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let hole: CourseHole
    let center: GeoCoordinate
    @State private var camera: MapCameraPosition = .automatic
    @State private var kind: CourseAreaKind = .fairway
    @State private var vertices: [GeoCoordinate] = []
    @State private var editingID: String?
    @State private var error: LocalizationKey?
    @State private var importing = false
    @State private var importTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                MapReader { proxy in
                    Map(position: $camera) {
                        ForEach(hole.areas.filter { $0.id != editingID }) { area in
                            MapPolygon(coordinates: area.vertices.map(\.mapCoordinate)).foregroundStyle(color(area.kind).opacity(0.25))
                                .stroke(color(area.kind), lineWidth: 1)
                        }
                        if vertices.count >= 3 {
                            MapPolygon(coordinates: vertices.map(\.mapCoordinate)).foregroundStyle(SLTheme.forest.opacity(0.3))
                        }
                        ForEach(Array(vertices.enumerated()), id: \.offset) { _, coordinate in
                            Annotation("", coordinate: coordinate.mapCoordinate) { Circle().fill(SLTheme.forest).frame(width: 10, height: 10) }
                        }
                    }.mapStyle(.hybrid(elevation: .flat))
                        .onTapGesture { point in
                            if let coordinate = proxy.convert(point, from: .local), vertices.count < 200 { vertices.append(coordinate.geoCoordinate) }
                        }
                }.frame(minHeight: 220)
                Text(prefs.text("Tap to add polygon vertices. Select an area to replace its outline."))
                    .font(.caption).padding(.horizontal)
                HStack {
                    Picker(prefs.text("Area type"), selection: $kind) {
                        ForEach(CourseAreaKind.allCases, id: \.self) { Text(prefs.text($0.localizationKey)).tag($0) }
                    }
                    Button(prefs.text("Undo")) { if !vertices.isEmpty { vertices.removeLast() } }.disabled(vertices.isEmpty)
                    Button(prefs.text("Save area"), action: saveArea).disabled(vertices.count < 3)
                }.padding(.horizontal)
                List {
                    if let error { Text(prefs.text(error)).foregroundStyle(.red) }
                    ForEach(hole.areas) { area in
                        Button {
                            editingID = area.id; kind = area.kind; vertices = area.vertices
                        } label: {
                            HStack {
                                Text(prefs.text(area.kind.localizationKey))
                                Spacer()
                                ProvenanceBadge(provenance: area.provenance)
                            }
                        }.swipeActions {
                            Button(prefs.text("Delete"), role: .destructive) {
                                hole.areas.removeAll { $0.id == area.id }; save()
                                if editingID == area.id { vertices = []; editingID = nil }
                            }
                        }
                    }
                    Button(prefs.text("New area")) { vertices = []; editingID = nil }
                    Button(prefs.text("Import OpenStreetMap areas"), action: importAreas).disabled(importing)
                    if importing { ProgressView() }
                    Text(prefs.text("Imported areas are community mapping, not surveyed boundaries. Saved areas work offline."))
                        .font(.caption).foregroundStyle(.secondary)
                    Link(prefs.text("© OpenStreetMap contributors · ODbL"), destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                        .font(.caption)
                }.frame(maxHeight: 260)
            }
            .navigationTitle(prefs.text("Course areas"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(prefs.text("Done")) { dismiss() } } }
            .onAppear { camera = .region(.init(center: center.mapCoordinate, latitudinalMeters: 700, longitudinalMeters: 700)) }
            .onDisappear { importTask?.cancel() }
        }
    }
    private func color(_ kind: CourseAreaKind) -> Color {
        switch kind { case .water: .blue; case .bunker: SLTheme.sand; case .penalty, .outOfBounds: .red; default: SLTheme.forest }
    }
    private func saveArea() {
        let old = editingID.flatMap { id in hole.areas.first { $0.id == id } }
        let area = CourseArea(id: editingID ?? UUID().uuidString, kind: kind, vertices: vertices,
                              provenance: .userEntered, sourceURL: old?.sourceURL)
        guard area.isValid else { return }
        hole.areas.removeAll { $0.id == area.id }; hole.areas.append(area)
        save(); vertices = []; editingID = nil
    }
    private func save() {
        do { try context.save(); error = nil }
        catch { context.rollbackPendingChanges(); self.error = "Changes could not be saved." }
    }
    private func importAreas() {
        importing = true; error = nil
        importTask = Task { @MainActor in
            defer { importing = false }
            do {
                let parsed = try await CourseGeometryService().fetch(near: center)
                try Task.checkCancellation()
                // Preserve user edits and existing offline copies on re-import.
                let existing = Set(hole.areas.map(\.id))
                hole.areas += parsed.areas.filter { !existing.contains($0.id) }
                save()
                if parsed.areas.isEmpty { error = "No complete mapped areas were found here." }
            } catch is CancellationError { }
            catch { self.error = "Map import failed. Your saved areas are still available." }
        }
    }
}
