import SwiftUI
import SwingLabCore

/// The six launch-monitor tiles: carry, ball speed, back spin / total, club speed, launch angle.
/// Ball speed and launch angle are measured; every other tile wears the badge that says what it
/// is instead (simulated, estimated, or a published bracket), so none reads as a measurement.
struct LaunchReadoutGrid: View {
    @Environment(AppPreferences.self) private var prefs
    let readout: LaunchReadout
    /// Three narrow columns over the camera preview instead of two on a screen.
    var compact = false

    var body: some View {
        let font: Font = compact ? .headline : .title3.weight(.medium)
        let columns = Array(repeating: GridItem(.flexible(), spacing: compact ? 8 : 16, alignment: .topLeading), count: compact ? 3 : 2)
        LazyVGrid(columns: columns, alignment: .leading, spacing: compact ? 8 : 16) {
            ForEach(tiles, id: \.self) { tile in
                tileView(tile, font: font).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private enum Tile: Hashable { case carry, ballSpeed, spin, total, clubSpeed, launchAngle }

    /// Compact: the launch-monitor order (carry, ball speed, spin / total, club speed, launch).
    /// Two columns pair each simulated tile with its measured neighbour instead.
    private var tiles: [Tile] {
        compact ? [.carry, .ballSpeed, .spin, .total, .clubSpeed, .launchAngle]
                : [.carry, .total, .ballSpeed, .launchAngle, .clubSpeed, .spin]
    }

    @ViewBuilder private func tileView(_ tile: Tile, font: Font) -> some View {
        switch tile {
        case .carry: SLRangeReadout(range: readout.carry, label: prefs.text("Carry"), valueFont: font, alignment: .leading)
        case .total: SLRangeReadout(range: readout.total, label: prefs.text("Total"), valueFont: font, alignment: .leading)
        case .ballSpeed:
            SLMetricReadout(metric: readout.ballSpeed, label: prefs.text("Ball speed"), fractionDigits: 1, valueFont: font, alignment: .leading)
        case .launchAngle:
            SLMetricReadout(metric: readout.launchAngle, label: prefs.text("Launch angle"), fractionDigits: 1, valueFont: font, alignment: .leading)
        case .clubSpeed: SLRangeReadout(range: readout.clubSpeed, label: prefs.text("Club speed"), valueFont: font, alignment: .leading)
        case .spin: SLRangeReadout(range: readout.spin, label: prefs.text("Back spin"), valueFont: font, alignment: .leading)
        }
    }
}

/// One line that says what the non-measured tiles are, placed under every readout grid.
struct LaunchReadoutFootnote: View {
    @Environment(AppPreferences.self) private var prefs
    let readout: LaunchReadout
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let guess = readout.clubGuess {
                Text(prefs.format("launch.clubGuess", prefs.text(guess.club.localizationKey)))
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            Text(prefs.text("Carry and total are simulated for a fairway across the published spin bracket for the club; club speed is the ball speed divided by published smash factors; back spin is that published bracket. None of them is measured."))
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
