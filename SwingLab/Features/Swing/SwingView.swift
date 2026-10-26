import SwiftUI
import SwiftData
import PhotosUI
import SwingLabCore

struct SwingView: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SwingRecording.createdAt, order: .reverse) private var recordings: [SwingRecording]
    @State private var showCamera = false
    @State private var importedItem: PhotosPickerItem?
    @State private var importing = false
    @State private var error: String?
    @State private var pendingDelete: SwingRecording?

    var body: some View {
        List {
                Section {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(prefs.text("A closer look\nat your swing."))
                            .font(.system(size: 32, weight: .regular, design: .serif)).foregroundStyle(SLTheme.ink)
                        Text(prefs.text("Record one swing. Review the movement. Build a practice worth repeating."))
                            .font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Button { showCamera = true } label: {
                                Label(prefs.text("Record swing"), systemImage: "camera")
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                            }.buttonStyle(.borderedProminent).tint(SLTheme.forest)
                            PhotosPicker(selection: $importedItem, matching: .videos) {
                                Image(systemName: "square.and.arrow.down").frame(width: 36, height: 36)
                            }.buttonStyle(.bordered).tint(SLTheme.forest)
                                .accessibilityLabel(prefs.text("Import video"))
                        }.disabled(importing)
                        if importing { ProgressView(prefs.text("Saving video…")) }
                    }.padding(.vertical, 12)
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 20, trailing: 0))

                Section {
                    if recordings.isEmpty {
                        SLEmptyState(title: prefs.text("Your practice starts here"),
                                     message: prefs.text("Record or import a video to review it frame by frame and analyze body pose on your iPhone."),
                                     symbol: "figure.golf")
                            .listRowBackground(SLTheme.surface)
                    } else {
                        ForEach(recordings) { recording in
                            NavigationLink {
                                SwingDetailView(recording: recording)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "play.rectangle").font(.title2).foregroundStyle(SLTheme.forest)
                                        .frame(width: 44, height: 54).background(SLTheme.sage.opacity(0.2))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(recording.title).font(.headline)
                                        Text(recording.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            .font(.caption).foregroundStyle(.secondary)
                                        HStack(spacing: 6) {
                                            Text(prefs.text(recording.cameraAngleValue.localizationKey))
                                            SLMetricReadout(metric: recording.durationMetric, fractionDigits: 1,
                                                            valueFont: .caption)
                                        }.font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if recording.analysisVersion > 0 {
                                        Image(systemName: "figure.stand").foregroundStyle(SLTheme.forest)
                                            .accessibilityLabel(prefs.text("Pose analyzed"))
                                    }
                                }.padding(.vertical, 6)
                            }.listRowBackground(SLTheme.surface)
                                .swipeActions { Button(prefs.text("Delete"), role: .destructive) { pendingDelete = recording } }
                        }
                    }
                } header: { Text(prefs.text("Practice library")) }
                Section {
                    NavigationLink {
                        SwingComparisonView()
                    } label: {
                        Label(prefs.text("Compare swings"), systemImage: "rectangle.split.2x1")
                    }
                }.listRowBackground(SLTheme.surface)
                Section {
                    NavigationLink {
                        HypotheticalFlightView()
                    } label: {
                        Label(prefs.text("Hypothetical flight"), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                } header: { Text(prefs.text("Ball Lab")) }
                .listRowBackground(SLTheme.surface)
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(prefs.text("Private by design"), systemImage: "iphone")
                            .font(.subheadline.weight(.medium))
                        Text(prefs.text("Videos, sound, and pose analysis stay on your iPhone. Imported videos keep their original audio."))
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 5)
                }.listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden).background(SLTheme.background)
            .navigationTitle(prefs.text("Swing"))
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { url, angle in
                    prefs.activeMediaWrites += 1
                    Task {
                        defer { prefs.activeMediaWrites -= 1 }
                        await save(url: url, angle: angle, source: .recorded)
                    }
                }
            }
            .onChange(of: importedItem) { _, item in
                guard let item else { return }
                // Cover the transfer itself: it writes a durable file before metadata/database work.
                prefs.activeMediaWrites += 1
                importing = true
                Task {
                    defer { importing = false; importedItem = nil; prefs.activeMediaWrites -= 1 }
                    do {
                        guard let movie = try await item.loadTransferable(type: ImportedSwingMovie.self) else {
                            throw VideoLibraryError.invalidVideo
                        }
                        await save(url: movie.url, angle: .unspecified, source: .imported)
                    } catch { self.error = "The video could not be imported. Try a local video shorter than three minutes." }
                }
            }
            .alert(prefs.text("Video library"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button(prefs.text("OK"), role: .cancel) { error = nil }
            } message: { Text(prefs.text(error ?? "")) }
            .confirmationDialog(prefs.text("Delete this recording and its analysis?"),
                                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                                titleVisibility: .visible) {
                Button(prefs.text("Delete recording"), role: .destructive) { deleteRecording() }
            }
    }

    @MainActor private func save(url: URL, angle: CameraAngle, source: RecordingSource) async {
        do {
            let metadata = try await VideoLibrary.metadata(for: url)
            let recording = SwingRecording(title: prefs.text("Swing recording"), videoFileName: url.lastPathComponent,
                                           durationSeconds: metadata.duration, nominalFrameRate: metadata.frameRate,
                                           videoWidth: metadata.width, videoHeight: metadata.height,
                                           cameraAngle: angle, source: source)
            modelContext.insert(recording)
            do { try modelContext.save() }
            catch { modelContext.delete(recording); throw error }
        } catch {
            try? FileManager.default.removeItem(at: url)
            self.error = (error as? VideoLibraryError)?.errorDescription ?? "The recording could not be saved. Check available storage."
        }
    }

    private func deleteRecording() {
        guard let recording = pendingDelete else { return }
        let name = recording.videoFileName
        pendingDelete = nil
        var original: URL?
        var staged: URL?
        do {
            // Stage on the same volume so a failed database save can restore the original movie.
            do {
                let file = try VideoLibrary.url(for: name)
                let temporary = file.deletingLastPathComponent().appendingPathComponent(".delete-" + UUID().uuidString + "-" + name)
                try FileManager.default.moveItem(at: file, to: temporary)
                original = file; staged = temporary
            } catch VideoLibraryError.missingFile { /* A missing original must not make its stale database row undeletable. */ }
            modelContext.delete(recording)
            do { try modelContext.save() }
            catch {
                modelContext.rollback()
                if let original, let staged { try FileManager.default.moveItem(at: staged, to: original) }
                throw error
            }
            if let staged {
                do { try FileManager.default.removeItem(at: staged) }
                catch { self.error = "The record was removed, but its video could not be erased. Use Delete All Local Data in Settings to retry." }
            }
        } catch { self.error = "The recording could not be deleted. Please try again." }
    }
}
