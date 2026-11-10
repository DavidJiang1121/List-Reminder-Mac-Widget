import AppKit

private final class FocusBackdropPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor final class QuickAddFocus {
    // Above the desktop and menu bar, below native date-picker popups.
    private static let backdropLevel = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 2)
    static let editorLevel = NSWindow.Level(rawValue: backdropLevel.rawValue + 1)
    private var panel: FocusBackdropPanel?
    private var timer: Timer?

    func show(on screen: NSScreen, refocus: @escaping () -> Void) {
        dismiss(animated: false)
        let reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let field = FocusWaveView(frame: NSRect(origin: .zero, size: screen.frame.size), refocus: refocus)
        let overlay = FocusBackdropPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        overlay.contentView = field
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = false
        overlay.hidesOnDeactivate = false
        overlay.isReleasedWhenClosed = false
        overlay.isExcludedFromWindowsMenu = true
        overlay.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient, .ignoresCycle]
        overlay.level = Self.backdropLevel
        overlay.setFrame(screen.frame, display: true)
        panel = overlay
        if reducesMotion { field.elapsed = 0.36 }
        overlay.orderFrontRegardless()

        guard !reducesMotion else { return }
        let began = ProcessInfo.processInfo.systemUptime
        let animation = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak field] _ in
            MainActor.assumeIsolated {
                field?.elapsed = ProcessInfo.processInfo.systemUptime - began
            }
        }
        RunLoop.main.add(animation, forMode: .common)
        timer = animation
    }

    func move(to screen: NSScreen) {
        if let panel, panel.frame != screen.frame { panel.setFrame(screen.frame, display: true) }
    }

    func dismiss(animated: Bool = true) {
        timer?.invalidate()
        timer = nil
        guard let overlay = panel else { return }
        panel = nil
        overlay.ignoresMouseEvents = true
        if !animated || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            overlay.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            overlay.animator().alphaValue = 0
        }, completionHandler: { overlay.orderOut(nil) })
    }
}

class FocusWaveView: NSView {
    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let brightness: CGFloat
        let phase: CGFloat
        let color: CGColor
    }

    private let refocus: () -> Void
    private let stars: [Star]
    private let glow: CGGradient?
    private static let nebulaGlows: [CGGradient] = [
        NSColor(srgbRed: 0.46, green: 0.19, blue: 0.67, alpha: 0.46),
        NSColor(srgbRed: 0.19, green: 0.35, blue: 0.64, alpha: 0.38),
        NSColor(srgbRed: 0.58, green: 0.24, blue: 0.45, alpha: 0.24)
    ].compactMap { tint in
        CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                   colors: [tint.cgColor, tint.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])
    }
    var elapsed: Double = 0 { didSet { needsDisplay = true } }

    init(frame: NSRect, refocus: @escaping () -> Void) {
        self.refocus = refocus
        let shades = [
            NSColor(srgbRed: 0.73, green: 0.82, blue: 1.00, alpha: 1).cgColor,
            NSColor(srgbRed: 0.89, green: 0.83, blue: 1.00, alpha: 1).cgColor,
            NSColor(srgbRed: 0.91, green: 0.95, blue: 1.00, alpha: 1).cgColor
        ]
        stars = (0..<230).map { index in
            Star(x: .random(in: -0.52...0.52), y: .random(in: -0.52...0.52),
                 size: .random(in: 0.45...1.55), brightness: .random(in: 0.18...0.80),
                 phase: .random(in: 0...(2 * .pi)), color: shades[index % shades.count])
        }
        let light = NSColor(srgbRed: 0.26, green: 0.31, blue: 0.69, alpha: 0.31).cgColor
        let edge = NSColor(srgbRed: 0.10, green: 0.10, blue: 0.33, alpha: 0).cgColor
        glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [light, edge] as CFArray, locations: [0, 1])
        super.init(frame: frame)
        wantsLayer = true
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { refocus() }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        drawField(in: context, time: CGFloat(elapsed), fade: min(1, CGFloat(elapsed) / 0.28))
    }

    func drawField(in context: CGContext, time: CGFloat, fade: CGFloat, nebula: Bool = false) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let depth = max(1, min(bounds.width, bounds.height))
        context.saveGState()
        defer { context.restoreGState() }
        context.clear(bounds)
        context.setFillColor(NSColor(srgbRed: 0.032, green: 0.043, blue: 0.095, alpha: (nebula ? 0.89 : 0.77) * fade).cgColor)
        context.fill(bounds)
        if let glow {
            context.setAlpha(fade)
            context.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: depth * 0.69, options: [])
        }
        if nebula {
            for (index, gradient) in Self.nebulaGlows.enumerated() {
                let offset = CGFloat(index)
                let x = bounds.width * (0.23 + 0.25 * offset + 0.03 * sin(time * 0.38 + offset))
                let y = bounds.height * (0.68 - 0.16 * offset + 0.04 * cos(time * 0.42 + offset))
                context.saveGState()
                context.translateBy(x: x, y: y)
                context.rotate(by: -0.30)
                context.scaleBy(x: 1.65, y: 0.72)
                context.setAlpha(fade)
                context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0,
                                           endCenter: .zero, endRadius: depth * 0.55, options: [])
                context.restoreGState()
            }
        }
        drawWaves(in: context, around: center, depth: depth, time: time, fade: fade)
        context.setLineCap(.round)
        for (index, star) in stars.enumerated() {
            let x = star.x * bounds.width, y = star.y * bounds.height
            let distance = hypot(x, y)
            let distortion = 1 + 0.035 * sin(distance * 0.025 - time * 1.45) * exp(-distance / depth)
            let spin = 0.025 * sin(distance * 0.008 - time * 0.31)
            let dx = (cos(spin) * x - sin(spin) * y) * distortion
            let dy = (sin(spin) * x + cos(spin) * y) * distortion
            let point = CGPoint(x: center.x + dx, y: center.y + dy)
            let twinkle = 0.78 + 0.22 * sin(time * 0.78 + star.phase)
            let alpha = fade * star.brightness * twinkle
            if index % 5 == 0 {
                let tail = 2.2 + 3 * max(0, sin(distance * 0.024 - time * 1.45))
                let length = max(1, hypot(dx, dy))
                context.setAlpha(alpha * 0.48)
                context.setStrokeColor(star.color)
                context.setLineWidth(star.size * 0.82)
                context.move(to: CGPoint(x: point.x - dx / length * tail, y: point.y - dy / length * tail))
                context.addLine(to: point)
                context.strokePath()
            }
            context.setAlpha(alpha)
            context.setFillColor(star.color)
            context.fillEllipse(in: CGRect(x: point.x - star.size, y: point.y - star.size, width: 2 * star.size, height: 2 * star.size))
        }
    }

    private func drawWaves(in context: CGContext, around center: CGPoint, depth: CGFloat, time: CGFloat, fade: CGFloat) {
        let base = depth * 0.16
        let reach = hypot(bounds.width, bounds.height) * 0.62
        let color = NSColor(srgbRed: 0.60, green: 0.68, blue: 1.00, alpha: 1).cgColor
        for wave in 0..<4 {
            let phase = (time * 0.145 + CGFloat(wave) / 4).truncatingRemainder(dividingBy: 1)
            let intensity = pow(max(0, sin(.pi * phase)), 1.45) * fade
            let radius = base + (reach - base) * phase
            for band in 0..<2 {
                let trace = CGMutablePath()
                for step in 0...112 {
                    let angle = CGFloat(step) * 2 * .pi / 112
                    let drift = 1 + 0.035 * sin(3 * angle - time * 0.66) + 0.024 * sin(5 * angle + time * 0.48)
                    let r = (radius + CGFloat(band) * 7) * drift
                    let point = CGPoint(x: center.x + cos(angle) * r * 1.08, y: center.y + sin(angle) * r * 0.90)
                    if step == 0 { trace.move(to: point) } else { trace.addLine(to: point) }
                }
                trace.closeSubpath()
                context.setAlpha(intensity * (band == 0 ? 0.24 : 0.08))
                context.setStrokeColor(color)
                context.setLineWidth(band == 0 ? 1.15 : 2.8)
                context.addPath(trace)
                context.strokePath()
            }
        }
    }
}
