// Renders the 1024x1024 App Store icon. Run: swift scripts/render-icon.swift <out.png>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size: CGFloat = 1024
let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon1024.png")
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Flip so y grows downward like a design tool.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: cs,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, a,
        ])!
}
func gradient(_ a: CGColor, _ b: CGColor) -> CGGradient {
    CGGradient(colorsSpace: cs, colors: [a, b] as CFArray, locations: [0, 1])!
}

// Background: indigo → violet diagonal, with a soft highlight top-left.
ctx.drawLinearGradient(
    gradient(rgb(0x3B2FD6), rgb(0x7B3AE8)), start: .zero, end: CGPoint(x: size, y: size), options: [])
ctx.drawRadialGradient(
    gradient(rgb(0xFFFFFF, 0.18), rgb(0xFFFFFF, 0)), startCenter: CGPoint(x: 200, y: 160), startRadius: 0,
    endCenter: CGPoint(x: 200, y: 160), endRadius: 900, options: [])

// Speech bubble with a tail at the bottom-left. Bubble and tail are filled separately
// inside one transparency layer so the shadow wraps their union and no seam shows.
let bubble = CGRect(x: 168, y: 232, width: 688, height: 500)
let tail = CGMutablePath()
tail.move(to: CGPoint(x: bubble.minX + 110, y: bubble.maxY - 40))
tail.addQuadCurve(
    to: CGPoint(x: bubble.minX + 58, y: bubble.maxY + 112),
    control: CGPoint(x: bubble.minX + 100, y: bubble.maxY + 60))
tail.addQuadCurve(
    to: CGPoint(x: bubble.minX + 330, y: bubble.maxY - 40),
    control: CGPoint(x: bubble.minX + 210, y: bubble.maxY + 40))
tail.closeSubpath()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: rgb(0x1B1060, 0.35))
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
ctx.setFillColor(rgb(0xFFFFFF))
ctx.addPath(CGPath(roundedRect: bubble, cornerWidth: 120, cornerHeight: 120, transform: nil))
ctx.fillPath()
ctx.addPath(tail)
ctx.fillPath()
ctx.endTransparencyLayer()
ctx.restoreGState()

// Text lines inside the bubble, tinted with the background gradient.
let lineHeight: CGFloat = 52
let lines: [(x: CGFloat, y: CGFloat, w: CGFloat)] = [(292, 342, 440), (292, 456, 340), (292, 570, 220)]
for line in lines {
    let r = CGRect(x: line.x, y: line.y, width: line.w, height: lineHeight)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: lineHeight / 2, cornerHeight: lineHeight / 2, transform: nil))
    ctx.clip()
    ctx.drawLinearGradient(
        gradient(rgb(0x4B3BE0), rgb(0x8A4BF0)), start: CGPoint(x: r.minX, y: r.minY),
        end: CGPoint(x: r.maxX, y: r.maxY), options: [])
    ctx.restoreGState()
}

// Four-point sparkle.
func sparkle(center c: CGPoint, radius R: CGFloat, pinch: CGFloat = 0.22) -> CGPath {
    let p = CGMutablePath()
    let r = R * pinch
    let tips = (0..<4).map { i -> CGPoint in
        let a = CGFloat(i) * .pi / 2 - .pi / 2
        return CGPoint(x: c.x + R * cos(a), y: c.y + R * sin(a))
    }
    let dips = (0..<4).map { i -> CGPoint in
        let a = CGFloat(i) * .pi / 2 - .pi / 4
        return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
    }
    p.move(to: tips[0])
    for i in 0..<4 {
        p.addQuadCurve(to: tips[(i + 1) % 4], control: dips[i])
    }
    p.closeSubpath()
    return p
}
func drawSparkle(center: CGPoint, radius: CGFloat) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 24, color: rgb(0xFFB020, 0.55))
    ctx.addPath(sparkle(center: center, radius: radius))
    ctx.clip()
    ctx.drawLinearGradient(
        gradient(rgb(0xFFE27A), rgb(0xFF9F1C)), start: CGPoint(x: center.x - radius, y: center.y - radius),
        end: CGPoint(x: center.x + radius, y: center.y + radius), options: [])
    ctx.restoreGState()
}
drawSparkle(center: CGPoint(x: 802, y: 238), radius: 150)
drawSparkle(center: CGPoint(x: 640, y: 168), radius: 52)
drawSparkle(center: CGPoint(x: 918, y: 428), radius: 46)

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("write failed") }
print("wrote \(out.path)")
