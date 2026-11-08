import AppKit
import Combine

final class DesktopPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

class ClickView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var needsPanelToBecomeKey: Bool { false }
}

final class WidgetRows: NSView {
    override var isFlipped: Bool { true }
}

extension ReminderCountdown {
    var color: NSColor {
        NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            switch tone {
            case .overdue:
                return dark ? NSColor(srgbRed: 1, green: 0.66, blue: 0.69, alpha: 1)
                    : NSColor(srgbRed: 0.65, green: 0.12, blue: 0.21, alpha: 1)
            case .soon:
                return dark ? NSColor(srgbRed: 1, green: 0.77, blue: 0.52, alpha: 1)
                    : NSColor(srgbRed: 0.57, green: 0.27, blue: 0.07, alpha: 1)
            case .planned:
                return dark ? NSColor(srgbRed: 0.61, green: 0.90, blue: 0.72, alpha: 1)
                    : NSColor(srgbRed: 0.12, green: 0.37, blue: 0.25, alpha: 1)
            }
        }
    }
}

final class WidgetHeader: NSView {
    var isPositionLocked = false
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { !isPositionLocked }
    override func mouseDown(with event: NSEvent) {
        guard !isPositionLocked else { return }
        window?.performDrag(with: event)
    }
    override func draw(_ dirtyRect: NSRect) {
        let title = "List Reminder" as NSString
        title.draw(at: NSPoint(x: 24, y: 25), withAttributes: [.font: NSFont.systemFont(ofSize: 18, weight: .semibold), .foregroundColor: NSColor.labelColor])
    }
}

final class WidgetRow: ClickView {
    let item: Reminder
    let countdown: ReminderCountdown?
    let action: () -> Void
    var hovered = false
    var tracking: NSTrackingArea?
    init(item: Reminder, day: ReminderDay = ReminderDay(), action: @escaping () -> Void) {
        self.item = item; self.action = action
        countdown = item.countdown(on: day)
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(countdown.map { "\(item.title)，\($0.spokenLabel)" } ?? item.title)
        setAccessibilityHelp("双击完成待办；也可使用辅助功能操作。")
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    override func accessibilityPerformPress() -> Bool { action(); return true }
    override func mouseDown(with event: NSEvent) { if event.clickCount == 2 { action() } }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(tracking!)
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        if hovered {
            NSColor.labelColor.withAlphaComponent(0.055).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 10, dy: 2), xRadius: 10, yRadius: 10).fill()
        }
        NSColor.labelColor.withAlphaComponent(0.3).setStroke()
        let circle = NSBezierPath(ovalIn: NSRect(x: 24, y: (bounds.height - 17) / 2, width: 17, height: 17))
        circle.lineWidth = 1.4; circle.stroke()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        var titleRight = bounds.width - 24
        if let countdown {
            let text = NSAttributedString(string: countdown.label, attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold), .foregroundColor: countdown.color])
            let size = text.size()
            let badge = NSRect(x: titleRight - size.width - 14, y: (bounds.height - 22) / 2, width: size.width + 14, height: 22)
            countdown.color.withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect: badge, xRadius: 11, yRadius: 11).fill()
            text.draw(at: NSPoint(x: badge.minX + 7, y: (bounds.height - size.height) / 2))
            titleRight = badge.minX - 9
        }
        let title = NSAttributedString(string: item.title, attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph])
        title.draw(with: NSRect(x: 53, y: (bounds.height - 20) / 2, width: max(0, titleRight - 53), height: 20), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        NSColor.separatorColor.withAlphaComponent(0.32).setFill()
        NSRect(x: 53, y: bounds.height - 1, width: bounds.width - 78, height: 0.5).fill()
    }
}

final class WidgetAddButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var needsPanelToBecomeKey: Bool { false }
    override var mouseDownCanMoveWindow: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        if cell?.isHighlighted == true {
            NSColor.labelColor.withAlphaComponent(0.12).setFill()
            NSBezierPath(ovalIn: bounds.insetBy(dx: 4, dy: 4)).fill()
        }
        super.draw(dirtyRect)
    }
}

final class ResizeGrip: ClickView {
    var changed: (() -> Void)?
    var isPositionLocked = false
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.secondaryLabelColor.withAlphaComponent(0.55).setStroke()
        for i in 0..<3 {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: bounds.width - 6 - CGFloat(i * 4), y: 5))
            path.line(to: NSPoint(x: bounds.width - 5, y: 6 + CGFloat(i * 4)))
            path.lineWidth = 1; path.stroke()
        }
    }
    override func mouseDown(with event: NSEvent) {
        guard !isPositionLocked, let window else { return }
        let initial = window.frame
        let start = NSEvent.mouseLocation
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp { break }
            let now = NSEvent.mouseLocation
            let screen = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let width = min(min(640, screen.maxX - initial.minX), max(280, initial.width + now.x - start.x))
            let height = min(min(800, initial.maxY - screen.minY), max(240, initial.height - now.y + start.y))
            window.setFrame(NSRect(x: initial.minX, y: initial.maxY - height, width: width, height: height), display: true)
        }
        changed?()
    }
}

final class WidgetSurface: NSView {
    let glass = NSGlassEffectView()
    let header = WidgetHeader()
    let scroll = NSScrollView()
    let rows = WidgetRows()
    let emptyTitle = NSTextField(labelWithString: "")
    let grip = ResizeGrip()
    let addGlass = NSGlassEffectView()
    let addButton = WidgetAddButton(frame: .zero)
    var onAdd: (() -> Void)?
    private var subscription: AnyCancellable?
    let store: ReminderStore

    init(store: ReminderStore) {
        self.store = store
        super.init(frame: NSRect(x: 0, y: 0, width: 340, height: 390))
        wantsLayer = true
        glass.style = .regular
        glass.cornerRadius = 24
        addSubview(glass)
        addSubview(header)
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.documentView = rows
        rows.postsFrameChangedNotifications = true
        addSubview(scroll)
        emptyTitle.font = .systemFont(ofSize: 13)
        emptyTitle.textColor = .secondaryLabelColor
        emptyTitle.alignment = .center
        addSubview(emptyTitle)
        addSubview(grip)
        addGlass.style = .regular
        addGlass.cornerRadius = 13
        addGlass.setAccessibilityElement(false)
        addSubview(addGlass)
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 11, weight: .semibold))
        addButton.imagePosition = .imageOnly
        addButton.isBordered = false
        addButton.contentTintColor = .labelColor
        addButton.target = self
        addButton.action = #selector(requestAdd)
        addButton.setAccessibilityLabel("添加待办")
        addSubview(addButton)
        subscription = store.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.reload() }
        }
        reload()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    @objc private func requestAdd() { onAdd?() }

    func reload() {
        let settings = store.settings
        appearance = settings.appearance == "system" ? nil : NSAppearance(named: settings.appearance == "dark" ? .darkAqua : .aqua)
        glass.alphaValue = 1 - settings.transparency
        header.isPositionLocked = settings.isPositionLocked
        grip.isPositionLocked = settings.isPositionLocked
        grip.isHidden = settings.isPositionLocked
        rows.subviews.forEach { $0.removeFromSuperview() }
        for item in store.pending {
            rows.addSubview(WidgetRow(item: item, day: store.countdownDay) { [weak store] in store?.toggle(item.id) })
        }
        let count = store.pending.count
        emptyTitle.stringValue = "暂无待办"
        emptyTitle.isHidden = count > 0
        scroll.isHidden = count == 0
        needsLayout = true
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height
        glass.frame = bounds
        header.frame = NSRect(x: 0, y: h - 73, width: w, height: 73)
        scroll.frame = NSRect(x: 0, y: 12, width: w, height: max(0, h - 85))
        addButton.frame = NSRect(x: w - 59, y: 13, width: 34, height: 34)
        addGlass.frame = addButton.frame.insetBy(dx: 4, dy: 4)
        let rowHeight: CGFloat = 54
        let itemsHeight = CGFloat(rows.subviews.count) * rowHeight
        let viewportHeight = scroll.contentSize.height
        // Extend only the scrollable document when needed, so the last item can clear the floating control.
        let clearance = addButton.frame.maxY - scroll.frame.minY + 3
        let tail = itemsHeight > viewportHeight - clearance ? clearance : 0
        rows.frame = NSRect(x: 0, y: 0, width: w, height: max(viewportHeight, itemsHeight + tail))
        for (index, row) in rows.subviews.enumerated() {
            row.frame = NSRect(x: 0, y: CGFloat(index) * rowHeight, width: w, height: rowHeight)
        }
        emptyTitle.frame = NSRect(x: 18, y: h * 0.5, width: w - 36, height: 28)
        grip.frame = NSRect(x: w - 22, y: 3, width: 17, height: 17)
    }
}

@MainActor final class WidgetController: NSObject, NSWindowDelegate {
    let panel: DesktopPanel
    let surface: WidgetSurface
    let store: ReminderStore
    private var subscription: AnyCancellable?
    private var applying = false
    private var lastSettings: WidgetSettings?

    init(store: ReminderStore) {
        self.store = store
        panel = DesktopPanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 390), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        surface = WidgetSurface(store: store)
        super.init()
        panel.title = "List Reminder 桌面小组件"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isFloatingPanel = false
        panel.isReleasedWhenClosed = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.contentView = surface
        panel.delegate = self
        surface.grip.changed = { [weak self] in self?.saveFrame() }
        subscription = store.$settings.sink { [weak self] value in
            DispatchQueue.main.async { self?.apply(value) }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        apply(store.settings)
    }

    private func apply(_ settings: WidgetSettings) {
        guard settings != lastSettings else { return }
        let previous = lastSettings
        lastSettings = settings
        applying = true
        defer { applying = false }
        panel.isMovable = !settings.isPositionLocked
        if previous == nil || previous?.width != settings.width || previous?.height != settings.height || previous?.x != settings.x || previous?.y != settings.y {
            let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(NSPoint(x: settings.x ?? -99999, y: settings.y ?? -99999)) }) ?? NSScreen.main
            let area = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let width = min(settings.width, area.width), height = min(settings.height, area.height)
            let x = min(area.maxX - width, max(area.minX, settings.x ?? area.maxX - width - 32))
            let top = previous == nil ? (settings.y.map { $0 + height } ?? area.maxY - 32) : panel.frame.maxY
            let y = min(area.maxY - height, max(area.minY, settings.y ?? top - height))
            panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }
        if settings.isVisible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
    }

    func saveFrame() {
        guard !applying else { return }
        let frame = panel.frame
        store.updateSettings { $0.width = frame.width; $0.height = frame.height; $0.x = frame.minX; $0.y = frame.minY }
    }
    func windowDidMove(_ notification: Notification) { saveFrame() }
    @objc private func screenChanged() { lastSettings = nil; apply(store.settings) }
    func resetPosition() { store.updateSettings { $0.x = nil; $0.y = nil }; lastSettings = nil; apply(store.settings) }
}
