import AppKit

private final class CelebrationPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

protocol CelebrationScene where Self: NSView {
    var duration: Double { get }
    var elapsed: Double { get set }
}

@MainActor final class CompletionCelebration {
    private var panel: CelebrationPanel?
    private var timer: Timer?

    func show(_ kind: ReminderStore.Completion, on screen: NSScreen) {
        dismiss()
        let frame = NSRect(origin: .zero, size: screen.frame.size)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let view: NSView & CelebrationScene
        if kind == .allTasks { view = ChampagneView(frame: frame, reduceMotion: reduceMotion) }
        else { view = FireworkView(frame: frame, reduceMotion: reduceMotion) }
        let overlay = CelebrationPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        overlay.title = kind == .allTasks ? "超级完成！！！" : "完成了！！！"
        overlay.contentView = view
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = false
        overlay.hidesOnDeactivate = false
        overlay.isReleasedWhenClosed = false
        overlay.isExcludedFromWindowsMenu = true
        overlay.ignoresMouseEvents = true
        overlay.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
        overlay.level = .screenSaver
        overlay.setFrame(screen.frame, display: true)
        panel = overlay
        overlay.orderFrontRegardless()

        let began = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / (kind == .allTasks ? 30.0 : 60.0), repeats: true) { [weak self, weak view] _ in
            MainActor.assumeIsolated {
                guard let self, let view else { return }
                let elapsed = ProcessInfo.processInfo.systemUptime - began
                if elapsed >= view.duration { self.dismiss() }
                else { view.elapsed = elapsed }
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func dismiss() {
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

final class FireworkView: NSView, CelebrationScene {
    private struct Spark {
        let direction: CGFloat
        let speed: CGFloat
        let size: CGFloat
        let lifetime: Double
        let color: CGColor
    }
    private struct Burst {
        let x: CGFloat
        let y: CGFloat
        let start: Double
        let scale: CGFloat
        let sparks: [Spark]
    }

    let reduceMotion: Bool
    var duration: Double { reduceMotion ? 1.7 : 3.05 }
    var elapsed = 0.0 { didSet { needsDisplay = true } }
    private let bursts: [Burst]

    init(frame: NSRect, reduceMotion: Bool, grand: Bool = false) {
        self.reduceMotion = reduceMotion
        let palettes: [[NSColor]] = [
            [.init(srgbRed: 1, green: 0.75, blue: 0.32, alpha: 1), .init(srgbRed: 1, green: 0.89, blue: 0.56, alpha: 1), .white],
            [.init(srgbRed: 1, green: 0.45, blue: 0.53, alpha: 1), .init(srgbRed: 1, green: 0.67, blue: 0.75, alpha: 1), .white],
            [.init(srgbRed: 0.46, green: 0.93, blue: 0.88, alpha: 1), .init(srgbRed: 0.67, green: 1, blue: 0.96, alpha: 1), .white],
            [.init(srgbRed: 0.75, green: 0.62, blue: 1, alpha: 1), .init(srgbRed: 0.9, green: 0.77, blue: 1, alpha: 1), .white]
        ]
        let standard: [(CGFloat, CGFloat, Double, CGFloat)] = [
            (0.17, 0.74, 0.29, 1.0), (0.81, 0.76, 0.38, 1.06), (0.47, 0.86, 0.56, 0.86),
            (0.10, 0.43, 0.73, 0.76), (0.91, 0.39, 0.82, 0.82), (0.28, 0.24, 0.96, 0.95),
            (0.71, 0.25, 1.12, 1.02), (0.27, 0.64, 1.34, 0.70), (0.74, 0.63, 1.43, 0.76)
        ]
        let positions: [(CGFloat, CGFloat, Double, CGFloat)] = grand ? [
            (0.18, 0.77, 0.72, 1.10), (0.81, 0.73, 0.96, 1.23), (0.50, 0.90, 1.13, 0.90),
            (0.09, 0.40, 1.36, 0.80), (0.94, 0.39, 1.56, 0.92), (0.73, 0.24, 2.12, 1.02),
            (0.32, 0.72, 2.72, 1.10), (0.89, 0.89, 3.15, 1.05), (0.14, 0.60, 3.81, 1.07),
            (0.65, 0.84, 4.32, 1.08), (0.83, 0.32, 5.02, 1.18), (0.23, 0.83, 5.68, 1.18),
            (0.10, 0.35, 6.32, 0.93), (0.62, 0.85, 7.10, 1.08), (0.86, 0.66, 7.23, 1.20),
            (0.27, 0.64, 7.45, 1.14), (0.68, 0.24, 7.89, 1.02), (0.48, 0.88, 8.25, 1.00)
        ] : standard
        bursts = positions.enumerated().map { index, position in
            let colors = palettes[index % palettes.count]
            let count = grand ? 62 : 46
            let sparks = (0..<count).map { index in
                Spark(direction: (CGFloat(index) / CGFloat(count)) * 2 * .pi + .random(in: -0.065...0.065),
                      speed: .random(in: 0.38...1.0), size: .random(in: 1.1...2.6),
                      lifetime: .random(in: 0.95...1.48), color: colors[index % colors.count].cgColor)
            }
            return Burst(x: position.0, y: position.1, start: position.2, scale: position.3, sparks: sparks)
        }
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.clear(bounds)
        let enter = min(1, elapsed / 0.20)
        let exit = min(1, max(0, (duration - elapsed) / 0.48))
        let opacity = CGFloat(enter * exit)
        context.setFillColor(NSColor(srgbRed: 0.025, green: 0.018, blue: 0.07, alpha: 0.42 * opacity).cgColor)
        context.fill(bounds)
        drawBursts(in: context, time: elapsed, opacity: opacity, staticBurst: reduceMotion)
        drawTitle(opacity: opacity)
    }

    func drawBursts(in context: CGContext, time: Double, opacity: CGFloat, staticBurst: Bool = false) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setLineCap(.round)
        let radius = min(bounds.width, bounds.height) * 0.245
        for burst in bursts {
            let age = staticBurst ? 0.46 : time - burst.start
            let center = CGPoint(x: bounds.width * burst.x, y: bounds.height * burst.y)
            if age < 0 {
                let progress = max(0, 1 + age / 0.30)
                if progress > 0 {
                    let tip = CGPoint(x: center.x, y: center.y * CGFloat(progress))
                    context.setAlpha(opacity * CGFloat(progress))
                    context.setStrokeColor(NSColor.systemYellow.cgColor)
                    context.setLineWidth(1.8)
                    context.move(to: CGPoint(x: tip.x, y: tip.y - 19))
                    context.addLine(to: tip)
                    context.strokePath()
                }
                continue
            }
            let burstRadius = radius * burst.scale
            for spark in burst.sparks where age < spark.lifetime {
                let fade = CGFloat(pow(1 - age / spark.lifetime, 0.9)) * opacity
                func point(at time: Double) -> CGPoint {
                    let spread = burstRadius * spark.speed * CGFloat(1 - exp(-2.6 * time))
                    return CGPoint(x: center.x + cos(spark.direction) * spread,
                                   y: center.y + sin(spark.direction) * spread - burstRadius * 0.22 * CGFloat(time * time))
                }
                let head = point(at: age)
                context.setAlpha(fade * 0.62)
                context.setStrokeColor(spark.color)
                context.setLineWidth(spark.size * 0.78)
                context.move(to: point(at: max(0, age - 0.09)))
                context.addLine(to: head)
                context.strokePath()
                context.setAlpha(fade)
                context.setFillColor(spark.color)
                context.fillEllipse(in: CGRect(x: head.x - spark.size, y: head.y - spark.size, width: spark.size * 2, height: spark.size * 2))
            }
        }
    }

    private func drawTitle(opacity: CGFloat) {
        let phase = min(1, max(0, (elapsed - 0.12) / 0.5))
        let pop = reduceMotion ? 1 : 1 - 0.32 * exp(-5 * phase) * cos(8 * phase)
        let fontSize = min(110, max(36, min(bounds.width * 0.09, bounds.height * 0.15))) * CGFloat(pop)
        let visible = opacity * CGFloat(min(1, phase * 4))
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(srgbRed: 0.10, green: 0.03, blue: 0.15, alpha: visible * 0.9)
        shadow.shadowBlurRadius = 22
        shadow.shadowOffset = NSSize(width: 0, height: -3)
        let title = NSAttributedString(string: "完成了！！！", attributes: [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .black),
            .foregroundColor: NSColor(srgbRed: 1, green: 0.96, blue: 0.82, alpha: visible),
            .shadow: shadow
        ])
        let size = title.size()
        title.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2))
    }
}
