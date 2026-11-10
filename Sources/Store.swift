import Foundation
import Combine

enum ReminderCategory: String, Codable, CaseIterable, Identifiable {
    case general = "普通"
    case homework = "作业"
    var id: Self { self }
}

struct Reminder: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted = false
    var createdAt = Date()
    var completedAt: Date?
    var deadline: ReminderDeadline?
    // Missing values in version 1 are ordinary, one-time tasks.
    var storedCategory: ReminderCategory?
    var repeatsDaily: Bool?
    var category: ReminderCategory { storedCategory ?? .general }
    var isDaily: Bool { repeatsDaily == true }

    func countdown(on day: ReminderDay) -> ReminderCountdown? {
        isCompleted || isDaily ? nil : deadline?.countdown(on: day)
    }

    func badge(on day: ReminderDay) -> ReminderBadge? {
        if isDaily { return .daily }
        return countdown(on: day).map(ReminderBadge.deadline)
    }

    func accessibilityTitle(on day: ReminderDay) -> String {
        [title, category == .homework ? category.rawValue : nil, badge(on: day)?.spokenLabel]
            .compactMap { $0 }.joined(separator: "，")
    }
}

enum ReminderBadge: Equatable {
    case daily
    case deadline(ReminderCountdown)

    var label: String {
        switch self { case .daily: return "每日"; case .deadline(let countdown): return countdown.label }
    }
    var spokenLabel: String {
        switch self { case .daily: return "每日重复"; case .deadline(let countdown): return countdown.spokenLabel }
    }
}

// Store the chosen calendar date, so travelling does not shift the deadline.
struct ReminderDeadline: Codable, Hashable {
    let year: Int
    let month: Int
    let day: Int

    init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year ?? 1
        month = parts.month ?? 1
        day = parts.day ?? 1
    }

    func date(in calendar: Calendar) -> Date? {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              ReminderDeadline(date, calendar: calendar) == self else { return nil }
        return calendar.startOfDay(for: date)
    }

    func countdown(on reference: ReminderDay) -> ReminderCountdown? {
        // Both endpoints are civil dates; UTC arithmetic avoids shortened DST days.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let target = date(in: calendar), let today = reference.date.date(in: calendar),
              let days = calendar.dateComponents([.day], from: today, to: target).day else { return nil }
        return ReminderCountdown(days: days)
    }
}

struct ReminderDay: Equatable {
    let date: ReminderDeadline
    let timeZone: TimeZone

    init(now: Date = .now, timeZone: TimeZone = .current) {
        self.timeZone = timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        date = ReminderDeadline(now, calendar: calendar)
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

struct ReminderCountdown: Equatable {
    enum Tone { case overdue, soon, planned }
    let days: Int
    var tone: Tone {
        if days < 0 { return .overdue }
        return days <= 3 ? .soon : .planned
    }
    var label: String {
        days == 0 ? "今天截止" : "\(days)d"
    }
    var spokenLabel: String {
        if days < 0 { return "超期 \(days.magnitude) 天" }
        return days == 0 ? label : "剩 \(days) 天"
    }
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
    var version = 2
    var reminders: [Reminder] = []
    var settings = WidgetSettings()
    var completionHistory: [CompletionRecord]?
}

struct CompletionRecord: Codable, Equatable {
    let reminderID: UUID
    let completedAt: Date
    let day: ReminderDeadline
}

@MainActor final class ReminderStore: ObservableObject {
    enum Completion { case task, allTasks }
    private struct UndoSnapshot {
        let reminders: [Reminder]
        let history: [CompletionRecord]
    }
    @Published private(set) var reminders: [Reminder] = []
    @Published private(set) var settings = WidgetSettings()
    @Published private(set) var completionHistory: [CompletionRecord] = []
    @Published var errorMessage: String?
    @Published private(set) var undoTitle: String?
    @Published private(set) var countdownDay = ReminderDay()
    private var undoSnapshot: UndoSnapshot?
    private var loadBlocked = false
    var onCompletion: ((Completion) -> Void)?
    let fileURL: URL

    private var dailyCompletions: [UUID: Date] {
        completionHistory.reduce(into: [:]) { dates, entry in
            if entry.day == countdownDay.date { dates[entry.reminderID] = entry.completedAt }
        }
    }
    var pending: [Reminder] {
        let daily = dailyCompletions
        return reminders.filter { $0.isDaily ? daily[$0.id] == nil : !$0.isCompleted }
    }
    var completed: [Reminder] {
        let daily = dailyCompletions
        return reminders.compactMap { item -> Reminder? in
            guard item.isDaily else { return item.isCompleted ? item : nil }
            guard let date = daily[item.id] else { return nil }
            var occurrence = item
            occurrence.isCompleted = true
            occurrence.completedAt = date
            return occurrence
        }.sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }
    var completionCounts: [ReminderDeadline: Int] {
        completionHistory.reduce(into: [:]) { $0[$1.day, default: 0] += 1 }
    }

    init(directory: URL? = nil) {
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("List Reminder", isDirectory: true)
        fileURL = root.appendingPathComponent("reminders.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let saved = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: fileURL))
            guard saved.version == 1 || saved.version == 2 else {
                loadBlocked = true
                errorMessage = "待办文件由其他版本创建，已保留原文件。"
                return
            }
            reminders = saved.reminders
            settings = saved.settings
            settings.normalize()
            completionHistory = saved.completionHistory ?? saved.reminders.compactMap { item in
                guard item.isCompleted, let time = item.completedAt else { return nil }
                return CompletionRecord(reminderID: item.id, completedAt: time, day: ReminderDay(now: time).date)
            }
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

    @discardableResult private func commit(_ items: [Reminder], history: [CompletionRecord], settings nextSettings: WidgetSettings) -> Bool {
        guard !loadBlocked else { errorMessage = "已停止写入以保留原有待办文件。"; return false }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(SavedState(reminders: items, settings: nextSettings, completionHistory: history))
            try data.write(to: fileURL, options: .atomic)
            if reminders != items { reminders = items }
            if completionHistory != history { completionHistory = history }
            if settings != nextSettings { settings = nextSettings }
            return true
        } catch {
            errorMessage = "保存失败，改动尚未保存：\(error.localizedDescription)"
            return false
        }
    }

    func refreshDay(now: Date = .now, timeZone: TimeZone = .current) {
        let day = ReminderDay(now: now, timeZone: timeZone)
        if countdownDay != day { countdownDay = day }
    }

    @discardableResult func add(_ title: String, deadline: ReminderDeadline? = nil, category: ReminderCategory = .general, daily: Bool = false) -> Bool {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= 1000 else { return false }
        let item = Reminder(title: cleaned, deadline: daily ? nil : deadline, storedCategory: category == .general ? nil : category, repeatsDaily: daily ? true : nil)
        return change(reminders + [item], history: completionHistory, label: "添加待办")
    }

    @discardableResult func edit(_ id: UUID, title: String, deadline: ReminderDeadline?, category: ReminderCategory? = nil, daily: Bool? = nil) -> Bool {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= 1000, let index = reminders.firstIndex(where: { $0.id == id }) else { return false }
        var items = reminders
        let wasDaily = items[index].isDaily
        let repeats = daily ?? wasDaily
        items[index].title = cleaned
        items[index].deadline = repeats ? nil : deadline
        if let category { items[index].storedCategory = category == .general ? nil : category }
        items[index].repeatsDaily = repeats ? true : nil
        if repeats {
            items[index].isCompleted = false
            items[index].completedAt = nil
        } else if wasDaily {
            items[index].completedAt = dailyCompletions[id]
            items[index].isCompleted = items[index].completedAt != nil
        }
        if items == reminders { return true }
        return change(items, history: completionHistory, label: "编辑待办")
    }

    func toggle(_ id: UUID, now: Date = .now, timeZone: TimeZone = .current) {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        refreshDay(now: now, timeZone: timeZone)
        var items = reminders
        var history = completionHistory
        let finished: Bool
        if items[index].isDaily {
            finished = !history.contains { $0.reminderID == id && $0.day == countdownDay.date }
            if !finished { history.removeAll { $0.reminderID == id && $0.day == countdownDay.date } }
        } else {
            finished = !items[index].isCompleted
            if let time = items[index].completedAt, !finished {
                history.removeAll { $0.reminderID == id && $0.completedAt == time }
            }
            items[index].isCompleted = finished
            items[index].completedAt = finished ? now : nil
        }
        if finished {
            history.append(CompletionRecord(reminderID: id, completedAt: now, day: countdownDay.date))
        }
        if change(items, history: history, label: finished ? "完成待办" : "恢复待办"), finished {
            onCompletion?(pending.isEmpty ? .allTasks : .task)
        }
    }

    func remove(_ id: UUID) { _ = change(reminders.filter { $0.id != id }, history: completionHistory, label: "删除待办") }
    func clearCompleted() { _ = change(reminders.filter { $0.isDaily || !$0.isCompleted }, history: completionHistory, label: "清除已完成") }

    @discardableResult private func change(_ items: [Reminder], history: [CompletionRecord], label: String) -> Bool {
        let previous = UndoSnapshot(reminders: reminders, history: completionHistory)
        guard items != previous.reminders || history != previous.history,
              commit(items, history: history, settings: settings) else { return false }
        undoSnapshot = previous
        undoTitle = label
        return true
    }

    func undo() {
        guard let previous = undoSnapshot, commit(previous.reminders, history: previous.history, settings: settings) else { return }
        undoSnapshot = nil
        undoTitle = nil
    }

    func updateSettings(_ update: (inout WidgetSettings) -> Void) {
        var next = settings
        update(&next)
        next.normalize()
        guard next != settings else { return }
        _ = commit(reminders, history: completionHistory, settings: next)
    }
}
