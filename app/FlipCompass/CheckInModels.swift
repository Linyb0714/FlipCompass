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

    /// 规则解析（每日 / 每周多选·工作日跳假 / 每月 · 向后兼容历史格式）：
    /// "" → nil
    /// "HH:mm" → 每日（首版数据兼容）
    /// "weekly|w|HH:mm" → 每周单天（第二版兼容）
    /// "weekly|w1,w2,…|HH:mm" → 每周多天（升序 CSV）
    /// "weekly|…|HH:mm|hol" → 每周 + 跳过法定假日（「工作日」）
    /// "monthly|d1,d2,…|HH:mm" → 每月多日（单日沿用 "monthly|d|HH:mm" 历史格式）
    static func parseRule(_ s: String) -> RemindRule? {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        if let r = parse(t) {
            return .daily(hour: r.hour, minute: r.minute)
        }
        let parts = t.split(separator: "|").map(String.init)
        guard (3...4).contains(parts.count), let hm = parse(parts[2]) else { return nil }
        switch parts[0] {
        case "weekly":
            let skip: Bool
            switch parts.count {
            case 3:
                skip = false
            case 4 where parts[3] == "hol":
                skip = true
            default:
                return nil   // 第 4 段只认 hol 标记
            }
            guard let ws = RemindRule.normalizeWeekdaysCSV(parts[1]) else { return nil }
            return .weekly(weekdays: ws, skipHolidays: skip, hour: hm.hour, minute: hm.minute)
        case "monthly":
            guard parts.count == 3, let ds = RemindRule.normalizeDaysCSV(parts[1]) else { return nil }
            return .monthly(days: ds, hour: hm.hour, minute: hm.minute)
        default:
            return nil
        }
    }
}

// MARK: - 打卡提醒规则（每日 / 每周多选 · 工作日跳假 / 每月 · 用户需求）

enum RemindRule: Equatable {
    case daily(hour: Int, minute: Int)
    /// weekdays：1 = 周日 … 7 = 周六（Calendar 语义）· 升序去重非空
    /// skipHolidays：命中星期若逢法定假日则当天不提醒（排期见 ChineseHoliday）
    case weekly(weekdays: [Int], skipHolidays: Bool, hour: Int, minute: Int)
    /// days：1 ~ 31 · 升序去重非空（多选）；当月无该日（如 31 号之于 4 月）该月自动跳过
    case monthly(days: [Int], hour: Int, minute: Int)

    /// 星期单字（index = weekday - 1）
    static let weekdayChars = ["日", "一", "二", "三", "四", "五", "六"]

    /// 「工作日」预设：周一 ~ 周五（Calendar 2~6）· 启用跳假
    static let workdayWeekdays = [2, 3, 4, 5, 6]
    /// 「周末」预设：周六、周日
    static let weekendWeekdays = [1, 7]

    var hour: Int {
        switch self {
        case .daily(let h, _), .weekly(_, _, let h, _), .monthly(_, let h, _): return h
        }
    }
    var minute: Int {
        switch self {
        case .daily(_, let m), .weekly(_, _, _, let m), .monthly(_, _, let m): return m
        }
    }

    /// 选中星期（非每周 → nil）
    var weekdays: [Int]? {
        if case .weekly(let ws, _, _, _) = self { return ws }
        return nil
    }
    var skipHolidays: Bool {
        if case .weekly(_, let skip, _, _) = self { return skip }
        return false
    }
    /// 是否为「工作日」预设态（周一~五 + 跳假）
    var isWorkdayPreset: Bool {
        if case .weekly(let ws, true, _, _) = self { return ws == Self.workdayWeekdays }
        return false
    }

    /// 星期集合规范化：1~7 校验 · 去重 · 升序（空 / 越界 → nil）
    static func normalizeWeekdays(_ ws: [Int]) -> [Int]? {
        guard !ws.isEmpty, ws.allSatisfy({ (1...7).contains($0) }) else { return nil }
        return Array(Set(ws)).sorted()
    }

    /// CSV "2,4,6" → [2,4,6]（空段 / 非数字 / 越界 → nil）
    static func normalizeWeekdaysCSV(_ s: String) -> [Int]? {
        let segments = s.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        let ints = segments.compactMap { Int($0) }
        guard segments.count == ints.count else { return nil }
        return normalizeWeekdays(ints)
    }

    /// 日期集合规范化：1~31 校验 · 去重 · 升序（空 / 越界 → nil）
    static func normalizeDays(_ ds: [Int]) -> [Int]? {
        guard !ds.isEmpty, ds.allSatisfy({ (1...31).contains($0) }) else { return nil }
        return Array(Set(ds)).sorted()
    }

    /// CSV "1,15" → [1,15]（空段 / 非数字 / 越界 → nil）
    static func normalizeDaysCSV(_ s: String) -> [Int]? {
        let segments = s.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        let ints = segments.compactMap { Int($0) }
        guard segments.count == ints.count else { return nil }
        return normalizeDays(ints)
    }

    /// 「工作日」预设构造（周一~五 + 跳过法定假日）
    static func workday(hour: Int, minute: Int) -> RemindRule {
        .weekly(weekdays: workdayWeekdays, skipHolidays: true, hour: hour, minute: minute)
    }

    /// 存储编码（每日沿用旧格式「HH:mm」、每周单天沿用 "weekly|w|HH:mm" 以兼容历史数据）
    var storage: String {
        let hm = String(format: "%02d:%02d", hour, minute)
        switch self {
        case .daily:
            return hm
        case .weekly(let ws, let skip, _, _):
            let csv = ws.map(String.init).joined(separator: ",")
            return skip ? "weekly|\(csv)|\(hm)|hol" : "weekly|\(csv)|\(hm)"
        case .monthly(let ds, _, _):
            return "monthly|\(ds.map(String.init).joined(separator: ","))|\(hm)"
        }
    }

    /// 展示文本（摘要行 / 详情页副题共用）
    var text: String {
        let hm = String(format: "%02d:%02d", hour, minute)
        switch self {
        case .daily:
            return "每日 \(hm)"
        case .weekly(let ws, let skip, _, _):
            if ws == Self.workdayWeekdays {
                return skip ? "工作日 \(hm)" : "每周一至五 \(hm)"
            }
            let days = Self.weekdaySummary(ws)
            return skip ? "每周\(days) \(hm)（跳假日）" : "每周\(days) \(hm)"
        case .monthly(let ds, _, _):
            return "每月 \(Self.daySummary(ds)) 日 \(hm)"
        }
    }

    /// 日期集合中文摘要：连续折叠「1至3」· 多段顿号分隔（单日 15 → "15"）
    static func daySummary(_ ds: [Int]) -> String {
        let sorted = Set(ds).sorted()
        var segments: [(start: Int, end: Int)] = []
        for d in sorted {
            if let last = segments.last, last.end == d - 1 {
                segments[segments.count - 1].end = d
            } else {
                segments.append((d, d))
            }
        }
        return segments.map { seg -> String in
            let len = seg.end - seg.start + 1
            if len == 1 { return String(seg.start) }
            if len == 2 { return "\(seg.start)、\(seg.end)" }
            return "\(seg.start)至\(seg.end)"
        }.joined(separator: "、")
    }

    /// 星期集合中文摘要：连续折叠「一至三」· 多段顿号分隔 · 惯用语特判「六日」
    static func weekdaySummary(_ ws: [Int]) -> String {
        let sorted = Set(ws).sorted()
        // 惯用语：周六+周日（Calendar 7、1）→「六日」
        if sorted == [1, 7] { return "六日" }
        // 自然序折叠连续段（不跨周环绕）
        var segments: [(start: Int, end: Int)] = []
        for w in sorted {
            if let last = segments.last, last.end == w - 1 {
                segments[segments.count - 1].end = w
            } else {
                segments.append((w, w))
            }
        }
        return segments.map { seg in
            let len = seg.end - seg.start + 1
            let s = weekdayChars[seg.start - 1], e = weekdayChars[seg.end - 1]
            if len == 1 { return s }
            if len == 2 { return "\(s)、\(e)" }
            return "\(s)至\(e)"
        }.joined(separator: "、")
    }
}
