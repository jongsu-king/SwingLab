import SwiftUI
import SwingLabCore

/// Schematic side view of the simulated flight: a dashed arc (never a tracer), the carry bracket
/// on the ground, and the total bracket beyond it. Heights are exaggerated; nothing is to scale.
struct LaunchRangeView: View {
    @Environment(AppPreferences.self) private var prefs
    let readout: LaunchReadout
    var height: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Canvas { context, size in draw(in: &context, size: size) }
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: SLTheme.cornerRadius))
                .accessibilityLabel(prefs.text("Range view (schematic, not to scale)"))
            HStack(spacing: 6) {
                ProvenanceBadge(provenance: .simulated, sampleCount: readout.carry?.low.sampleCount)
                Text(prefs.text("Range view (schematic, not to scale)")).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private static let sky = Color(red: 0.78, green: 0.86, blue: 0.93), horizon = Color(red: 0.93, green: 0.95, blue: 0.96)
    private static let turf = Color(red: 0.42, green: 0.60, blue: 0.40), arc = Color(red: 0.16, green: 0.30, blue: 0.22)
    private static let carryBand = Color(red: 0.22, green: 0.40, blue: 0.29), totalBand = Color(red: 0.86, green: 0.78, blue: 0.56)

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let unit = prefs.distanceUnit
        let farthest = max(readout.total?.high.value ?? 0, readout.carry?.high.value ?? 0,
                           readout.trajectory.map(\.forward).max() ?? 0, unit.toSI(50))
        let span = farthest * 1.12
        let groundY = size.height * 0.82, left: CGFloat = 12, right = size.width - 12
        func x(_ metres: Double) -> CGFloat { left + CGFloat(metres / span) * (right - left) }
        let apex = max(readout.trajectory.map(\.height).max() ?? 1, 1)
        func y(_ metres: Double) -> CGFloat { groundY - CGFloat(metres / apex) * (groundY - 14) }
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: [Self.sky, Self.horizon]), startPoint: .zero, endPoint: CGPoint(x: 0, y: groundY)))
        context.fill(Path(CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY)), with: .color(Self.turf))
        // Distance marks every 50 of the display unit.
        let step = unit.toSI(50)
        var mark = step
        while mark < span {
            let markX = x(mark)
            var tick = Path()
            tick.move(to: CGPoint(x: markX, y: groundY)); tick.addLine(to: CGPoint(x: markX, y: groundY + 5))
            context.stroke(tick, with: .color(.white.opacity(0.8)), lineWidth: 1)
            let label = Text(unit.fromSI(mark).formatted(.number.precision(.fractionLength(0)).locale(prefs.locale)))
                .font(.system(size: 9)).foregroundStyle(.white)
            context.draw(label, at: CGPoint(x: markX, y: groundY + 11))
            mark += step
        }
        if let total = readout.total, let low = total.low.value, let high = total.high.value {
            context.fill(Path(CGRect(x: x(low), y: groundY - 3, width: max(2, x(high) - x(low)), height: 3)), with: .color(Self.totalBand))
        }
        if let carry = readout.carry, let low = carry.low.value, let high = carry.high.value {
            context.fill(Path(CGRect(x: x(low), y: groundY - 5, width: max(3, x(high) - x(low)), height: 5)), with: .color(Self.carryBand))
        }
        if readout.trajectory.count > 1 {
            var path = Path()
            for (index, sample) in readout.trajectory.enumerated() {
                let point = CGPoint(x: x(sample.forward), y: y(sample.height))
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(Self.arc), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
        }
        context.fill(Path(ellipseIn: CGRect(x: left - 3, y: groundY - 3, width: 6, height: 6)), with: .color(.white))
    }
}

/// The frames the shot was measured on, combined so the ball shows once per frame, with the
/// tracked centres marked. A picture of the measurement, not a replay.
struct LaunchStrobeView: View {
    @Environment(AppPreferences.self) private var prefs
    let image: CGImage
    let observations: [LaunchObservation]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Image(decorative: image, scale: 1).resizable().frame(width: geometry.size.width, height: geometry.size.height)
                ForEach(Array(observations.enumerated()), id: \.offset) { _, observation in
                    Circle().stroke(SLTheme.sage, lineWidth: 1.5).frame(width: 10, height: 10)
                        .position(x: observation.center.x / Double(max(image.width, 1)) * geometry.size.width,
                                  y: observation.center.y / Double(max(image.height, 1)) * geometry.size.height)
                }
            }
        }
        .aspectRatio(CGFloat(image.width) / CGFloat(max(image.height, 1)), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: SLTheme.cornerRadius))
        .accessibilityLabel(prefs.text("Strobe of the ball after impact"))
    }
}
