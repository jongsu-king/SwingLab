import SwiftUI
import SwiftData
import MapKit
import SwingLabCore

private enum ReferenceKind: String, CaseIterable, Identifiable {
    case target = "Target", ball = "Ball position", front = "Green front", center = "Green center"
    case back = "Green back", hazard = "Hazard reference", layup = "Layup point"
    var id: String { rawValue }
}

struct CourseView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.modelContext) private var context
    @Query(sort: \GolfClub.name) private var clubs: [GolfClub]
    @Query(sort: \GolfCourse.name) private var courses: [GolfCourse]
    @Query(sort: \RoundSession.startedAt, order: .reverse) private var rounds: [RoundSession]
    @State private var location = LocationService()
    @State private var camera: MapCameraPosition = .automatic
    @State private var selectedCourseID: UUID?
    @State private var selectedClubID: UUID?
    @State private var holeNumber = 1
    @State private var target: GeoCoordinate?
    @State private var manualOrigin: GeoCoordinate?
    @State private var referenceKind = ReferenceKind.target
    @State private var showSearch = false
    @State private var showStart = false
    @State private var showCaddie = false
    @State private var showDetails = false
    @State private var errorKey: String?

    private var activeRound: RoundSession? { rounds.first { $0.endedAt == nil } }
    private var selectedCourse: GolfCourse? { courses.first { $0.id == selectedCourseID } }
    private var selectedClub: GolfClub? { clubs.first { $0.id == selectedClubID } }
    private var origin: GeoCoordinate? { manualOrigin ?? location.fix?.coordinate }
    private var targetDistance: Double? {
        guard let origin, let target else { return nil }
        return Geo.distance(from: origin, to: target)
    }
    private var estimate: CourseLandingEstimate? {
        guard let origin, let target, let selectedClub else { return nil }
        return CourseLandingEstimate(origin: origin, target: target, club: selectedClub)
    }
    private var hole: CourseHole? { selectedCourse?.holes.first { $0.number == holeNumber } }
    private var references: [CourseReferencePoint] { hole?.references.filter { $0.kind != ReferenceKind.target.rawValue } ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            courseHeader
            MapReader { proxy in
                Map(position: $camera) {
                    if let origin {
                        Annotation(preferences.text(manualOrigin == nil ? "GPS position" : "Ball position"), coordinate: origin.mapCoordinate) {
                            Circle().fill(.white).frame(width: 17, height: 17)
                                .overlay(Circle().stroke(SLTheme.forest, lineWidth: 5))
                                .accessibilityLabel(preferences.text(manualOrigin == nil ? "GPS position" : "User-entered ball position"))
                        }
                    }
                    if let target {
                        Annotation(preferences.text("Target"), coordinate: target.mapCoordinate) {
                            Image(systemName: "flag.fill").font(.title2).foregroundStyle(SLTheme.forest)
                                .padding(11).background(.regularMaterial, in: Circle())
                                .accessibilityLabel(preferences.text("Target. Drag to move."))
                                .gesture(DragGesture(coordinateSpace: .global)
                                    .onChanged { value in
                                        if let coordinate = proxy.convert(value.location, from: .global) {
                                            self.target = coordinate.geoCoordinate
                                        }
                                    }
                                    .onEnded { _ in if let target = self.target { saveReference(.target, coordinate: target) } })
                        }
                        if let origin {
                            MapPolyline(coordinates: [origin.mapCoordinate, target.mapCoordinate])
                                .stroke(SLTheme.forest, style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        }
                    }
                    ForEach(references) { reference in
                        Marker(preferences.text(reference.kind), coordinate: reference.coordinate.mapCoordinate)
                            .tint(reference.kind == ReferenceKind.hazard.rawValue ? .orange : SLTheme.sand)
                    }
                    if let estimate {
                        if !estimate.region80.isEmpty {
                            MapPolygon(coordinates: estimate.region80).foregroundStyle(SLTheme.forest.opacity(0.16))
                                .stroke(SLTheme.forest.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            MapPolygon(coordinates: estimate.region50).foregroundStyle(SLTheme.forest.opacity(0.25))
                                .stroke(SLTheme.forest, lineWidth: 1.5)
                        }
                        Annotation(preferences.text("Estimated landing"), coordinate: estimate.expectedCoordinate) {
                            Image(systemName: "plus").font(.headline.weight(.heavy)).foregroundStyle(SLTheme.ink)
                                .padding(6).background(SLTheme.sage, in: Circle())
                        }
                    }
                }
                .mapStyle(.hybrid(elevation: .flat))
                .mapControls { MapCompass(); MapScaleView() }
                .onTapGesture { point in
                    guard let coordinate = proxy.convert(point, from: .local) else { return }
                    if referenceKind == .ball { manualOrigin = coordinate.geoCoordinate }
                    else { saveReference(referenceKind, coordinate: coordinate.geoCoordinate) }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { controls }
        }
        .navigationTitle(preferences.text("Course"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showSearch = true } label: { Label(preferences.text("Find course"), systemImage: "magnifyingglass") }
                    .disabled(activeRound != nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { RoundHistoryView() } label: { Label(preferences.text("Round history"), systemImage: "list.bullet.rectangle") }
            }
        }
        .sheet(isPresented: $showSearch) {
            CourseSearchView(near: location.fix?.mapCoordinate, savedCourses: courses) { course in
                selectedCourseID = course.id
                center(on: CLLocationCoordinate2D(latitude: course.latitude, longitude: course.longitude))
                loadHole()
            }
        }
        .sheet(isPresented: $showStart) {
            StartRoundView(course: selectedCourse) { round in
                selectedCourseID = round.course?.id
                holeNumber = 1
                loadHole()
            }
        }
        .sheet(isPresented: $showCaddie) {
            CaddieView(clubs: clubs, targetDistance: targetDistance ?? 0) { selectedClubID = $0.id }
        }
        .onAppear {
            if let activeRound {
                selectedCourseID = activeRound.course?.id
                holeNumber = activeRound.currentHole
                loadHole()
            }
        }
        .onChange(of: location.fix?.timestamp) { _, _ in
            if manualOrigin == nil, let fix = location.fix { center(on: fix.mapCoordinate) }
        }
        .onChange(of: courses.map(\.id)) { _, ids in
            if let selectedCourseID, !ids.contains(selectedCourseID) {
                self.selectedCourseID = nil
                target = nil
                manualOrigin = nil
                holeNumber = 1
            }
        }
    }

    private var courseHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedCourse?.name ?? preferences.text("Manual course")).font(.headline).lineLimit(1)
                Text(preferences.text("Map references are user-entered")).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Picker(preferences.text("Hole"), selection: $holeNumber) {
                ForEach(1...(activeRound?.holeCount ?? 18), id: \.self) { Text(preferences.text("Hole") + " \($0)").tag($0) }
            }.labelsHidden().disabled(activeRound?.pendingShot != nil)
                .onChange(of: holeNumber) { _, newValue in
                    activeRound?.currentHole = newValue
                    saveContext()
                    loadHole()
                }
        }.padding(.horizontal, 18).padding(.vertical, 10).background(SLTheme.background)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(targetDistance.map(preferences.distance) ?? "—")
                        .font(.system(size: 30, weight: .medium, design: .rounded)).monospacedDigit()
                    Text(preferences.text("To target")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Picker(preferences.text("Place on map"), selection: $referenceKind) {
                        ForEach(ReferenceKind.allCases) { Text(preferences.text($0.rawValue)).tag($0) }
                    }
                    if let target {
                        Button(preferences.text("Clear target")) {
                            self.target = nil
                            if let hole { hole.references.removeAll { $0.kind == ReferenceKind.target.rawValue }; saveContext() }
                        }
                        Button(preferences.text("Center target")) { center(on: target.mapCoordinate) }
                    }
                } label: {
                    Label(preferences.text(referenceKind.rawValue), systemImage: "mappin.and.ellipse").font(.subheadline)
                }
                Button {
                    manualOrigin = nil
                    location.requestFix()
                } label: {
                    if location.isRequesting { ProgressView().frame(width: 44, height: 44) }
                    else { Image(systemName: "location.fill").frame(width: 44, height: 44) }
                }.accessibilityLabel(preferences.text("Refresh GPS")).disabled(location.isRequesting)
            }
            HStack {
                Picker(preferences.text("Club"), selection: $selectedClubID) {
                    Text(preferences.text("Select club")).tag(UUID?.none)
                    ForEach(clubs) { Text($0.name).tag(Optional($0.id)) }
                }.labelsHidden()
                Spacer()
                Button(preferences.text("Caddie")) { showCaddie = true }.disabled(targetDistance == nil)
                if let activeRound {
                    NavigationLink { ScorecardView(round: activeRound) } label: {
                        Image(systemName: "list.clipboard").frame(minWidth: 44, minHeight: 44)
                    }.accessibilityLabel(preferences.text("Scorecard"))
                }
            }
            HStack {
                if activeRound == nil {
                    Button(preferences.text("Start round")) { showStart = true }.buttonStyle(.borderedProminent)
                } else {
                    Button(preferences.text(activeRound?.pendingShot == nil ? "Record ball position" : "Finish shot here"), action: recordPosition)
                        .buttonStyle(.borderedProminent)
                        .disabled(location.isRequesting || (activeRound?.pendingShot == nil && selectedClub == nil))
                }
                Spacer()
                Button { showDetails.toggle() } label: {
                    Label(preferences.text("Details"), systemImage: showDetails ? "chevron.down" : "info.circle")
                }.font(.subheadline)
            }
            if let message = errorKey ?? location.errorKey {
                Text(preferences.text(message)).font(.caption).foregroundStyle(.red)
            }
            locationStatus
            if showDetails { details.frame(maxHeight: 190) }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(SLTheme.background).tint(SLTheme.forest)
    }

    private var details: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(preferences.text("Tap the map to place the selected reference. Drag the target flag to adjust your aim."))
                if manualOrigin != nil {
                    Text(preferences.text("Ball position: user-entered. Shot recording always uses a fresh GPS fix."))
                }
                if let estimate {
                    Text(preferences.text("Estimated carry") + ": " + preferences.distance(estimate.carryMeters))
                    Text(preferences.text("Expected distance from target") + ": " + preferences.distance(estimate.remainingMeters))
                    Text(preferences.text(estimate.region80.isEmpty
                                          ? "Add carry and lateral variability in My Bag to show probability regions."
                                          : "Inner region: 50%. Dashed outer region: 80%. Conditional on your entered club profile; not a calibrated guarantee."))
                }
                ForEach(references) { reference in
                    if let origin {
                        Text(preferences.text(reference.kind) + ": " + preferences.distance(Geo.distance(from: origin, to: reference.coordinate)))
                    }
                }
                Text(preferences.text("Wind, terrain and hazard probabilities: unavailable. MapKit does not supply verified hole geometry."))
                Text(preferences.text("GPS shots measure ground displacement, including roll. They do not update carry statistics."))
            }.font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var locationStatus: some View {
        TimelineView(.periodic(from: .now, by: 5)) { timeline in
            VStack(alignment: .leading, spacing: 3) {
                if manualOrigin != nil { Text(preferences.text("Ball position: user-entered")) }
                if let fix = location.fix {
                    HStack {
                        Text(preferences.text("GPS accuracy") + " ±" + preferences.distance(fix.horizontalAccuracy))
                        Text(fix.timestamp, style: .time)
                    }
                    if !fix.isUsableForShot(at: timeline.date) {
                        Text(preferences.text("GPS is stale or too uncertain for shot recording. Refresh GPS."))
                            .foregroundStyle(.orange)
                    }
                } else { Text(preferences.text("Tap the location button for GPS, or place a ball position on the map.")) }
            }.font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func center(on coordinate: CLLocationCoordinate2D) {
        camera = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 850, longitudinalMeters: 850))
    }

    private func loadHole() {
        target = hole?.references.first { $0.kind == ReferenceKind.target.rawValue }?.coordinate
    }

    private func saveReference(_ kind: ReferenceKind, coordinate: GeoCoordinate) {
        if kind == .target { target = coordinate }
        let course: GolfCourse
        if let selectedCourse { course = selectedCourse }
        else {
            course = GolfCourse(name: preferences.text("Manual course"), latitude: coordinate.latitude, longitude: coordinate.longitude)
            context.insert(course)
            selectedCourseID = course.id
            if let round = activeRound, round.course == nil {
                round.course = course
                course.name = round.courseName
            }
        }
        let editedHole: CourseHole
        if let existing = course.holes.first(where: { $0.number == holeNumber }) { editedHole = existing }
        else {
            editedHole = CourseHole(number: holeNumber)
            context.insert(editedHole)
            course.holes.append(editedHole)
        }
        var points = editedHole.references.filter { $0.kind != kind.rawValue }
        points.append(CourseReferencePoint(kind: kind.rawValue, latitude: coordinate.latitude, longitude: coordinate.longitude))
        editedHole.references = points
        saveContext()
    }

    private func recordPosition() {
        errorKey = nil
        guard let round = activeRound else { return }
        guard let fix = location.fix, fix.isUsableForShot() else {
            errorKey = "Refresh GPS first. Shot recording needs a fix less than 20 seconds old with accuracy within 30 meters."
            location.requestFix()
            return
        }
        if let shot = round.pendingShot {
            guard fix.timestamp > shot.startedAt else {
                errorKey = "Refresh GPS at the next ball position before finishing this shot."
                location.requestFix()
                return
            }
            shot.endLatitude = fix.latitude
            shot.endLongitude = fix.longitude
            shot.endAccuracyMeters = fix.horizontalAccuracy
            shot.endedAt = fix.timestamp
        } else {
            guard let club = selectedClub else { return }
            let shot = ShotRecord(holeNumber: holeNumber,
                                  shotNumber: (round.shots.filter { $0.holeNumber == holeNumber }.map(\.shotNumber).max() ?? 0) + 1,
                                  clubID: club.id, clubName: club.name,
                                  startLatitude: fix.latitude, startLongitude: fix.longitude,
                                  startAccuracyMeters: fix.horizontalAccuracy, startedAt: fix.timestamp)
            context.insert(shot)
            round.shots.append(shot)
        }
        saveContext()
    }

    private func saveContext() {
        do { try context.save(); errorKey = nil }
        catch { context.rollback(); errorKey = "Your changes could not be saved. Try again." }
    }
}

private extension GeoCoordinate {
    var mapCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

private extension CLLocationCoordinate2D {
    var geoCoordinate: GeoCoordinate { GeoCoordinate(latitude: latitude, longitude: longitude) }
}
