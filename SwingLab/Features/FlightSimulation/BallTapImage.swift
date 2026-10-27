import SwiftUI

/// A still frame the user taps to mark the ball. `point` is normalized, origin top-left.
struct BallTapImage: View {
    let image: CGImage
    @Binding var point: CGPoint?
    let accessibilityLabel: String

    var body: some View {
        GeometryReader { geometry in
            let size = fittedSize(for: geometry.size)
            ZStack(alignment: .topLeading) {
                Image(decorative: image, scale: 1).resizable().frame(width: size.width, height: size.height)
                if let point {
                    Circle().stroke(SLTheme.sage, lineWidth: 2).frame(width: 28, height: 28)
                        .position(x: point.x * size.width, y: point.y * size.height)
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .onTapGesture { location in
                point = CGPoint(x: min(1, max(0, location.x / size.width)), y: min(1, max(0, location.y / size.height)))
            }
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private func fittedSize(for available: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0 else { return available }
        let aspect = Double(image.width) / Double(image.height)
        let height = min(available.height, available.width / aspect)
        return CGSize(width: height * aspect, height: height)
    }
}
