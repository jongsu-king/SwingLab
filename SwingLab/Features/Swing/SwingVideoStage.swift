import SwiftUI
import AVFoundation
import UIKit

struct SwingVideoStage: View {
    var player: AVPlayer
    var report: PoseAnalysisReport?
    var time: Double
    var aspectRatio: Double
    var showSkeleton: Bool
    var showWristPath: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = fittedSize(geometry.size)
            ZStack {
                PlayerSurface(player: player)
                Canvas { context, canvasSize in
                    guard let report else { return }
                    let origin = CGPoint(x: (canvasSize.width - size.width) / 2, y: (canvasSize.height - size.height) / 2)
                    func point(_ joint: PoseJoint) -> CGPoint {
                        CGPoint(x: origin.x + joint.x * size.width, y: origin.y + (1 - joint.y) * size.height)
                    }
                    if showWristPath {
                        for name in ["leftWrist", "rightWrist"] {
                            var path = Path()
                            var previousTime: Double?
                            for frame in report.frames where frame.time <= time && frame.time >= time - 1.5 {
                                guard let wrist = frame.joint(name) else { previousTime = nil; continue }
                                if let previousTime, frame.time - previousTime <= 0.12 { path.addLine(to: point(wrist)) }
                                else { path.move(to: point(wrist)) }
                                previousTime = frame.time
                            }
                            context.stroke(path, with: .color(name == "leftWrist" ? .yellow : .cyan), lineWidth: 2)
                        }
                    }
                    guard showSkeleton, let frame = report.frames.last(where: { $0.time <= time + 0.015 }),
                          abs(frame.time - time) < 0.09 else { return }
                    var skeleton = Path()
                    for (start, end) in Self.bones {
                        if let a = frame.joint(start), let b = frame.joint(end) {
                            skeleton.move(to: point(a)); skeleton.addLine(to: point(b))
                        }
                    }
                    context.stroke(skeleton, with: .color(.white.opacity(0.9)), lineWidth: 2)
                    for joint in frame.joints {
                        let position = point(joint)
                        context.fill(Path(ellipseIn: CGRect(x: position.x - 3, y: position.y - 3, width: 6, height: 6)),
                                     with: .color(.yellow))
                    }
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
    private func fittedSize(_ available: CGSize) -> CGSize {
        if available.width / available.height > aspectRatio {
            return CGSize(width: available.height * aspectRatio, height: available.height)
        }
        return CGSize(width: available.width, height: available.width / aspectRatio)
    }
    private static let bones = [
        ("nose", "neck"), ("neck", "leftShoulder"), ("neck", "rightShoulder"),
        ("leftShoulder", "leftElbow"), ("leftElbow", "leftWrist"),
        ("rightShoulder", "rightElbow"), ("rightElbow", "rightWrist"),
        ("leftShoulder", "leftHip"), ("rightShoulder", "rightHip"), ("leftHip", "rightHip"),
        ("leftHip", "leftKnee"), ("leftKnee", "leftAnkle"), ("rightHip", "rightKnee"), ("rightKnee", "rightAnkle")
    ]
}

private struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }
    func updateUIView(_ view: PlayerUIView, context: Context) { view.playerLayer.player = player }
}

private final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
