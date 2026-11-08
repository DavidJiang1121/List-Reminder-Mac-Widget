import AppKit
import Foundation

@main struct Regression {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ListReminder-tests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ReminderStore(directory: root)
        assert(store.reminders.isEmpty)
        assert(!store.settings.isPositionLocked)
        let oldSettings = try JSONDecoder().decode(WidgetSettings.self, from: Data("{\"transparency\":0.5,\"width\":300,\"height\":400,\"x\":12,\"y\":24,\"isVisible\":true,\"appearance\":\"light\"}".utf8))
        assert(!oldSettings.isPositionLocked && oldSettings.width == 300 && oldSettings.x == 12)
        assert(!store.add(" \n  "))
        assert(!store.add(String(repeating: "a", count: 1001)))
        assert(store.add("  完成一件小事  "))
        assert(store.pending.first?.title == "完成一件小事")
        let id = store.pending[0].id
        assert(store.rename(id, title: "测试中文 / 📝"))
        assert(store.rename(id, title: "测试中文 / 📝"))
        assert(!store.rename(id, title: "  "))
        let row = WidgetRow(item: store.pending[0]) { store.toggle(id) }
        let single = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        let double = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0.1, windowNumber: 0, context: nil, eventNumber: 2, clickCount: 2, pressure: 1)!
        row.mouseDown(with: single)
        assert(store.pending.count == 1, "A single click must not complete a row")
        row.mouseDown(with: double)
        assert(store.pending.isEmpty && store.completed.count == 1)
        assert(store.completed[0].completedAt != nil)
        store.undo()
        assert(store.pending.count == 1)
        assert(store.undoTitle == nil)
        store.updateSettings { $0.transparency = 0.73; $0.width = 440; $0.height = 520; $0.x = 100; $0.y = 120; $0.appearance = "dark"; $0.isVisible = false; $0.isPositionLocked = true }
        let restored = ReminderStore(directory: root)
        assert(restored.reminders == store.reminders)
        assert(restored.settings == store.settings)
        assert(restored.settings.isPositionLocked)
        let header = WidgetHeader()
        assert(header.mouseDownCanMoveWindow)
        header.isPositionLocked = true
        assert(!header.mouseDownCanMoveWindow)
        header.mouseDown(with: single)
        let surface = WidgetSurface(store: restored)
        assert(surface.header.isPositionLocked && surface.grip.isPositionLocked && surface.grip.isHidden)
        let lockedID = restored.pending[0].id
        let lockedRow = WidgetRow(item: restored.pending[0]) { restored.toggle(lockedID) }
        lockedRow.mouseDown(with: double)
        assert(restored.completed.count == 1 && restored.settings.isPositionLocked)
        restored.undo()
        restored.updateSettings { $0.isPositionLocked = false }
        surface.reload()
        assert(!surface.header.isPositionLocked && !surface.grip.isPositionLocked && !surface.grip.isHidden)
        store.updateSettings { $0.width = -1; $0.height = 10000; $0.transparency = 4; $0.appearance = "invalid" }
        assert(store.settings.width == 280 && store.settings.height == 800 && store.settings.transparency == 0.9 && store.settings.appearance == "system")
        store.toggle(id)
        store.clearCompleted()
        assert(store.reminders.isEmpty)
        store.undo()
        assert(store.completed.count == 1)
        store.remove(id)
        assert(store.reminders.isEmpty)
        store.undo()
        assert(store.completed.count == 1)
        if !NSScreen.screens.isEmpty {
            let controller = WidgetController(store: restored)
            assert(!controller.panel.canBecomeKey && !controller.panel.canBecomeMain)
            assert(controller.panel.styleMask.contains(.nonactivatingPanel))
            assert(!controller.panel.hidesOnDeactivate)
            assert(controller.panel.level.rawValue == Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            assert(!controller.panel.isVisible)
            assert(controller.surface.glass.alphaValue == 1 - restored.settings.transparency)
            controller.panel.orderOut(nil)
        } else {
            print("NOTE: no display in shell sandbox; panel flags and glass must also be verified in live app")
        }
        let corruptRoot = root.appendingPathComponent("corrupt")
        try FileManager.default.createDirectory(at: corruptRoot, withIntermediateDirectories: true)
        let badData = Data("{ broken json".utf8)
        try badData.write(to: corruptRoot.appendingPathComponent("reminders.json"))
        let corrupted = ReminderStore(directory: corruptRoot)
        assert(corrupted.errorMessage != nil)
        assert(corrupted.reminders.isEmpty)
        let backups = try FileManager.default.contentsOfDirectory(at: corruptRoot, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.contains("unreadable") }
        assert(backups.count == 1)
        let backupData = try Data(contentsOf: backups[0])
        assert(backupData == badData)
        assert(corrupted.add("安全的新待办"))
        let failureRoot = root.appendingPathComponent("blocked")
        try Data().write(to: failureRoot)
        let failing = ReminderStore(directory: failureRoot)
        assert(!failing.add("不能静默丢失"))
        assert(failing.reminders.isEmpty && failing.errorMessage != nil)
        print("PASS: add/trim/limits, edit, single vs double click, complete/restore, undo/delete/clear, persistence, settings bounds, corruption backup, failed-write rollback, legacy settings migration, lock persistence, drag guard, resize guard, double-click while locked, unlock")
    }
}
