import Foundation

// MARK: - M2 业务逻辑（纯决策函数，可单测；写库在 View 层用 modelContext 执行）
// 对齐 M1Store：输入为轻量数据（[Thought] / 文本），不依赖 SwiftData 运行时。

enum M2Store {

    // MARK: 心情（原型 MOODS_M2 · 默认「心动」）

    static let moods = ["晴朗", "平静", "心动", "疲惫", "雀跃"]
    static let defaultMood = "心动"

    // MARK: 今日 / 月过滤

    static func today0(_ d: Date, cal: Calendar = .current) -> Date {
        cal.startOfDay(for: d)
    }

    static func isToday(_ d: Date, today: Date, cal: Calendar = .current) -> Bool {
        today0(d, cal: cal) == today0(today, cal: cal)
    }

    /// 日期 → 年月键 "yyyy-MM"
    static func monthKey(_ d: Date, cal: Calendar = .current) -> String {
        let c = cal.dateComponents([.year, .month], from: d)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    /// 今日想法（按时刻降序，新在前）
    static func todayThoughts(_ thoughts: [Thought], today: Date, cal: Calendar = .current) -> [Thought] {
        thoughts
            .filter { isToday($0.date, today: today, cal: cal) }
            .sorted { $0.time > $1.time }
    }

    /// 指定年月想法（按日期降序，新在前）
    static func monthThoughts(_ thoughts: [Thought], year: Int, month: Int,
                              cal: Calendar = .current) -> [Thought] {
        thoughts
            .filter { t in
                let c = cal.dateComponents([.year, .month], from: t.date)
                return c.year == year && c.month == month
            }
            .sorted { ($0.date, $0.time) > ($1.date, $1.time) }
    }

    // MARK: B2b 时间轴 · 按日分组（组间日期降序 · 组内时刻降序）

    struct DayGroup: Equatable {
        let date: Date              // 当天零时
        var thoughts: [Thought]
    }

    static func monthGroups(_ thoughts: [Thought], year: Int, month: Int,
                            cal: Calendar = .current) -> [DayGroup] {
        monthThoughts(thoughts, year: year, month: month, cal: cal)
            .reduce(into: []) { acc, t in
                if acc.last?.date == t.date {
                    acc[acc.count - 1].thoughts.append(t)
                } else {
                    acc.append(DayGroup(date: t.date, thoughts: [t]))
                }
            }
    }

    /// 时间轴日期分组标题（原型 MM-DD → 「10月12日」）
    static func dayTitle(_ d: Date, cal: Calendar = .current) -> String {
        let c = cal.dateComponents([.month, .day], from: d)
        return "\(c.month ?? 0)月\(c.day ?? 0)日"
    }

    // MARK: 头部胶囊 / 记录卡副标（R8 ③「标记看得见」）

    /// 胶囊文案（HeadChip 会拆出数值 → 数字 +「条想法」）
    static func headline(todayCount: Int) -> String { "\(todayCount) 条想法" }

    /// 记录卡副标：有草稿 →「有草稿 N 条 · 上次 MM-DD」；无 →「写一句就好 · 写一半也没关系」
    static func composeSubtitle(draftCount: Int, latestDate: Date?,
                                cal: Calendar = .current) -> String {
        if draftCount > 0, let d = latestDate {
            return "有草稿 \(draftCount) 条 · 上次 \(ThoughtFormat.mmdd(d))"
        }
        return "写一句就好 · 写一半也没关系"
    }

    // MARK: R8 ① 草稿自动落盘决策（每字 input → saveDraft）
    // 输入当前写作态文本与「最新草稿」文本；输出该轮应执行的操作。
    // 语义（对齐原型 saveDraft）：清空 → 删除最新草稿；同内容 → 不动；否则更新/新建最新草稿。

    enum DraftDecision: Equatable {
        case none
        case clear                                  // 文本清空 → 删除最新草稿
        case upsert(text: String, mood: String, date: Date, time: Date)  // 非空 → 写/更最新草稿
    }

    /// latestText/latestMood = 当前目标草稿现有内容；文本与心情都未变 → 不动
    static func draftDecision(
        currentText: String, latestDraftText: String?, latestDraftMood: String?,
        mood: String, date: Date, time: Date
    ) -> DraftDecision {
        let t = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            return latestDraftText == nil ? .none : .clear
        }
        if latestDraftText == t, latestDraftMood == mood { return .none }   // 同内容不重复插入
        return .upsert(text: t, mood: mood, date: date, time: time)
    }

    // MARK: 发布决策（收下这句 / 编辑保存）

    enum PublishDecision: Equatable {
        case empty        // 空内容拦截
        case create       // 新建想法
        case update       // 编辑态 → 覆盖原想法
    }

    static func publishDecision(text: String, isEditing: Bool) -> PublishDecision {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return .empty }
        return isEditing ? .update : .create
    }

    // MARK: 月导航（跨年正确）

    static func shiftMonth(year: Int, month: Int, by delta: Int) -> (year: Int, month: Int) {
        var m = month + delta
        var y = year
        while m > 12 { m -= 12; y += 1 }
        while m < 1 { m += 12; y -= 1 }
        return (y, m)
    }

    static func monthLabel(year: Int, month: Int) -> String { "\(year)年\(month)月" }
    static func prevLabel(month: Int) -> String { "‹ \(month)月" }
    static func nextLabel(month: Int) -> String { "\(month)月 ›" }

    /// 月视图空态文案
    static let monthEmpty = "这个月还没有想法\n翻到今天，写下第一句"
}