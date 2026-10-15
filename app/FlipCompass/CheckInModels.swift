import Foundation
import SwiftData

// MARK: - M1 SwiftData 模型（V0.4.1 架构：CheckInItem + CheckInRecord 两实体）
// item = 打卡条目（标题/描述/提醒时间）；record = 一次打卡（按日聚合， streak/热力/周条的统计源）。
// 今日 done = 今天存在 record；删除 item 级联删除记录。

@Model
final class CheckInItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var itemDesc: String
    /// 每日提醒时间 "HH:mm"；空串 = 不提醒
    var remind: String
    /// 排序序号（手动排序，越小越前）
    var sortOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CheckInRecord.item)
    var records: [CheckInRecord]

    init(
        id: UUID = UUID(),
        title: String,
        itemDesc: String = "",
        remind: String = "",
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.itemDesc = itemDesc
        self.remind = remind
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.records = []
    }
}

@Model
final class CheckInRecord {
    @Attribute(.unique) var id: UUID
    /// 聚合键：当天零时（Calendar.startOfDay）
    var day: Date
    /// 打卡时刻（列表完成时间 HH:mm 展示源）
    var time: Date
    /// C1：打卡时心情（温暖/感动/平静/想念/开心/安心 · 原型 MOOD_EMOJI；历史数据默认空串）
    var mood: String
    var item: CheckInItem?

    init(id: UUID = UUID(), day: Date, time: Date, mood: String = "", item: CheckInItem? = nil) {
        self.id = id
        self.day = day
        self.time = time
        self.mood = mood
        self.item = item
    }
}

// MARK: - M1 统计纯函数（原型 updateM1Stats / renderHeat / buildWeekStrip 的真机实算版）
// 输入为轻量日期集合，不依赖 SwiftData 运行时 → 单测直接覆盖。

enum CheckInStats {

    /// 日历条单格状态（原型 .ws-cell：hit ≥45% / miss ≤5% / 其余 plain）
    enum DayCellState: Equatable {
        case hit, miss, plain
    }

    /// 周条单格数据
    struct DayCell: Equatable {
        let date: Date          // 当天零时
        let state: DayCellState
        let isToday: Bool
    }

    // MARK: 通用

    static func startOfDay(_ d: Date, cal: Calendar = .current) -> Date {
        cal.startOfDay(for: d)
    }

    /// 单条目打卡日集合 → 连续天数（温情语义：今天未打不断连，从昨天起算进行中连续）
    static func streak(days: Set<Date>, today: Date, cal: Calendar = .current) -> Int {
        let today0 = startOfDay(today, cal: cal)
        var cursor = days.contains(today0) ? today0 : (cal.date(byAdding: .day, value: -1, to: today0) ?? today0)
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// 全部条目最大连续天数（头部胶囊「连续 N 天」）
    static func maxStreak(itemDays: [Set<Date>], today: Date, cal: Calendar = .current) -> Int {
        itemDays.map { streak(days: $0, today: today, cal: cal) }.max() ?? 0
    }

    /// 今日完成数 / 总条目数（统计卡「N/M」）
    static func todayCount(itemDays: [Set<Date>], today: Date, cal: Calendar = .current) -> (done: Int, total: Int) {
        let today0 = startOfDay(today, cal: cal)
        let done = itemDays.filter { $0.contains(today0) }.count
        return (done, itemDays.count)
    }

    /// 本周打卡总次数（自然周：周一起算，含今天）
    static func weekCount(dayCounts: [Date: Int], today: Date, cal: Calendar = .current) -> Int {
        let today0 = startOfDay(today, cal: cal)
        let weekday = (cal.component(.weekday, from: today0) + 6) % 7   // 周日=0 → 周一起始偏移
        let weekStart = cal.date(byAdding: .day, value: -weekday, to: today0) ?? today0
        return (0...weekday).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
            .reduce(0) { $0 + (dayCounts[$1] ?? 0) }
    }

    // MARK: 周条（近 21 天日历条）与热力图（近 6 周×7）

    /// 近 N 天的日完成率序列（末位 = 今天；ratio = 当日打卡数/条目总数，无条目 = 0）
    static func dailyRatios(daysAgo: Int, dayCounts: [Date: Int], total: Int,
                            today: Date, cal: Calendar = .current) -> [Double] {
        guard daysAgo > 0 else { return [] }
        let today0 = startOfDay(today, cal: cal)
        return (0..<daysAgo).reversed().compactMap { off -> Double? in
            guard let d = cal.date(byAdding: .day, value: -off, to: today0) else { return nil }
            let c = dayCounts[d] ?? 0
            return total > 0 ? Double(c) / Double(total) : 0
        }
    }

    /// 周条单格序列（原型 buildWeekStrip：近 21 天，末位今天）
    static func strip(daysAgo: Int = 21, dayCounts: [Date: Int], total: Int,
                      today: Date, cal: Calendar = .current) -> [DayCell] {
        dailyRatios(daysAgo: daysAgo, dayCounts: dayCounts, total: total, today: today, cal: cal)
            .enumerated().map { idx, ratio in
                let off = idx - (daysAgo - 1)                       // 0 = 今天
                let date = cal.date(byAdding: .day, value: off, to: startOfDay(today, cal: cal)) ?? today
                let state: DayCellState = total == 0
                    ? .plain
                    : (ratio >= 0.45 ? .hit : (ratio <= 0.05 ? .miss : .plain))
                return DayCell(date: date, state: state, isToday: off == 0)
            }
    }

    /// 热力图 42 格（近 6 周×7，原型 --a 透明度 = 完成率）
    static func heat(daysAgo: Int = 42, dayCounts: [Date: Int], total: Int,
                     today: Date, cal: Calendar = .current) -> [Double] {
        dailyRatios(daysAgo: daysAgo, dayCounts: dayCounts, total: total, today: today, cal: cal)
    }

    // MARK: C1 d1 · 本月分布月历（7 列；橙点深浅=已打 红环=遗漏 今天描边 未来/前后空格=无样式）

    enum CalCell: Equatable {
        case blank                                    // 月初对齐空格
        case future                                   // 未来日期（弱数字）
        case hit(alpha: Double)                       // 已打卡（0.25~0.92 深浅无意义，历史单打卡恒一亮）
        case miss                                     // 过去未打（红环）
        case today(hasHit: Bool)                      // 今天（橙描边；无打卡可点大✓）
    }

    /// 本月 7 列网格：先 blank 对齐星期，再逐日判定（原型 renderCal 规则）
    static func monthCalendar(days: Set<Date>, today: Date, cal: Calendar = .current) -> [CalCell] {
        let today0 = startOfDay(today, cal: cal)
        let comps = cal.dateComponents([.year, .month], from: today0)
        guard let monthStart = cal.date(from: comps),
              let monthLen = cal.range(of: .day, in: .month, for: monthStart)?.count
        else { return [] }
        let firstWd = cal.component(.weekday, from: monthStart)
        var cells: [CalCell] = Array(repeating: .blank, count: firstWd - 1)
        for d in 1...monthLen {
            guard let date = cal.date(byAdding: .day, value: d - 1, to: monthStart) else { continue }
            if date > today0 {
                cells.append(.future)
            } else if date == today0 {
                cells.append(.today(hasHit: days.contains(date)))
            } else if days.contains(date) {
                cells.append(.hit(alpha: 0.9))
            } else {
                cells.append(.miss)
            }
        }
        return cells
    }

    // MARK: C1 d1 · 心情时间线（最近 N 次打卡按时刻降序）

    static func recentRecords(_ records: [CheckInRecord], limit: Int = 6) -> [CheckInRecord] {
        Array(records.sorted { $0.time > $1.time }.prefix(limit))
    }
}

// MARK: - 提醒时间解析（"21:00" → UNCalendarNotificationTrigger 组件）

enum CheckInRemind {
    /// "HH:mm" → (hour, minute)；空串/「不提醒」→ nil
    static func parse(_ s: String) -> (hour: Int, minute: Int)? {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.count == 5, t.dropFirst(2).first == ":" else { return nil }
        let parts = t.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return nil }
        return (h, m)
    }
}
