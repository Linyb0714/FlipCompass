import Foundation

// MARK: - M4 业务逻辑（纯决策函数，可单测；全部由 GameProgress 实算）

enum M4Store {

    static let starMax = 3

    // MARK: 通用

    static func startOfDay(_ d: Date, cal: Calendar = .current) -> Date {
        cal.startOfDay(for: d)
    }

    // MARK: 今日局数（p0 战绩卡）

    static func todayCount(_ records: [GameProgress], today: Date, cal: Calendar = .current) -> Int {
        let t0 = startOfDay(today, cal: cal)
        return records.filter { $0.day == t0 }.count
    }

    // MARK: 连续天数（温情语义：今天还没玩不断连，从昨天起算进行中连续）

    static func streakDays(_ records: [GameProgress], today: Date, cal: Calendar = .current) -> Int {
        let t0 = startOfDay(today, cal: cal)
        let days = Set(records.map(\.day))
        var cursor = days.contains(t0) ? t0 : (cal.date(byAdding: .day, value: -1, to: t0) ?? t0)
        var n = 0
        while days.contains(cursor) {
            n += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return n
    }

    // MARK: 星星统计（头部胶囊 / 勋章）

    static func threeStarCount(_ records: [GameProgress]) -> Int {
        records.filter { $0.stars == starMax }.count
    }

    static func totalStars(_ records: [GameProgress]) -> Int {
        records.reduce(0) { $0 + $1.stars }
    }

    static func maxStar(_ records: [GameProgress]) -> Int {
        records.map(\.stars).max() ?? 0
    }

    /// 头部胶囊（原型 updateM4Stats：「三星 N 局」实算）
    static func headline(threeStar: Int) -> (text: String, value: Int) {
        ("三星 \(threeStar) 局", threeStar)
    }

    // MARK: 勋章进度（解锁判定实算，不用硬编码 on）

    static func badgeProgress(_ badge: BadgeDef, records: [GameProgress],
                              streak: Int) -> (cur: Int, need: Int) {
        switch badge.kind {
        case .plays: return (records.count, badge.need)
        case .streak: return (streak, badge.need)
        case .maxstar: return (maxStar(records), badge.need)
        }
    }

    static func badgeUnlocked(_ badge: BadgeDef, records: [GameProgress],
                              streak: Int) -> Bool {
        let p = badgeProgress(badge, records: records, streak: streak)
        return p.cur >= p.need
    }

    // MARK: p0 文案

    /// 战绩卡副标（有战绩「点按看全部战绩」/ 无「今天还没开局 · 来一局」）
    static func todayStatSub(_ n: Int) -> String {
        n > 0 ? "点按看全部战绩" : "今天还没开局 · 来一局"
    }

    /// 连胜卡副标（剩 0 = 已解锁「七日之约」）
    static func streakStatSub(_ streak: Int, need: Int = 7) -> String {
        let left = max(0, need - streak)
        return left == 0 ? "「七日之约」已解锁 ✦" : "再连 \(left) 天解锁「七日之约」"
    }
}
