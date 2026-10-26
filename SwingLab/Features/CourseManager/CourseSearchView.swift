import SwingLabCore
import SwiftUI
import SwiftData
import MapKit

struct CourseSearchView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let near: CLLocationCoordinate2D?
    let savedCourses: [GolfCourse]
    let select: (GolfCourse) -> Void
    @State private var query = ""
    @State private var results: [CourseSearchResult] = []
    @State private var isSearching = false
    @State private var searched = false
    @State private var errorKey: LocalizationKey?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(preferences.text("Course name or location"), text: $query)
                        .submitLabel(.search).onSubmit(search)
                    Button(preferences.text("Search"), action: search)
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                    if isSearching { ProgressView() }
                    if let errorKey { Text(preferences.text(errorKey)).foregroundStyle(.red) }
                } footer: {
                    Text(preferences.text("Search uses Apple Maps and needs internet access. Results are places, not verified hole layouts."))
                }
                if !results.isEmpty {
                    Section(preferences.text("Search results")) {
                        ForEach(results) { result in
                            Button {
                                let course = GolfCourse(name: result.name, latitude: result.coordinate.latitude,
                                                        longitude: result.coordinate.longitude, source: "mapKitPlace")
                                context.insert(course)
                                do { try context.save(); select(course); dismiss() }
                                catch { context.rollbackPendingChanges(); errorKey = "Your changes could not be saved. Try again." }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.name).foregroundStyle(.primary)
                                    Text(result.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else if searched && !isSearching {
                    Text(preferences.text("No places found. Try the course name with its city."))
                }
                if !savedCourses.isEmpty {
                    Section(preferences.text("Saved courses")) {
                        ForEach(savedCourses) { course in
                            Button(course.name) { select(course); dismiss() }.foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle(preferences.text("Find course"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(preferences.text("Done")) { dismiss() } } }
            .onDisappear { searchTask?.cancel() }
        }
    }

    private func search() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        searchTask?.cancel()
        isSearching = true
        errorKey = nil
        searchTask = Task { @MainActor in
            do {
                let found = try await MapKitGolfCourseRepository().search(query: term, near: near)
                guard !Task.isCancelled else { return }
                results = found
                searched = true
                isSearching = false
            } catch is CancellationError { }
            catch {
                guard !Task.isCancelled else { return }
                errorKey = "Course search is unavailable. Try again with an internet connection."
                isSearching = false
            }
        }
    }
}

struct StartRoundView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let course: GolfCourse?
    let started: (RoundSession) -> Void
    @State private var name = ""
    @State private var holeCount = 18
    @State private var errorKey: LocalizationKey?

    var body: some View {
        NavigationStack {
            Form {
                TextField(preferences.text("Course name"), text: $name)
                Picker(preferences.text("Holes"), selection: $holeCount) {
                    Text("9").tag(9)
                    Text("18").tag(18)
                }.pickerStyle(.segmented)
                Text(preferences.text("Pars start empty unless you entered them before. Add scores, putts and penalties in the scorecard."))
                    .font(.footnote).foregroundStyle(.secondary)
                if let errorKey { Text(preferences.text(errorKey)).foregroundStyle(.red) }
                Button(preferences.text("Start round")) {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let round = RoundSession(courseName: trimmed, holeCount: holeCount, course: course)
                    context.insert(round)
                    for number in 1...holeCount {
                        let score = HoleScore(number: number, par: course?.holes.first { $0.number == number }?.par)
                        context.insert(score)
                        round.holeScores.append(score)
                    }
                    do { try context.save(); started(round); dismiss() }
                    catch { context.rollbackPendingChanges(); errorKey = "Your changes could not be saved. Try again." }
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle(preferences.text("Start round"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(preferences.text("Cancel")) { dismiss() } } }
            .onAppear { name = course?.name ?? preferences.text("Manual course") }
        }
    }
}
