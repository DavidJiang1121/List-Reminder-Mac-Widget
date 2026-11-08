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
        assert(store.edit(id, title: "测试中文 / 📝", deadline: nil))
        assert(store.edit(id, title: "测试中文 / 📝", deadline: nil))
        assert(!store.edit(id, title: "  ", deadline: nil))
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
        try verifyCountdowns(at: root.appendingPathComponent("countdowns"))
        print("PASS: add/trim/limits, edit, single vs double click, complete/restore, undo/delete/clear, persistence, settings bounds, corruption backup, failed-write rollback, legacy migration, lock/resize guards, calendar deadlines, DST and time-zone changes, urgency rollover, widget plus while locked, completion-only celebration")
    }

    @MainActor private static func verifyCountdowns(at root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let oldData = """
        {"version":1,"reminders":[{"id":"01234567-89AB-CDEF-0123-456789ABCDEF","title":"旧版待办","createdAt":0,"isCompleted":false}],"settings":{"isPositionLocked":true}}
        """
        try Data(oldData.utf8).write(to: root.appendingPathComponent("reminders.json"))
        let store = ReminderStore(directory: root)
        assert(store.errorMessage == nil && store.pending.count == 1 && store.pending[0].deadline == nil)
        let pacific = TimeZone(identifier: "America/Los_Angeles")!
        var local = Calendar(identifier: .gregorian)
        local.timeZone = pacific
        func march(_ day: Int) -> Date { local.date(from: DateComponents(year: 2026, month: 3, day: day, hour: 12))! }
        let deadline = ReminderDeadline(march(10), calendar: local)
        store.refreshDay(now: march(6), timeZone: pacific)
        assert(deadline.countdown(on: store.countdownDay)?.label == "4d")
        assert(deadline.countdown(on: store.countdownDay)?.tone == .planned)
        assert(store.add("有截止日期", deadline: deadline))
        assert(store.add("不倒计时"))
        let item = store.pending[1]
        assert(item.deadline == deadline && store.pending[2].deadline == nil)
        assert(ReminderStore(directory: root).pending[1].deadline == deadline)
        let surface = WidgetSurface(store: store)
        surface.layoutSubtreeIfNeeded()
        assert(surface.grip.isHidden && !surface.addButton.isHidden)
        assert(surface.addButton.frame.intersects(surface.scroll.frame), "The add button floats over the list instead of reserving a footer")
        assert(!surface.addButton.frame.intersects(surface.grip.frame))
        surface.setFrameSize(NSSize(width: 280, height: 240))
        surface.layoutSubtreeIfNeeded()
        let bottomClearance = surface.rows.bounds.maxY - surface.rows.subviews.last!.frame.maxY
        assert(bottomClearance >= surface.addButton.frame.maxY - surface.scroll.frame.minY, "The last task must scroll clear of the floating button")
        var addCount = 0
        surface.onAdd = { addCount += 1 }
        surface.addButton.performClick(nil)
        assert(addCount == 1 && store.pending.count == 3 && store.settings.isPositionLocked)
        assert((surface.rows.subviews[1] as? WidgetRow)?.countdown?.tone == .planned)
        store.refreshDay(now: march(7), timeZone: pacific)
        surface.reload()
        assert((surface.rows.subviews[1] as? WidgetRow)?.countdown?.label == "3d")
        assert((surface.rows.subviews[1] as? WidgetRow)?.countdown?.tone == .soon)
        store.refreshDay(now: march(8), timeZone: pacific)
        surface.reload()
        assert((surface.rows.subviews[1] as? WidgetRow)?.countdown == ReminderCountdown(days: 2))
        let dueToday = deadline.countdown(on: ReminderDay(now: march(10), timeZone: pacific))
        assert(dueToday?.label == "今天截止" && dueToday?.tone == .soon)
        let overdue = deadline.countdown(on: ReminderDay(now: march(11), timeZone: pacific))
        assert(overdue?.label == "-1d" && overdue?.tone == .overdue)
        let instant = local.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 12))!
        assert(deadline.countdown(on: ReminderDay(now: instant, timeZone: pacific))?.days == 1)
        assert(deadline.countdown(on: ReminderDay(now: instant, timeZone: TimeZone(identifier: "Asia/Shanghai")!))?.days == 0)
        var celebrations = 0
        store.onCompletion = { celebrations += 1 }
        store.toggle(item.id)
        assert(celebrations == 1)
        assert(store.completed[0].deadline == deadline && store.completed[0].countdown(on: store.countdownDay) == nil)
        store.undo()
        assert(celebrations == 1)
        assert(store.pending[1].countdown(on: store.countdownDay)?.days == 2)
        store.toggle(item.id)
        assert(celebrations == 2)
        store.toggle(item.id)
        assert(celebrations == 2 && store.pending[1].deadline == deadline)
        assert(store.edit(item.id, title: item.title, deadline: nil))
        assert(ReminderStore(directory: root).pending[1].deadline == nil)
        store.undo()
        assert(store.pending[1].deadline == deadline)
    }
}
