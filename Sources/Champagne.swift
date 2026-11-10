import AppKit

final class ChampagneView: FocusWaveView, CelebrationScene {
    let duration = 10.0
    private let reduceMotion: Bool
    private struct Bubble {
        let launch: CGFloat
        let lifetime: CGFloat
        let horizontal: CGFloat
        let vertical: CGFloat
        let size: CGFloat
        let tint: NSColor
    }
    private struct Mist {
        let x: CGFloat
        let y: CGFloat
        let speed: CGFloat
        let phase: CGFloat
        let size: CGFloat
    }
    private struct BottlePose {
        let anchor: CGPoint
        let tilt: CGFloat
        let scale: CGFloat
        var mouth: CGPoint {
            CGPoint(x: anchor.x - sin(tilt) * 132 * scale, y: anchor.y + cos(tilt) * 132 * scale)
        }
    }
    private let bubbles: [Bubble]
    private let mist: [Mist]
    private let fireworks: FireworkView
    private static let gold = NSColor(srgbRed: 1, green: 0.79, blue: 0.43, alpha: 1)
    private static let cream = NSColor(srgbRed: 1, green: 0.95, blue: 0.79, alpha: 1)
    private static let rose = NSColor(srgbRed: 1, green: 0.61, blue: 0.74, alpha: 1)
    private static let glass = NSGradient(colors: [
        NSColor(srgbRed: 0.075, green: 0.19, blue: 0.16, alpha: 1),
        NSColor(srgbRed: 0.31, green: 0.50, blue: 0.32, alpha: 1),
        NSColor(srgbRed: 0.09, green: 0.26, blue: 0.22, alpha: 1),
        NSColor(srgbRed: 0.05, green: 0.13, blue: 0.13, alpha: 1)
    ])!
    private static let foil = NSGradient(colors: [
        NSColor(srgbRed: 0.52, green: 0.27, blue: 0.09, alpha: 1), cream, gold,
        NSColor(srgbRed: 0.57, green: 0.32, blue: 0.11, alpha: 1)
    ])!

    init(frame: NSRect, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        let palette = [Self.cream, Self.gold, Self.rose]
        bubbles = (0..<418).map { index in
            let burst = index < 170
            let launch: CGFloat = burst ? .random(in: 0.64...1.52) : .random(in: 1.53...8.90)
            let horizontal: CGFloat = index.isMultiple(of: 5) ? .random(in: -0.36...0.07) : .random(in: 0.08...0.95)
            return Bubble(launch: launch, lifetime: .random(in: 1.0...2.2), horizontal: horizontal,
                          vertical: .random(in: 0.39...1.32), size: .random(in: 0.9...5.3),
                          tint: palette[index % palette.count])
        }
        mist = (0..<146).map { _ in
            Mist(x: .random(in: 0...1), y: .random(in: 0...1), speed: .random(in: 0.11...0.25),
                 phase: .random(in: 0...(2 * .pi)), size: .random(in: 0.8...3.6))
        }
        fireworks = FireworkView(frame: frame, reduceMotion: reduceMotion, grand: true)
        super.init(frame: frame, refocus: {})
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let opacity = CGFloat(min(1, elapsed / 0.30) * min(1, max(0, (duration - elapsed) / 0.72)))
        let time = reduceMotion ? 1.63 : CGFloat(elapsed)
        drawField(in: context, time: time, fade: opacity, nebula: true)
        let scale = max(0.45, min(1.85, min(bounds.width / 870, bounds.height / 585)))
        fireworks.drawBursts(in: context, time: Double(time), opacity: opacity)
        drawMist(in: context, time: time, scale: scale, opacity: opacity)
        let pose = bottlePose(at: time, scale: scale)
        context.saveGState()
        context.translateBy(x: pose.anchor.x, y: pose.anchor.y)
        context.rotate(by: pose.tilt)
        context.scaleBy(x: pose.scale, y: pose.scale)
        drawBottle(in: context, opacity: opacity)
        context.restoreGState()
        drawSpray(in: context, time: time, scale: scale, opacity: opacity)
        drawTitle(scale: scale * 0.88, opacity: opacity)
    }

    private func bottlePose(at time: CGFloat, scale: CGFloat) -> BottlePose {
        let rise = min(1, max(0, time / 0.70))
        let eased = 1 - pow(1 - rise, 3)
        let recoil = 0.57 * exp(-pow((time - 0.79) * 7.2, 2))
        let aftershock = max(0, time - 0.86)
        let sway = 0.32 * sin(aftershock * 7) * exp(-1.13 * aftershock) + 0.10 * sin(time * 2.25)
        let x = bounds.width * (0.19 + 0.045 * eased) + (16 * sin(time * 2.7) - 36 * recoil) * scale
        let y = bounds.height * (-0.19 + 0.35 * eased) + (12 * sin(time * 3.0) - 36 * recoil) * scale
        return BottlePose(anchor: CGPoint(x: x, y: y), tilt: 0.22 - 0.91 * eased - recoil + sway,
                          scale: scale * (0.80 + 0.20 * eased + 0.13 * recoil))
    }

    private func drawBottle(in context: CGContext, opacity: CGFloat) {
        let body = NSBezierPath()
        body.move(to: NSPoint(x: -27, y: 2))
        body.curve(to: NSPoint(x: -29, y: 12), controlPoint1: NSPoint(x: -28, y: 4), controlPoint2: NSPoint(x: -29, y: 8))
        body.line(to: NSPoint(x: -29, y: 73))
        body.curve(to: NSPoint(x: -10, y: 106), controlPoint1: NSPoint(x: -29, y: 90), controlPoint2: NSPoint(x: -12, y: 92))
        body.line(to: NSPoint(x: -9, y: 129))
        body.line(to: NSPoint(x: 9, y: 129))
        body.line(to: NSPoint(x: 10, y: 106))
        body.curve(to: NSPoint(x: 29, y: 73), controlPoint1: NSPoint(x: 12, y: 92), controlPoint2: NSPoint(x: 29, y: 90))
        body.line(to: NSPoint(x: 29, y: 12))
        body.curve(to: NSPoint(x: 27, y: 2), controlPoint1: NSPoint(x: 29, y: 8), controlPoint2: NSPoint(x: 28, y: 4))
        body.curve(to: NSPoint(x: -27, y: 2), controlPoint1: NSPoint(x: 21, y: -3), controlPoint2: NSPoint(x: -21, y: -3))
        body.close()
        context.setAlpha(opacity)
        context.setShadow(offset: .zero, blur: 21, color: Self.gold.withAlphaComponent(0.28).cgColor)
        Self.glass.draw(in: body, angle: 0)
        context.setShadow(offset: .zero, blur: 0, color: nil)
        Self.gold.withAlphaComponent(0.60).setStroke()
        body.lineWidth = 0.75
        body.stroke()
        let neck = NSBezierPath(roundedRect: NSRect(x: -10, y: 105, width: 20, height: 27), xRadius: 4, yRadius: 4)
        Self.foil.draw(in: neck, angle: 0)
        let rim = NSBezierPath(roundedRect: NSRect(x: -12, y: 127, width: 24, height: 6), xRadius: 2.5, yRadius: 2.5)
        Self.foil.draw(in: rim, angle: 0)
        let label = NSBezierPath(roundedRect: NSRect(x: -24, y: 23, width: 48, height: 45), xRadius: 5, yRadius: 5)
        Self.foil.draw(in: label, angle: -21)
        let emblem = NSBezierPath(ovalIn: NSRect(x: -8, y: 39, width: 16, height: 16))
        NSColor(srgbRed: 0.33, green: 0.15, blue: 0.09, alpha: 0.88).setStroke()
        emblem.lineWidth = 0.8
        emblem.stroke()
        let star = NSAttributedString(string: "✦", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor(srgbRed: 0.33, green: 0.15, blue: 0.09, alpha: 0.88)
        ])
        star.draw(at: NSPoint(x: -star.size().width / 2, y: 47 - star.size().height / 2))
        context.setAlpha(opacity * 0.28)
        context.setStrokeColor(Self.cream.cgColor)
        context.setLineWidth(1.4)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: -22, y: 11)); context.addLine(to: CGPoint(x: -22, y: 75))
        context.strokePath()
    }

    private func drawMist(in context: CGContext, time: CGFloat, scale: CGFloat, opacity: CGFloat) {
        let fade = min(1, max(0, (time - 0.87) / 0.95)) * opacity
        guard fade > 0 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        for (index, drop) in mist.enumerated() {
            let progress = (drop.y + time * drop.speed).truncatingRemainder(dividingBy: 1)
            let x = bounds.width * drop.x + 19 * scale * sin(time * 1.05 + drop.phase)
            let y = bounds.height * (1.03 - 1.06 * progress)
            let radius = drop.size * scale
            context.setAlpha(fade * pow(max(0, sin(.pi * progress)), 0.6) * (0.21 + drop.size * 0.12))
            context.setStrokeColor(Self.gold.cgColor)
            context.setFillColor(Self.cream.cgColor)
            let circle = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            if index.isMultiple(of: 3) {
                context.setLineWidth(0.8 * scale)
                context.strokeEllipse(in: circle)
            } else { context.fillEllipse(in: circle.insetBy(dx: radius * 0.34, dy: radius * 0.34)) }
        }
    }

    private func drawSpray(in context: CGContext, time: CGFloat, scale: CGFloat, opacity: CGFloat) {
        context.saveGState()
        defer { context.restoreGState() }
        if time >= 0.53, time < 1.9 {
            let age = max(0, time - 0.64)
            let origin = bottlePose(at: min(time, 0.64), scale: scale).mouth
            context.saveGState()
            context.translateBy(x: origin.x + age * bounds.width * 0.46, y: origin.y + 8 * scale + bounds.height * (0.84 * age - 0.28 * age * age))
            context.rotate(by: -0.59 - 7.4 * age)
            context.setAlpha(opacity * min(1, (1.9 - time) * 2.7))
            NSColor(srgbRed: 0.85, green: 0.62, blue: 0.34, alpha: 1).setFill()
            NSBezierPath(roundedRect: CGRect(x: -6 * scale, y: -4 * scale, width: 12 * scale, height: 10 * scale),
                         xRadius: 2 * scale, yRadius: 2 * scale).fill()
            context.restoreGState()
        }
        context.setLineCap(.round)
        for bubble in bubbles {
            let age = time - bubble.launch
            guard age >= 0, age < bubble.lifetime else { continue }
            let origin = bottlePose(at: bubble.launch, scale: scale).mouth
            func flightPoint(at flight: CGFloat) -> CGPoint {
                let dx = bounds.width * bubble.horizontal * flight + 12 * scale * sin(flight * 4 + bubble.vertical * 3)
                let dy = bounds.height * (bubble.vertical * flight - 0.47 * flight * flight)
                return CGPoint(x: origin.x + dx, y: origin.y + dy)
            }
            let point = flightPoint(at: age)
            guard bounds.insetBy(dx: -20, dy: -20).contains(point) else { continue }
            let radius = bubble.size * scale * (0.75 + age * 0.35)
            let alpha = opacity * min(1, 0.52 + age * 4) * pow(1 - age / bubble.lifetime, 0.69)
            context.setAlpha(alpha)
            context.setStrokeColor(bubble.tint.cgColor)
            context.setFillColor(bubble.tint.cgColor)
            let circle = CGRect(x: point.x - radius, y: point.y - radius, width: 2 * radius, height: 2 * radius)
            if bubble.size > 3.15 {
                context.setLineWidth(0.8 * scale)
                context.strokeEllipse(in: circle)
                context.fillEllipse(in: CGRect(x: point.x - radius * 0.46, y: point.y + radius * 0.28, width: radius * 0.55, height: radius * 0.43))
            } else {
                context.setAlpha(alpha * 0.45)
                context.setLineWidth(radius * 0.60)
                context.move(to: flightPoint(at: max(0, age - 0.045)))
                context.addLine(to: point)
                context.strokePath()
                context.setAlpha(alpha)
                context.fillEllipse(in: circle)
            }
        }
    }

    private func drawTitle(scale: CGFloat, opacity: CGFloat) {
        let progress = min(1, max(0, (elapsed - 0.20) / 0.74))
        let size = 69 * scale * (reduceMotion ? 1 : 1 - 0.26 * exp(-4.3 * progress) * cos(8.4 * progress))
        let fade = opacity * CGFloat(min(1, progress * 3.6))
        let shadow = NSShadow()
        shadow.shadowColor = Self.rose.withAlphaComponent(fade * 0.78)
        shadow.shadowBlurRadius = 23 * scale
        shadow.shadowOffset = NSSize(width: 0, height: -2 * scale)
        let title = NSAttributedString(string: "超级完成！！！", attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .black),
            .foregroundColor: Self.cream.withAlphaComponent(fade),
            .shadow: shadow
        ])
        title.draw(at: NSPoint(x: bounds.midX - title.size().width / 2, y: bounds.midY - title.size().height / 2))
    }
}
