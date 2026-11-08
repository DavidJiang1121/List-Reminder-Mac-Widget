import AppKit
import SwiftUI

@main struct ListReminderApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

private final class QuickAddPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var store: ReminderStore!
    var widget: WidgetController!
    var window: NSWindow!
    var status: NSStatusItem!
    private var quickAddPanel: QuickAddPanel?
    private var dayTimer: Timer?
    private let celebration = CompletionCelebration()
    private let quickAddFocus = QuickAddFocus()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let testDirectory = ProcessInfo.processInfo.environment["LIST_REMINDER_DATA_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        store = ReminderStore(directory: testDirectory)
        widget = WidgetController(store: store)
        widget.surface.onAdd = { [weak self] in self?.showQuickAdd() }
        store.onCompletion = { [weak self] in self?.celebrateCompletion() }
        startCountdownClock()
        NotificationCenter.default.addObserver(self, selector: #selector(recenterQuickAdd), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        configureMenu()
        configureStatusItem()
        let content = MainView(store: store, resetPosition: { [weak self] in self?.widget.resetPosition() })
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1030, height: 710), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "List Reminder"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 940, height: 650)
        window.contentView = NSHostingView(rootView: content)
        window.setFrameAutosaveName("ListReminderMainWindow")
        if !window.setFrameUsingName("ListReminderMainWindow") { window.center() }
        showMain()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMain(); return true }
    func applicationWillTerminate(_ notification: Notification) { dayTimer?.invalidate(); celebration.dismiss(); quickAddFocus.dismiss(animated: false); widget?.saveFrame() }

    private func celebrateCompletion() {
        let cursor = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(cursor) } ?? NSApp.keyWindow?.screen ?? widget.panel.screen ?? NSScreen.main
        if let screen { celebration.show(on: screen) }
    }

    @objc func showMain() { quickAddPanel?.close(); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func newReminder() { showMain(); NotificationCenter.default.post(name: .newReminder, object: nil) }
    @objc func settings() { showMain(); NotificationCenter.default.post(name: .showWidgetSettings, object: nil) }
    @objc func toggleWidget() { store.updateSettings { $0.isVisible.toggle() } }
    @objc func resetWidget() { widget.resetPosition(); store.updateSettings { $0.isVisible = true } }

    @objc private func showQuickAdd() {
        if let panel = quickAddPanel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        store.refreshDay()
        let panel = QuickAddPanel(contentRect: NSRect(x: 0, y: 0, width: 390, height: 470), styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "快速添加待办"
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = QuickAddFocus.editorLevel
        panel.isMovable = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.appearance = widget.surface.appearance
        let editor = NSHostingView(rootView: ReminderEditor(store: store, close: { [weak panel] in panel?.close() }))
        panel.contentView = editor
        panel.setContentSize(editor.fittingSize)
        let pointer = NSEvent.mouseLocation
        let pointerScreen = NSScreen.screens.first { $0.frame.contains(pointer) }
        if let screen = (widget.panel.isVisible ? widget.panel.screen : nil) ?? pointerScreen ?? NSScreen.main {
            center(panel, on: screen)
            quickAddFocus.show(on: screen, refocus: { [weak panel] in panel?.makeKeyAndOrderFront(nil) })
        } else { panel.center() }
        panel.delegate = self
        quickAddPanel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    private func center(_ panel: NSWindow, on screen: NSScreen) {
        let area = screen.frame
        panel.setFrameOrigin(NSPoint(x: area.midX - panel.frame.width / 2, y: area.midY - panel.frame.height / 2))
    }

    @objc private func recenterQuickAdd(_ notification: Notification) {
        guard let panel = quickAddPanel, let screen = panel.screen ?? NSScreen.main else { return }
        quickAddFocus.move(to: screen)
        center(panel, on: screen)
    }

    func windowDidResize(_ notification: Notification) {
        if let panel = quickAddPanel, notification.object as? NSWindow === panel { recenterQuickAdd(notification) }
    }

    func windowWillClose(_ notification: Notification) {
        guard let panel = quickAddPanel, notification.object as? NSWindow === panel else { return }
        quickAddPanel = nil
        quickAddFocus.dismiss()
    }

    private func startCountdownClock() {
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.store.refreshDay() }
        }
        timer.tolerance = 2
        RunLoop.main.add(timer, forMode: .common)
        dayTimer = timer
        for name in [Notification.Name.NSCalendarDayChanged, .NSSystemClockDidChange, .NSSystemTimeZoneDidChange] {
            NotificationCenter.default.addObserver(self, selector: #selector(refreshCountdownClock), name: name, object: nil)
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refreshCountdownClock), name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func refreshCountdownClock(_ notification: Notification) {
        Task { @MainActor [weak self] in self?.store.refreshDay() }
    }

    private func configureStatusItem() {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "List Reminder")
        status.button?.toolTip = "List Reminder"
        let menu = NSMenu()
        menu.addItem(item("打开 List Reminder", #selector(showMain), ""))
        menu.addItem(item("快速添加待办…", #selector(showQuickAdd), ""))
        menu.addItem(.separator())
        menu.addItem(item("显示 / 隐藏桌面小组件", #selector(toggleWidget), ""))
        menu.addItem(item("小组件外观…", #selector(settings), ""))
        menu.addItem(item("将小组件移回主屏幕", #selector(resetWidget), ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 List Reminder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        status.menu = menu
    }
    private func configureMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "关于 List Reminder", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(item("小组件外观…", #selector(settings), ","))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "隐藏 List Reminder", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "退出 List Reminder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        let file = NSMenuItem(); menu.addItem(file)
        file.submenu = NSMenu(title: "文件")
        file.submenu?.addItem(item("添加待办", #selector(newReminder), "n"))
        file.submenu?.addItem(NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        let edit = NSMenuItem(); menu.addItem(edit)
        edit.submenu = NSMenu(title: "编辑")
        for (title, action, key) in [("撤销", "undo:", "z"), ("重做", "redo:", "Z"), ("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            edit.submenu?.addItem(NSMenuItem(title: title, action: Selector(action), keyEquivalent: key))
        }
        let view = NSMenuItem(); menu.addItem(view)
        view.submenu = NSMenu(title: "窗口")
        view.submenu?.addItem(item("打开待办窗口", #selector(showMain), "0"))
        view.submenu?.addItem(item("显示 / 隐藏桌面小组件", #selector(toggleWidget), ""))
        NSApp.mainMenu = menu
    }
    private func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }
}
