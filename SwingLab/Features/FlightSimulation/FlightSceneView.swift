import SwiftUI
import SwingLabCore

/// A simulated flight seen from behind the ball, played over its real flight time and then its
/// run, the way a launch-monitor simulator shows a shot. The trace is dashed, the badge says
/// simulated, and the perspective is a schematic: nothing in it is to scale.
struct FlightSceneView: View {
    @Environment(AppPreferences.self) private var prefs
    let playback: FlightPlayback
    /// Shown under the picture when the lateral motion was simulated from known inputs.
    var shape: ShotShapeClassification? = nil
    /// The measurement was face-on: lateral motion is unknown and the ball is drawn straight.
    var faceOn = false
    var height: CGFloat = 180
    @State private var startedAt = Date()
    @State private var playing = true
    @State private var stopper: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !playing)) { timeline in
                Canvas { context, size in
                    draw(in: &context, size: size, time: timeline.date.timeIntervalSince(startedAt))
                }
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: SLTheme.cornerRadius))
            .contentShape(Rectangle())
            .onTapGesture { replay() }
            .accessibilityLabel(prefs.text("Flight seen from behind the ball (simulated, not to scale). Tap to replay."))
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    ProvenanceBadge(provenance: .simulated)
                    if faceOn {
                        Text(prefs.text("Shape cannot be seen by a face-on camera; the flight is drawn straight along the target line."))
                            .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    } else if let shape {
                        HStack(spacing: 12) {
                            Text(prefs.text(shape.shape.localizationKey)).font(.caption.weight(.semibold))
                            SLMetricReadout(metric: shape.startMetric, label: prefs.text("Start (right +)"), fractionDigits: 1, valueFont: .caption2, alignment: .leading)
                            SLMetricReadout(metric: shape.curveMetric, label: prefs.text("Curve (right +)"), fractionDigits: 0, valueFont: .caption2, alignment: .leading)
                        }
                    }
                }
                Spacer(minLength: 0)
                Button(prefs.text("Replay"), systemImage: "arrow.counterclockwise") { replay() }
                    .font(.caption).labelStyle(.iconOnly)
                    .accessibilityIdentifier("flight.replay")
            }
        }
        .onAppear { replay() }
        .onChange(of: playback) { replay() }
        .onDisappear { stopper?.cancel() }
    }

    private func replay() {
        startedAt = .now
        playing = true
        stopper?.cancel()
        let total = playback.duration + 0.75
        stopper = Task {
            try? await Task.sleep(for: .seconds(total))
            if !Task.isCancelled { playing = false }
        }
    }

    // MARK: Drawing

    private static let sky = Color(red: 0.74, green: 0.84, blue: 0.93), horizon = Color(red: 0.90, green: 0.93, blue: 0.95)
    private static let turfFar = Color(red: 0.36, green: 0.55, blue: 0.35), turfNear = Color(red: 0.45, green: 0.64, blue: 0.42)
    private static let trace = Color(red: 0.98, green: 0.98, blue: 0.95), shadow = Color.black.opacity(0.35)
    private static let marker = Color(red: 0.86, green: 0.78, blue: 0.56)
    /// Camera behind the tee: how far back and how high (m), and where the horizon sits.
    private static let cameraBack = 10.0, cameraHeight = 2.4, horizonShare = 0.36

    private struct Projection {
        let size: CGSize
        let horizonY: CGFloat
        let focal: CGFloat
        func point(forward: Double, height: Double, right: Double) -> CGPoint {
            let depth = max(0.5, forward + FlightSceneView.cameraBack)
            return CGPoint(x: size.width / 2 + focal * CGFloat(right / depth),
                           y: horizonY + focal * CGFloat((FlightSceneView.cameraHeight - height) / depth))
        }
        func scale(forward: Double) -> CGFloat { CGFloat(FlightSceneView.cameraBack / max(0.5, forward + FlightSceneView.cameraBack)) }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let horizonY = size.height * Self.horizonShare
        // The tee lands near the bottom edge; everything else follows from that focal length.
        let focal = (size.height - 16 - horizonY) * CGFloat(Self.cameraBack / Self.cameraHeight)
        let projection = Projection(size: size, horizonY: horizonY, focal: focal)
        let unit = prefs.distanceUnit
        let farthest = max(playback.rest.forward, playback.samples.map(\.forward).max() ?? 0, unit.toSI(100)) * 1.15

        context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: horizonY)),
                     with: .linearGradient(Gradient(colors: [Self.sky, Self.horizon]), startPoint: .zero, endPoint: CGPoint(x: 0, y: horizonY)))
        context.fill(Path(CGRect(x: 0, y: horizonY, width: size.width, height: size.height - horizonY)),
                     with: .linearGradient(Gradient(colors: [Self.turfFar, Self.turfNear]), startPoint: CGPoint(x: 0, y: horizonY),
                                           endPoint: CGPoint(x: 0, y: size.height)))
        // Fairway edges and the target line.
        let halfWidth = 30.0
        var edges = Path()
        for side in [-halfWidth, halfWidth] {
            edges.move(to: projection.point(forward: 0, height: 0, right: side))
            edges.addLine(to: projection.point(forward: farthest, height: 0, right: side))
        }
        context.stroke(edges, with: .color(.white.opacity(0.35)), lineWidth: 1)
        var target = Path()
        target.move(to: projection.point(forward: 0, height: 0, right: 0))
        target.addLine(to: projection.point(forward: farthest, height: 0, right: 0))
        context.stroke(target, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
        // Distance lines every 50 of the display unit, labelled on the left.
        let step = unit.toSI(50)
        var mark = step
        while mark < farthest {
            var line = Path()
            line.move(to: projection.point(forward: mark, height: 0, right: -halfWidth))
            line.addLine(to: projection.point(forward: mark, height: 0, right: halfWidth))
            context.stroke(line, with: .color(.white.opacity(0.45)), lineWidth: 1)
            let label = Text(unit.fromSI(mark).formatted(.number.precision(.fractionLength(0)).locale(prefs.locale)))
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.9))
            let anchor = projection.point(forward: mark, height: 0, right: -halfWidth)
            context.draw(label, at: CGPoint(x: max(12, anchor.x - 14), y: anchor.y), anchor: .trailing)
            mark += step
        }
        // Where the ball comes to rest, and the carry point, once reached.
        if time >= playback.flightTime, let landing = playback.landing {
            let point = projection.point(forward: landing.forward, height: 0, right: landing.right)
            let radius = 3 + 6 * projection.scale(forward: landing.forward)
            context.stroke(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius / 3, width: 2 * radius, height: 2 * radius / 3)),
                           with: .color(Self.marker), lineWidth: 1.5)
        }
        if time >= playback.duration {
            let rest = playback.rest
            let point = projection.point(forward: rest.forward, height: 0, right: rest.right)
            let radius = 2 + 5 * projection.scale(forward: rest.forward)
            context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius / 3, width: 2 * radius, height: 2 * radius / 3)),
                         with: .color(Self.marker.opacity(0.9)))
        }
        // The trace so far: its ground shadow first, then the dashed flight.
        let end = min(time, playback.duration)
        let steps = max(2, Int(end / 0.04))
        var flight = Path(), ground = Path()
        for index in 0...steps {
            let position = playback.position(at: end * Double(index) / Double(steps))
            let air = projection.point(forward: position.forward, height: position.height, right: position.right)
            let floor = projection.point(forward: position.forward, height: 0, right: position.right)
            if index == 0 { flight.move(to: air); ground.move(to: floor) } else { flight.addLine(to: air); ground.addLine(to: floor) }
        }
        context.stroke(ground, with: .color(Self.shadow), lineWidth: 1.5)
        context.stroke(flight, with: .color(Self.trace), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4]))
        // The ball and its shadow.
        let position = playback.position(at: min(time, playback.duration + 0.0001))
        let scale = projection.scale(forward: position.forward)
        let ball = projection.point(forward: position.forward, height: position.height, right: position.right)
        let floor = projection.point(forward: position.forward, height: 0, right: position.right)
        let radius = max(2.5, 7 * scale)
        if !position.rolling {
            context.fill(Path(ellipseIn: CGRect(x: floor.x - radius, y: floor.y - radius / 3, width: 2 * radius, height: 2 * radius / 3)),
                         with: .color(Self.shadow))
        }
        context.fill(Path(ellipseIn: CGRect(x: ball.x - radius, y: ball.y - radius, width: 2 * radius, height: 2 * radius)), with: .color(.white))
        context.stroke(Path(ellipseIn: CGRect(x: ball.x - radius, y: ball.y - radius, width: 2 * radius, height: 2 * radius)),
                       with: .color(.black.opacity(0.25)), lineWidth: 0.5)
    }
}
