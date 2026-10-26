import AppKit
import ImageIO
import UniformTypeIdentifiers
let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: 1)
}
context.setFillColor(color(0x202823))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.setStrokeColor(color(0xB5C7A0))
context.setLineWidth(8)
context.addEllipse(in: CGRect(x: 148, y: 148, width: 728, height: 728))
context.strokePath()
context.setStrokeColor(color(0xF6F5F1))
context.setLineWidth(20)
context.setLineCap(.round)
context.move(to: CGPoint(x: 459, y: 316))
context.addLine(to: CGPoint(x: 459, y: 730))
context.strokePath()
context.setFillColor(color(0xB5C7A0))
context.move(to: CGPoint(x: 477, y: 724))
context.addLine(to: CGPoint(x: 682, y: 650))
context.addLine(to: CGPoint(x: 477, y: 569))
context.closePath()
context.fillPath()
context.setStrokeColor(color(0xB6A17C))
context.setLineWidth(10)
context.addEllipse(in: CGRect(x: 320, y: 278, width: 282, height: 72))
context.strokePath()
context.setFillColor(color(0xF6F5F1))
context.fillEllipse(in: CGRect(x: 650, y: 344, width: 38, height: 38))
let image = context.makeImage()!
let url = URL(fileURLWithPath: "SwingLab/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
assert(CGImageDestinationFinalize(destination))
