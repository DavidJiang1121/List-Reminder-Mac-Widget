import SwiftUI

struct AchievementsView: View {
    let counts: [ReminderDeadline: Int]
    let day: ReminderDay
    @State private var selected: ReminderDeadline?
    @State private var hovered: ReminderDeadline?
    private let focusColor = Color(red: 0.15, green: 0.36, blue: 0.27)

    private static let shades: [Color] = [
        Color(red: 0.92, green: 0.94, blue: 0.92),
        Color(red: 0.74, green: 0.87, blue: 0.76),
        Color(red: 0.49, green: 0.74, blue: 0.56),
        Color(red: 0.29, green: 0.60, blue: 0.41),
        Color(red: 0.14, green: 0.43, blue: 0.29)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("完成记录", systemImage: "checkmark.seal")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Text("成就").font(.system(size: 29, weight: .semibold))
                }
                HStack(spacing: 10) {
                    metric("今日完成", value: counts[day.date, default: 0], unit: "项")
                    metric("累计完成", value: counts.values.reduce(0, +), unit: "项")
                    metric("有完成记录", value: counts.count, unit: "天")
                }
                contributionCard
            }
            .padding(.horizontal, 40).padding(.top, 43).padding(.bottom, 29)
        }
        .scrollIndicators(.hidden)
    }

    private func metric(_ title: String, value: Int, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value.formatted()).font(.system(size: 30, weight: .light, design: .rounded)).monospacedDigit()
                Text(unit).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.black.opacity(0.06)))
        .accessibilityElement(children: .combine)
    }

    private var contributionCard: some View {
        let grid = AchievementGrid(day: day)
        let current = hovered ?? selected ?? day.date
        return VStack(alignment: .leading, spacing: 17) {
            HStack {
                Text("每日完成").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("过去 365 天").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            ViewThatFits(in: .horizontal) {
                chart(grid)
                ScrollView(.horizontal) { chart(grid) }.scrollIndicators(.hidden)
            }
            HStack {
                Text(verbatim: "\(current.year) 年 \(current.month) 月 \(current.day) 日 · 完成 \(counts[current, default: 0]) 项")
                    .font(.system(size: 11, weight: .medium)).monospacedDigit()
                    .accessibilityIdentifier("achievementDayDetail")
                Spacer()
                HStack(spacing: 4) {
                    Text("少").padding(.trailing, 2)
                    ForEach(Self.shades.indices, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2).fill(Self.shades[level]).frame(width: 9, height: 9)
                    }
                    Text("多").padding(.leading, 2)
                }.font(.system(size: 10)).foregroundStyle(.secondary).accessibilityHidden(true)
            }
        }
        .padding(18).background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06)))
    }

    private func chart(_ grid: AchievementGrid) -> some View {
        let size: CGFloat = 8
        let gap: CGFloat = 2
        return VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .leading) {
                Color.clear.frame(width: CGFloat(grid.weeks.count) * (size + gap) - gap, height: 14)
                ForEach(grid.monthLabels, id: \.column) { mark in
                    Text("\(mark.month)月").font(.system(size: 9)).foregroundStyle(.secondary)
                        .offset(x: CGFloat(min(mark.column, max(0, grid.weeks.count - 2))) * (size + gap))
                }
            }.padding(.leading, 24).accessibilityHidden(true)
            HStack(spacing: gap) {
                VStack(spacing: gap) {
                    ForEach(0..<7) { index in
                        Text([0: "周一", 2: "周三", 4: "周五"][index] ?? "")
                            .font(.system(size: 8)).foregroundStyle(.secondary)
                            .frame(width: 22, height: size, alignment: .leading)
                    }
                }.accessibilityHidden(true)
                ForEach(grid.weeks.indices, id: \.self) { index in
                    VStack(spacing: gap) {
                        ForEach(0..<7) { weekday in
                            if let date = grid.weeks[index][weekday] { cell(date, size: size) }
                            else { Color.clear.frame(width: size, height: size).accessibilityHidden(true) }
                        }
                    }
                }
            }
        }.fixedSize(horizontal: true, vertical: true)
    }

    private func cell(_ date: ReminderDeadline, size: CGFloat) -> some View {
        let count = counts[date, default: 0]
        let level = count == 0 ? 0 : count == 1 ? 1 : count <= 3 ? 2 : count <= 6 ? 3 : 4
        let highlighted = date == (hovered ?? selected ?? day.date)
        let label = "\(date.year) 年 \(date.month) 月 \(date.day) 日，完成 \(count) 项"
        return Button { selected = date } label: {
            RoundedRectangle(cornerRadius: 2).fill(Self.shades[level])
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(highlighted ? focusColor : .clear))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .help(label)
        .onHover { inside in
            if inside { hovered = date }
            else if hovered == date { hovered = nil }
        }
        .accessibilityLabel(label)
    }
}

private struct AchievementGrid {
    var weeks: [[ReminderDeadline?]] = []
    var monthLabels: [(column: Int, month: Int)] = []

    init(day: ReminderDay) {
        let calendar = day.calendar
        guard let end = day.date.date(in: calendar),
              let start = calendar.date(byAdding: .day, value: -364, to: end) else { return }
        let leading = (calendar.component(.weekday, from: start) + 5) % 7
        let columnCount = (leading + 365 + 6) / 7
        weeks = Array(repeating: Array(repeating: nil, count: 7), count: columnCount)
        var lastMonth: Int?
        for offset in 0..<365 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let civilDate = ReminderDeadline(date, calendar: calendar)
            let column = (offset + leading) / 7
            weeks[column][(offset + leading) % 7] = civilDate
            if civilDate.month != lastMonth {
                lastMonth = civilDate.month
                if monthLabels.last.map({ column - $0.column >= 3 }) ?? true {
                    monthLabels.append((column: column, month: civilDate.month))
                }
            }
        }
    }
}
