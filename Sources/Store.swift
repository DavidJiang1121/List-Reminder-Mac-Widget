import Foundation
import Combine

struct Reminder: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted = false
    var createdAt = Date()
    var completedAt: Date?
}

struct WidgetSettings: Codable, Equatable {
    var transparency: Double = 0.24
    var width: Double = 340
    var height: Double = 390
    var x: Double?
    var y: Double?
    var isVisible = true
    var appearance = "system"
    var isPositionLocked = false

    init() {}
    private enum CodingKeys: String, CodingKey { case transparency, width, height, x, y, isVisible, appearance, isPositionLocked }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        transparency = try values.decodeIfPresent(Double.self, forKey: .transparency) ?? 0.24
        width = try values.decodeIfPresent(Double.self, forKey: .width) ?? 340
        height = try values.decodeIfPresent(Double.self, forKey: .height) ?? 390
        x = try values.decodeIfPresent(Double.self, forKey: .x)
        y = try values.decodeIfPresent(Double.self, forKey: .y)
        isVisible = try values.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        appearance = try values.decodeIfPresent(String.self, forKey: .appearance) ?? "system"
        isPositionLocked = try values.decodeIfPresent(Bool.self, forKey: .isPositionLocked) ?? false
    }

    mutating func normalize() {
        transparency = transparency.isFinite ? min(0.9, max(0, transparency)) : 0.24
        width = width.isFinite ? min(640, max(280, width)) : 340
        height = height.isFinite ? min(800, max(240, height)) : 390
        if let x, !x.isFinite { self.x = nil }
        if let y, !y.isFinite { self.y = nil }
        if !["system", "light", "dark"].contains(appearance) { appearance = "system" }
    }
}

private struct SavedState: Codable {
    var version = 1
    var reminders: [Reminder] = []
    var settings = WidgetSettings()
}

@MainActor final class ReminderStore: ObservableObject {
    @Published private(set) var reminders: [Reminder] = []
    @Published private(set) var settings = WidgetSettings()
    @Published var errorMessage: String?
    @Published private(set) var undoTitle: String?
    private var undoSnapshot: [Reminder]?
    private var loadBlocked = false
    let fileURL: URL

    var pending: [Reminder] { reminders.filter { !$0.isCompleted } }
    var completed: [Reminder] { reminders.filter(\.isCompleted).sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) } }

    init(directory: URL? = nil) {
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("List Reminder", isDirectory: true)
        fileURL = root.appendingPathComponent("reminders.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let saved = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: fileURL))
            guard saved.version == 1 else { throw CocoaError(.coderReadCorrupt) }
            reminders = saved.reminders
            settings = saved.settings
            settings.normalize()
        } catch {
            let backup = root.appendingPathComponent("reminders-unreadable-\(UUID().uuidString).json")
            do {
                try FileManager.default.copyItem(at: fileURL, to: backup)
                errorMessage = "无法读取原有数据，已保留备份：\(backup.lastPathComponent)。你可以继续添加待办。"
            } catch {
                loadBlocked = true
                errorMessage = "无法读取待办文件。原文件已保留；请检查文件夹权限。"
            }
        }
    }

    @discardableResult private func commit(_ items: [Reminder], settings nextSettings: WidgetSettings) -> Bool {
        guard !loadBlocked else { errorMessage = "原数据无法备份，已停止写入以保留原文件。请检查存储文件夹权限后重新打开应用。"; return false }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(SavedState(reminders: items, settings: nextSettings))
            try data.write(to: fileURL, options: .atomic)
            if reminders != items { reminders = items }
            if settings != nextSettings { settings = nextSettings }
            return true
        } catch {
            errorMessage = "保存失败，改动尚未保存：\(error.localizedDescription)"
            return false
        }
    }

    @discardableResult func add(_ title: String) -> Bool {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= 1000 else { return false }
        return change(reminders + [Reminder(title: cleaned)], label: "添加待办")
    }

    @discardableResult func rename(_ id: UUID, title: String) -> Bool {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= 1000, let index = reminders.firstIndex(where: { $0.id == id }) else { return false }
        if reminders[index].title == cleaned { return true }
        var items = reminders
        items[index].title = cleaned
        return change(items, label: "编辑待办")
    }

    func toggle(_ id: UUID) {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        var items = reminders
        items[index].isCompleted.toggle()
        items[index].completedAt = items[index].isCompleted ? Date() : nil
        _ = change(items, label: items[index].isCompleted ? "完成待办" : "恢复待办")
    }

    func remove(_ id: UUID) { _ = change(reminders.filter { $0.id != id }, label: "删除待办") }
    func clearCompleted() { _ = change(pending, label: "清除已完成") }

    @discardableResult private func change(_ items: [Reminder], label: String) -> Bool {
        let previous = reminders
        guard items != previous, commit(items, settings: settings) else { return false }
        undoSnapshot = previous
        undoTitle = label
        return true
    }

    func undo() {
        guard let previous = undoSnapshot, commit(previous, settings: settings) else { return }
        undoSnapshot = nil
        undoTitle = nil
    }

    func updateSettings(_ update: (inout WidgetSettings) -> Void) {
        var next = settings
        update(&next)
        next.normalize()
        guard next != settings else { return }
        _ = commit(reminders, settings: next)
    }
}
