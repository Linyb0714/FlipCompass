import SwiftUI
import SwiftData

/// 打卡详情 d1（V0.4.1 ② 重写）
/// 标题/描述 → 今日打卡状态 → 本月月历分布（橙点已打/红环遗漏/今日描边）→ 心情时间线
struct CheckInDetailView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext
    let itemID: String?
    @State private var item: CheckInItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let item {
                    VStack(alignment: .leading, spacing: 21) {
                        headerSection(item)
                        statusSection(item)
                        monthCalendar(item)
                        moodTimeline(item)
                    }
                    .padding(14)
                } else {
                    Text("条目不存在").font(.headline).padding()
                }
            }
            .navigationTitle("打卡详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("返回") { state.backOneLevel() }
                }
            }
        }
        .task { await loadItem() }
    }

    private func loadItem() async {
        guard let id = itemID.flatMap(UUID.init(uuidString:)) else { return }
        let desc = FetchDescriptor<CheckInItem>(predicate: #Predicate { $0.id == id })
        item = try? modelContext.fetch(desc).first
    }

    private func headerSection(_ item: CheckInItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
            if !item.desc.isEmpty {
                Text(item.desc)
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.inkSecondary)
            }
            if let h = item.remindHour, let m = item.remindMinute {
                Text("提醒 \(String(format: "%02d", h)):\(String(format: "%02d", m))")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.m1Orange)
                    .padding(.top, 2)
            }
        }
    }

    @MainActor
    private func statusSection(_ item: CheckInItem) -> some View {
        let cal = Calendar.current
        let doneToday = item.records.contains { cal.isDateInToday($0.doneAt) }
        let provider = CheckInProvider(context: modelContext)
        let streak = provider.streak(of: item)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("今日")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.inkSecondary)
                Text(doneToday ? "已打卡" : "未完成")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(doneToday ? DesignTokens.success : DesignTokens.error)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("连续")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.inkSecondary)
                Text("\(streak) 天")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignTokens.m1Orange)
            }
        }
        .padding(14)
        .glassCard(moduleColor: DesignTokens.m1Orange, selected: false)
    }

    private func monthCalendar(_ item: CheckInItem) -> some View {
        let cal = Calendar.current
        let days = monthDays(item: item, cal: cal)
        return VStack(alignment: .leading, spacing: 7) {
            Text("本月分布")
                .font(.system(size: 15, weight: .semibold))
            let cols = Array(repeating: GridItem(.flexible()), count: 7)
            LazyVGrid(columns: cols, spacing: 7) {
                ForEach(Array(days.enumerated()), id: \.0) { _, day in
                    cell(day: day, today: cal.isDateInToday(Date()))
                }
            }
        }
    }

    private struct DayCell {
        let date: Date?
        let done: Bool
        let isToday: Bool
    }

    private func monthDays(item: CheckInItem, cal: Calendar) -> [DayCell] {
        let range = cal.range(of: .day, in: .month, for: .now) ?? 1..<29
        let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: .now))!
        let weekday = cal.component(.weekday, from: firstOfMonth)
        var cells: [DayCell] = []
        for _ in 1..<weekday { cells.append(DayCell(date: nil, done: false, isToday: false)) }
        let doneDays = Set(item.records.map { cal.startOfDay(for: $0.doneAt) })
        for day in range {
            let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth)!
            cells.append(DayCell(
                date: date,
                done: doneDays.contains(cal.startOfDay(for: date)),
                isToday: cal.isDateInToday(date)
            ))
        }
        return cells
    }

    private func cell(day: DayCell, today: Bool) -> some View {
        ZStack {
            if let _ = day.date {
                if day.done {
                    Circle().fill(DesignTokens.m1Orange).frame(width: 24, height: 24)
                } else if !day.isToday {
                    Circle().stroke(DesignTokens.error.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                }
                if day.isToday {
                    Circle().stroke(DesignTokens.m1Orange, lineWidth: 2)
                        .frame(width: 28, height: 28)
                }
                Text("\(cal.component(.day, from: day.date!))")
                    .font(.system(size: 11, weight: day.isToday ? .bold : .regular))
                    .foregroundStyle(day.done ? Color.white : DesignTokens.inkSecondary)
            } else {
                Color.clear.frame(height: 24)
            }
        }
        .frame(height: 32)
    }

    private var cal: Calendar { Calendar.current }

    @ViewBuilder
    private func moodTimeline(_ item: CheckInItem) -> some View {
        let sorted = item.records.sorted { $0.doneAt > $1.doneAt }
        VStack(alignment: .leading, spacing: 7) {
            Text("心情时间线")
                .font(.system(size: 15, weight: .semibold))
            if sorted.isEmpty {
                Text("还没有记录").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(sorted.prefix(20), id: \.id) { r in
                    HStack(spacing: 10) {
                        Text(r.mood ?? "📝")
                            .font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.doneAt, format: .dateTime.month().day())
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DesignTokens.ink)
                            Text(r.doneAt, format: .dateTime.hour().minute())
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(DesignTokens.inkSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .glassCard(moduleColor: DesignTokens.m1Orange, selected: false)
                }
            }
        }
    }
}
