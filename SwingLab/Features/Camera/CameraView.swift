import SwiftUI
import UIKit
import SwingLabCore
@preconcurrency import AVFoundation

struct CameraView: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var camera = CameraController()
    @State private var angle = CameraAngle.faceOn
    @State private var showGrid = true
    @State private var exposure = 0.0
    var onSave: (URL, CameraAngle) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if camera.authorized {
                    GeometryReader { geometry in
                        CameraPreview(engine: camera.engine)
                        if showGrid {
                            Path { path in
                                for fraction in [1.0 / 3, 2.0 / 3] {
                                    path.move(to: CGPoint(x: geometry.size.width * fraction, y: 0))
                                    path.addLine(to: CGPoint(x: geometry.size.width * fraction, y: geometry.size.height))
                                    path.move(to: CGPoint(x: 0, y: geometry.size.height * fraction))
                                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * fraction))
                                }
                            }.stroke(.white.opacity(0.35), lineWidth: 0.5).allowsHitTesting(false)
                        }
                    }
                    VStack {
                        Text(prefs.text(angle == .faceOn ? "Keep your full body and club in view." : "Place the camera along your hand line."))
                            .font(.subheadline).multilineTextAlignment(.center)
                            .padding(12).background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                        if camera.interrupted {
                            Text(prefs.text("Camera interrupted. Recording will resume only when you start it again."))
                                .padding().background(.black.opacity(0.7))
                        }
                        Spacer()
                        if let date = camera.recordedAt {
                            TimelineView(.periodic(from: date, by: 0.2)) { context in
                                SLMetricReadout(metric: ProvenancedValue(value: max(0, context.date.timeIntervalSince(date)),
                                                                         unit: "s", provenance: .measured,
                                                                         method: "capture.elapsedClock.v1"),
                                                fractionDigits: 1, valueFont: .title2)
                                    .environment(\.colorScheme, .dark)
                                    .padding(10).background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        controls
                    }.padding()
                } else if camera.denied {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill").font(.largeTitle)
                        Text(prefs.text("Allow camera access to record a swing.")).multilineTextAlignment(.center)
                        Button(prefs.text("Open Settings")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }.buttonStyle(.borderedProminent).foregroundStyle(SLTheme.background)
                    }.padding(32)
                } else { ProgressView().tint(.white) }
            }
            .foregroundStyle(.white)
            .navigationTitle(prefs.text("Record swing"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(prefs.text("Close")) { camera.stop(); dismiss() }.disabled(camera.isRecording)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showGrid.toggle() } label: { Image(systemName: showGrid ? "grid" : "square") }
                        .accessibilityLabel(prefs.text("Toggle alignment grid"))
                }
            }
            .task { await camera.start() }
            .onDisappear { camera.stop() }
            .onChange(of: camera.savedURL) { _, url in
                guard let url else { return }
                onSave(url, angle)
                dismiss()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await camera.start() } }
                else { camera.stop() }
            }
            .alert(prefs.text("Camera"), isPresented: Binding(get: { camera.error != nil }, set: { if !$0 { camera.error = nil } })) {
                Button(prefs.text("OK"), role: .cancel) { camera.error = nil }
            } message: { Text(prefs.text(camera.error ?? "")) }
        }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "sun.min")
                Slider(value: $exposure, in: -2...2).tint(.white)
                    .accessibilityLabel(prefs.text("Exposure"))
                    .onChange(of: exposure) { _, value in camera.engine.exposure(bias: Float(value)) }
                Image(systemName: "sun.max")
            }
            HStack {
                Menu {
                    ForEach(camera.formats) { format in
                        Button(format.label) { camera.engine.selectFormat(format.id) }
                    }
                } label: {
                    Text(camera.formats.first(where: { $0.id == camera.selectedFormat })?.label ?? prefs.text("Camera format"))
                        .font(.caption).monospacedDigit()
                }.disabled(camera.isRecording)
                Spacer()
                Picker(prefs.text("Camera angle"), selection: $angle) {
                    Text(prefs.text(CameraAngle.faceOn.localizationKey)).tag(CameraAngle.faceOn)
                    Text(prefs.text(CameraAngle.downTheLine.localizationKey)).tag(CameraAngle.downTheLine)
                }.tint(.white).disabled(camera.isRecording)
            }
            HStack {
                Button { camera.switchCamera() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera").font(.title2).frame(width: 60, height: 60)
                }.disabled(camera.isRecording || !camera.ready)
                    .accessibilityLabel(prefs.text("Switch camera"))
                Spacer()
                Button {
                    if camera.isRecording { camera.engine.stopRecording() } else { camera.engine.startRecording() }
                } label: {
                    ZStack {
                        Circle().stroke(.white, lineWidth: 3).frame(width: 76, height: 76)
                        if camera.isRecording { RoundedRectangle(cornerRadius: 5).fill(.red).frame(width: 30, height: 30) }
                        else { Circle().fill(.red).frame(width: 62, height: 62) }
                    }
                }.disabled(!camera.ready || camera.interrupted)
                    .accessibilityLabel(prefs.text(camera.isRecording ? "Stop recording" : "Start recording"))
                Spacer()
                Text(prefs.text("60 s max")).font(.caption).frame(width: 60)
            }
            Text(prefs.text(camera.recordsAudio ? "Sound on for impact timing · tap preview to focus"
                                                : "No sound · impact from pose only · tap preview to focus"))
                .font(.caption).foregroundStyle(.white.opacity(0.75))
        }.padding(16).background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct CameraPreview: UIViewRepresentable {
    let engine: CameraEngine
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.layerView.session = engine.session
        view.layerView.videoGravity = .resizeAspect
        view.focus = { point in engine.focus(at: point) }
        return view
    }
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if let connection = uiView.layerView.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
    }
}

private final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var layerView: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var focus: ((CGPoint) -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        focus?(layerView.captureDevicePointConverted(fromLayerPoint: gesture.location(in: self)))
    }
}
