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

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: ReminderStore!
    var widget: WidgetController!
    var window: NSWindow!
    var status: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let testDirectory = ProcessInfo.processInfo.environment["LIST_REMINDER_DATA_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        store = ReminderStore(directory: testDirectory)
        widget = WidgetController(store: store)
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
    func applicationWillTerminate(_ notification: Notification) { widget?.saveFrame() }

    @objc func showMain() { window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func newReminder() { showMain(); NotificationCenter.default.post(name: .newReminder, object: nil) }
    @objc func settings() { showMain(); NotificationCenter.default.post(name: .showWidgetSettings, object: nil) }
    @objc func toggleWidget() { store.updateSettings { $0.isVisible.toggle() } }
    @objc func resetWidget() { widget.resetPosition(); store.updateSettings { $0.isVisible = true } }

    private func configureStatusItem() {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "List Reminder")
        status.button?.toolTip = "List Reminder"
        let menu = NSMenu()
        menu.addItem(item("打开 List Reminder", #selector(showMain), ""))
        menu.addItem(item("添加待办…", #selector(newReminder), ""))
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
