import SwiftUI
import AppKit

private let accent = Color(red: 0.28, green: 0.31, blue: 0.30)
private let ink = Color(red: 0.17, green: 0.20, blue: 0.19)
private let muted = Color(red: 0.49, green: 0.51, blue: 0.48)
private let paper = Color(red: 0.98, green: 0.975, blue: 0.96)

enum AppSection: String, CaseIterable { case pending = "待办清单", completed = "已完成", appearance = "小组件外观" }
private struct EditorSession: Identifiable {
    let id = UUID()
    var item: Reminder?
}

struct MainView: View {
    @ObservedObject var store: ReminderStore
    var resetPosition: () -> Void
    @State private var section: AppSection = .pending
    @State private var editing: EditorSession?
    @State private var confirmClear = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(ink.opacity(0.06)).frame(width: 1)
            Group {
                if section == .appearance { appearancePage }
                else { listPage }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(paper)
        }
        .foregroundStyle(ink)
        .tint(accent)
        .frame(minWidth: 920, minHeight: 620)
        .preferredColorScheme(.light)
        .sheet(item: $editing) { session in ReminderEditor(store: store, item: session.item) }
        .alert("保存提示", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("知道了") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .alert("清除所有已完成待办？", isPresented: $confirmClear) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) { store.clearCompleted() }
        } message: { Text("清除后可以通过“撤销”恢复。") }
        .onReceive(NotificationCenter.default.publisher(for: .newReminder)) { _ in beginAdd() }
        .onReceive(NotificationCenter.default.publisher(for: .showWidgetSettings)) { _ in section = .appearance }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("List Reminder").font(.system(size: 14, weight: .semibold))
                }
            }
            .padding(.top, 58).padding(.bottom, 39)

            Text("我的空间").font(.system(size: 10, weight: .medium)).foregroundStyle(muted).padding(.leading, 12).padding(.bottom, 12)
            ForEach(AppSection.allCases, id: \.self) { page in
                Button { section = page } label: {
                    HStack(spacing: 10) {
                        Image(systemName: page == .pending ? "checklist" : page == .completed ? "checkmark.circle" : "slider.horizontal.3").font(.system(size: 15)).frame(width: 19)
                        Text(page.rawValue).font(.system(size: 12, weight: section == page ? .semibold : .regular))
                        Spacer(minLength: 2)
                        if page != .appearance {
                            Text("\(page == .pending ? store.pending.count : store.completed.count)")
                                .font(.system(size: 10, weight: .medium)).monospacedDigit()
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background((section == page ? accent : muted).opacity(0.1), in: Capsule())
                        }
                    }
                    .foregroundStyle(section == page ? accent : ink.opacity(0.72))
                    .padding(.horizontal, 12).padding(.vertical, 12)
                    .background(section == page ? accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain).padding(.bottom, 5)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Circle().fill(store.settings.isVisible ? Color(red: 0.36, green: 0.53, blue: 0.40) : muted).frame(width: 6, height: 6)
                    Text(store.settings.isVisible ? "桌面小组件已开启" : "桌面小组件已隐藏").font(.system(size: 10, weight: .medium))
                }
                Toggle("显示在桌面", isOn: binding(\.isVisible)).font(.system(size: 11)).toggleStyle(.switch).controlSize(.mini)
                    .accessibilityIdentifier("widgetVisibility")
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 5) {
                Image(systemName: "internaldrive").font(.system(size: 9))
                Text("本地保存 · 无需联网").font(.system(size: 9))
            }.foregroundStyle(muted).padding(.top, 18).padding(.bottom, 22).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 17).frame(width: 208)
        .frame(maxHeight: .infinity)
        .background(Color(red: 0.93, green: 0.935, blue: 0.91).opacity(0.86))
    }

    private var listPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide).locale(Locale(identifier: "zh_CN"))), systemImage: "sun.max")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(muted)
                Spacer()
                if let undoTitle = store.undoTitle {
                    Button { store.undo() } label: { Label("撤销\(undoTitle)", systemImage: "arrow.uturn.backward") }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(accent)
                        .accessibilityIdentifier("undoTask")
                }
            }.padding(.bottom, 27)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(section.rawValue)
                        .font(.system(size: 29, weight: .semibold))
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(section == .pending ? store.pending.count : store.completed.count)").font(.system(size: 34, weight: .light, design: .rounded))
                    Text(section == .pending ? "项待办" : "项完成").font(.system(size: 11)).foregroundStyle(muted)
                }.padding(.bottom, 2)
            }
            Spacer().frame(height: 24)

            HStack(spacing: 0) {
                Rectangle().fill(ink.opacity(0.08)).frame(height: 1)
                Text(section == .pending ? "待办事项" : "已完成事项").font(.system(size: 10, weight: .medium)).foregroundStyle(muted).padding(.horizontal, 13)
                Rectangle().fill(ink.opacity(0.08)).frame(height: 1)
            }.padding(.bottom, 10)

            let items = section == .pending ? store.pending : store.completed
            if items.isEmpty {
                VStack(spacing: 13) {
                    ZStack {
                        Circle().fill(accent.opacity(0.065)).frame(width: 68, height: 68)
                        Image(systemName: section == .pending ? (store.completed.isEmpty ? "leaf" : "checkmark") : "checkmark.seal")
                            .font(.system(size: 28, weight: .light)).foregroundStyle(accent.opacity(0.8))
                    }
                    Text(section == .pending ? "暂无待办" : "暂无已完成事项")
                        .font(.system(size: 16, weight: .medium))
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(items) { item in
                            ReminderRow(item: item, countdown: item.countdown(on: store.countdownDay), toggle: { store.toggle(item.id) }, edit: { editing = EditorSession(item: item) }, delete: { store.remove(item.id) })
                        }
                    }.padding(.vertical, 6)
                }.scrollIndicators(.hidden)
            }
            if section == .pending {
                Button(action: beginAdd) {
                    Label("添加待办", systemImage: "plus")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(accent)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .padding(.horizontal, 17)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(ink.opacity(0.09)))
                }.buttonStyle(.plain).accessibilityIdentifier("newTaskButton")
                .padding(.top, 18)
            } else if !store.completed.isEmpty {
                HStack {
                    Spacer()
                    Button("清除已完成") { confirmClear = true }.font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(accent)
                }.padding(.top, 15)
            }
        }.padding(.horizontal, 40).padding(.top, 43).padding(.bottom, 29)
    }

    private var appearancePage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("小组件外观")
                .font(.system(size: 28, weight: .semibold)).padding(.top, 9)
            Spacer().frame(height: 28)
            HStack(alignment: .top, spacing: 30) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        settingHeading("背景透明度", value: "\(Int(store.settings.transparency * 100))%")
                        Slider(value: binding(\.transparency), in: 0...0.9, step: 0.01).accessibilityLabel("背景透明度")
                        HStack { Text("更清晰"); Spacer(); Text("更通透") }.font(.system(size: 10)).foregroundStyle(muted)
                    }
                    Divider().opacity(0.5)
                    VStack(alignment: .leading, spacing: 12) {
                        settingHeading("小组件尺寸", value: "\(Int(store.settings.width)) × \(Int(store.settings.height))")
                        HStack(spacing: 7) {
                            sizeButton("小", width: 290, height: 300)
                            sizeButton("中", width: 340, height: 390)
                            sizeButton("大", width: 440, height: 520)
                        }
                        HStack { Text("宽度").frame(width: 27, alignment: .leading); Slider(value: binding(\.width), in: 280...640, step: 10).accessibilityLabel("小组件宽度") }.font(.system(size: 11)).foregroundStyle(muted)
                        HStack { Text("高度").frame(width: 27, alignment: .leading); Slider(value: binding(\.height), in: 240...800, step: 10).accessibilityLabel("小组件高度") }.font(.system(size: 11)).foregroundStyle(muted)
                    }
                    Divider().opacity(0.5)
                    VStack(alignment: .leading, spacing: 12) {
                        settingHeading("玻璃色调", value: "")
                        Picker("玻璃色调", selection: binding(\.appearance)) {
                            Text("跟随系统").tag("system")
                            Text("浅色").tag("light")
                            Text("深色").tag("dark")
                        }.pickerStyle(.segmented).labelsHidden()
                        HStack {
                            Button("重置桌面位置", action: resetPosition).buttonStyle(.plain).foregroundStyle(accent)
                            Spacer()
                            Toggle("显示", isOn: binding(\.isVisible)).toggleStyle(.switch).controlSize(.mini)
                        }.font(.system(size: 11)).padding(.top, 5)
                        Toggle("锁定位置", isOn: binding(\.isPositionLocked))
                            .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                            .accessibilityIdentifier("lockWidgetPosition")
                    }
                }.frame(maxWidth: .infinity)
                VStack(spacing: 15) {
                    WidgetPreview(store: store)
                    Label("实时外观预览", systemImage: "sparkle").font(.system(size: 10)).foregroundStyle(muted)
                }.frame(width: 230)
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 40).padding(.top, 52).padding(.bottom, 29)
    }

    private func binding<T>(_ path: WritableKeyPath<WidgetSettings, T>) -> Binding<T> {
        Binding(get: { store.settings[keyPath: path] }, set: { value in store.updateSettings { $0[keyPath: path] = value } })
    }
    private func settingHeading(_ label: String, value: String) -> some View {
        HStack { Text(label).font(.system(size: 12, weight: .semibold)); Spacer(); Text(value).font(.system(size: 10, design: .monospaced)).foregroundStyle(muted) }
    }
    private func sizeButton(_ title: String, width: Double, height: Double) -> some View {
        let selected = store.settings.width == width && store.settings.height == height
        return Button {
            store.updateSettings { $0.width = width; $0.height = height }
        } label: {
            Text(title).font(.system(size: 11, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(selected ? accent.opacity(0.09) : .white, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(selected ? accent.opacity(0.4) : ink.opacity(0.10)))
                .foregroundStyle(selected ? accent : ink)
        }.buttonStyle(.plain).accessibilityLabel("\(title)尺寸")
    }
    private func beginAdd() { section = .pending; editing = EditorSession() }
}

private struct ReminderRow: View {
    var item: Reminder
    var countdown: ReminderCountdown?
    var toggle: () -> Void
    var edit: () -> Void
    var delete: () -> Void
    @State private var hover = false
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .light)).foregroundStyle(item.isCompleted ? accent.opacity(0.75) : ink.opacity(0.23))
            Text(item.title).font(.system(size: 13, weight: .medium)).strikethrough(item.isCompleted, color: muted.opacity(0.6))
                .foregroundStyle(item.isCompleted ? muted : ink).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
            if let countdown { CountdownBadge(countdown: countdown) }
            HStack(spacing: 12) {
                Button(action: edit) { Image(systemName: "pencil").font(.system(size: 11)) }.help("编辑待办").accessibilityLabel("编辑：\(item.title)")
                Button(action: delete) { Image(systemName: "trash").font(.system(size: 11)) }.help("删除待办").accessibilityLabel("删除：\(item.title)")
            }.buttonStyle(.plain).foregroundStyle(muted).opacity(hover ? 1 : 0.30)
        }
        .padding(.horizontal, 17).padding(.vertical, 18)
        .background(hover ? .white : Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ink.opacity(hover ? 0.07 : 0.025)))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(count: 2, perform: toggle)
        .onHover { hover = $0 }
        .contextMenu {
            Button(item.isCompleted ? "恢复待办" : "完成待办", action: toggle)
            Button("编辑", action: edit)
            Button("删除", role: .destructive, action: delete)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(countdown.map { "\(item.title)，\($0.spokenLabel)" } ?? item.title)
        .accessibilityAction(named: item.isCompleted ? "恢复待办" : "完成待办", toggle)
    }
}

private struct CountdownBadge: View {
    let countdown: ReminderCountdown
    var size: CGFloat = 11
    var body: some View {
        let tone = Color(nsColor: countdown.color)
        Text(countdown.label).font(.system(size: size, weight: .semibold)).monospacedDigit()
            .foregroundStyle(tone).lineLimit(1).fixedSize()
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(tone.opacity(0.12), in: Capsule())
            .accessibilityLabel(countdown.spokenLabel)
    }
}

private struct WidgetPreview: View {
    @ObservedObject var store: ReminderStore
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.54, green: 0.64, blue: 0.58), Color(red: 0.78, green: 0.80, blue: 0.66), Color(red: 0.94, green: 0.84, blue: 0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.2)).frame(width: 160).blur(radius: 19).offset(x: 60, y: -90)
            VStack(alignment: .leading, spacing: 0) {
                HStack { Text("List Reminder").font(.system(size: 13, weight: .semibold)); Spacer() }.padding(.bottom, 18)
                let previewItems: [(String, ReminderCountdown?)] = store.pending.isEmpty
                    ? [("写下今天的第一件事", nil), ("为自己留一点时间", nil)]
                    : store.pending.prefix(3).map { ($0.title, $0.countdown(on: store.countdownDay)) }
                ForEach(Array(previewItems.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 9) {
                        Image(systemName: "circle").foregroundStyle(.secondary).font(.system(size: 13))
                        Text(item.0).font(.system(size: 10)).lineLimit(1)
                        Spacer(minLength: 0)
                        if let countdown = item.1 { CountdownBadge(countdown: countdown, size: 8) }
                    }.padding(.vertical, 8)
                    Rectangle().fill(.primary.opacity(0.06)).frame(height: 0.5)
                }
                Spacer(minLength: 4)
                Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22).background(.primary.opacity(0.08), in: Circle())
                    .frame(maxWidth: .infinity, alignment: .trailing).accessibilityHidden(true)
            }
            .padding(18).frame(width: 200, height: min(340, max(225, store.settings.height * 0.65)))
            .background { PreviewGlass(transparency: store.settings.transparency) }
            .environment(\.colorScheme, store.settings.appearance == "dark" ? .dark : .light)
            .foregroundStyle(store.settings.appearance == "dark" ? Color.white : ink)
            .shadow(color: .black.opacity(0.13), radius: 15, y: 10)
        }
        .frame(width: 230, height: 390).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct PreviewGlass: NSViewRepresentable {
    var transparency: Double
    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.cornerRadius = 18
        view.style = .regular
        return view
    }
    func updateNSView(_ view: NSGlassEffectView, context: Context) { view.alphaValue = 1 - transparency }
}

struct ReminderEditor: View {
    @ObservedObject var store: ReminderStore
    let item: Reminder?
    var close: (() -> Void)?
    @State private var title: String
    @State private var enablesCountdown: Bool
    @State private var selectedDate: Date
    @State private var saveError: String?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    init(store: ReminderStore, item: Reminder? = nil, close: (() -> Void)? = nil) {
        self.store = store; self.item = item; self.close = close
        let calendar = store.countdownDay.calendar
        let initialDate = item?.deadline?.date(in: calendar) ?? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        _title = State(initialValue: item?.title ?? "")
        _enablesCountdown = State(initialValue: item?.deadline != nil)
        _selectedDate = State(initialValue: initialDate)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item == nil ? "添加待办" : "编辑待办").font(.system(size: 20, weight: .semibold))
            TextField("待办内容", text: $title, axis: .vertical).lineLimit(2, reservesSpace: true)
                .textFieldStyle(.roundedBorder).focused($focused).accessibilityIdentifier("reminderTitle")
            Toggle("启用倒计时", isOn: $enablesCountdown).toggleStyle(.switch)
                .accessibilityIdentifier("reminderCountdownToggle")
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("截止日期").font(.system(size: 12, weight: .medium))
                    Spacer()
                    if enablesCountdown, let countdown = selectedDeadline.countdown(on: store.countdownDay) {
                        CountdownBadge(countdown: countdown)
                    }
                }.frame(minHeight: 24)
                DatePicker("截止日期", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical).labelsHidden()
                    .environment(\.calendar, store.countdownDay.calendar)
                    .environment(\.timeZone, store.countdownDay.timeZone)
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("reminderDeadlineCalendar")
            }.disabled(!enablesCountdown).opacity(enablesCountdown ? 1 : 0.46)
            if let saveError { Text(saveError).font(.footnote).foregroundStyle(.red).lineLimit(3) }
            Divider()
            HStack(spacing: 12) {
                Spacer()
                Button("取消", action: finish).keyboardShortcut(.cancelAction)
                Button(item == nil ? "添加" : "保存", action: save).keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 1000)
            }
        }
        .padding(24).frame(width: 390)
        .onAppear { DispatchQueue.main.async { focused = true } }
        .onChange(of: store.countdownDay.timeZone) { oldZone, _ in
            var oldCalendar = Calendar(identifier: .gregorian)
            oldCalendar.timeZone = oldZone
            let date = ReminderDeadline(selectedDate, calendar: oldCalendar)
            if let preserved = date.date(in: store.countdownDay.calendar) { selectedDate = preserved }
        }
    }
    private var selectedDeadline: ReminderDeadline { ReminderDeadline(selectedDate, calendar: store.countdownDay.calendar) }
    private func finish() { if let close { close() } else { dismiss() } }
    private func save() {
        let deadline = enablesCountdown ? selectedDeadline : nil
        let saved = item.map { store.edit($0.id, title: title, deadline: deadline) } ?? store.add(title, deadline: deadline)
        if saved { finish() } else {
            saveError = store.errorMessage ?? "无法保存待办，请重试。"
            store.errorMessage = nil
        }
    }
}

extension Notification.Name {
    static let newReminder = Notification.Name("ListReminder.newReminder")
    static let showWidgetSettings = Notification.Name("ListReminder.showWidgetSettings")
}
