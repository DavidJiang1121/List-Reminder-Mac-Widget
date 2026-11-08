import AppKit

func path(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius) }
let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for (pixels, name) in [(16,"icon_16x16.png"),(32,"icon_16x16@2x.png"),(32,"icon_32x32.png"),(64,"icon_32x32@2x.png"),(128,"icon_128x128.png"),(256,"icon_128x128@2x.png"),(256,"icon_256x256.png"),(512,"icon_256x256@2x.png"),(512,"icon_512x512.png"),(1024,"icon_512x512@2x.png")] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let transform = NSAffineTransform(); transform.scale(by: CGFloat(pixels) / 1024); transform.concat()
    let base = path(NSRect(x: 60, y: 60, width: 904, height: 904), 204)
    NSShadow().set()
    NSGradient(starting: NSColor(srgbRed: 0.96, green: 0.97, blue: 0.97, alpha: 1), ending: NSColor(srgbRed: 0.78, green: 0.81, blue: 0.81, alpha: 1))!.draw(in: base, angle: -65)
    NSColor.white.withAlphaComponent(0.7).setStroke(); base.lineWidth = 3; base.stroke()
    let card = path(NSRect(x: 216, y: 214, width: 592, height: 620), 105)
    let shadow = NSShadow(); shadow.shadowColor = NSColor(srgbRed: 0.35, green: 0.3, blue: 0.2, alpha: 0.18); shadow.shadowBlurRadius = 35; shadow.shadowOffset = NSSize(width: 0, height: -16); shadow.set()
    NSColor.white.withAlphaComponent(0.60).setFill(); card.fill(); NSShadow().set()
    NSColor.white.withAlphaComponent(0.95).setStroke(); card.lineWidth = 4; card.stroke()
    for y: CGFloat in [653, 501, 349] {
        let circle = NSBezierPath(ovalIn: NSRect(x: 282, y: y - 18, width: 48, height: 48))
        NSColor(srgbRed: 0.34, green: 0.38, blue: 0.37, alpha: 0.75).setStroke(); circle.lineWidth = 5; circle.stroke()
        let line = path(NSRect(x: 378, y: y - 1, width: y == 349 ? 235 : 305, height: 15), 7)
        NSColor(srgbRed: 0.29, green: 0.36, blue: 0.32, alpha: y == 653 ? 0.35 : 0.65).setFill(); line.fill()
    }
    NSColor(srgbRed: 0.25, green: 0.29, blue: 0.28, alpha: 1).setStroke()
    let check = NSBezierPath(); check.move(to: NSPoint(x: 288, y: 662)); check.line(to: NSPoint(x: 304, y: 645)); check.line(to: NSPoint(x: 341, y: 689)); check.lineWidth = 10; check.lineCapStyle = .round; check.lineJoinStyle = .round; check.stroke()
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(name))
}
