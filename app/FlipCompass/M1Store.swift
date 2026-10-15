import Foundation

// MARK: - M1 业务逻辑（纯决策函数，可单测；写库在 View 层用 modelContext 执行）

enum M1Store {

    /// 今日完成时间 HH:mm（无记录 = nil）
    static func doneTime(of item: CheckInItem, today: Date, cal: Calendar = .current) -> String? {
        let today0 = CheckInStats.startOfDay(today, cal: cal)
        guard let rec = item.records.first(where: { $0.day == today0 }) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: rec.time)
    }

    /// 打卡决策：今日已打 → 不重复（返回已有时间）；否则给新时间与新连续数
    static func checkInDecision(
        item: CheckInItem, now: Date, cal: Calendar = .current
    ) -> (inserted: Bool, time: String, streak: Int) {
        let today0 = CheckInStats.startOfDay(now, cal: cal)
        if let rec = item.records.first(where: { $0.day == today0 }) {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return (false, f.string(from: rec.time), CheckInStats.streak(days: Set(item.records.map(\.day)), today: now, cal: cal))
        }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        let days = Set(item.records.map(\.day))
        let nextStreak = CheckInStats.streak(days: days, today: now, cal: cal) + 1
        return (true, f.string(from: now), nextStreak)
    }

    /// 统计页鼓励语（实算生成，替代原型静态文案）
    static func encourage(streak: Int) -> String {
        if streak >= 7 { return "「连续 \(streak) 天了，比上周多了一天」" }
        if streak > 0 { return "「连续 \(streak) 天，继续加油」" }
        return "「从今天的一次打卡开始」"
    }

    /// 条目管理页提示行文案（B1i：长按拖动排序 + swipe 删除）
    static let manageHint = "长按拖动排序 · 左滑行删除 · 点「编辑 ›」修改"

    // MARK: 打卡心情池（拓展优化轮：经典六心情基调 + 近期热词潮词彩蛋）

    /// 经典池（原型六心情 · 温情向基调）
    static let moodClassic = ["温暖", "感动", "平静", "想念", "开心", "安心"]

    /// 热词潮词池（正向生活向彩蛋 · 随版本更新替换；后续可换云端配置下发）
    static let moodTrendy = [
        "松弛感", "满血复活", "电量满格", "小确幸",
        "人间清醒", "元气满满", "治愈瞬间", "稳稳的幸福",
    ]

    /// 热词彩蛋触发概率（经典基调 62% / 热词 38%）
    static let moodTrendyRate = 0.38

    /// 抽取候选集：指定段先剔除上次心情（避免连抽同一个，随机更有变化感）
    static func moodCandidates(trendy: Bool, previous: String?) -> [String] {
        var pool = trendy ? moodTrendy : moodClassic
        if let prev = previous, !prev.isEmpty, pool.count > 1 {
            pool.removeAll { $0 == prev }
        }
        return pool
    }

    /// 随机抽取打卡心情（详情页 / 主屏两打卡入口统一走这里）
    static func pickMood(previous: String?) -> String {
        let candidates = moodCandidates(
            trendy: Double.random(in: 0..<1) < moodTrendyRate, previous: previous
        )
        return candidates.randomElement() ?? "安心"
    }

    /// 心情 emoji（时间线等共用地；未收录 fallback 😊）
    static let moodEmoji: [String: String] = [
        "温暖": "🤗", "感动": "🥹", "平静": "😌", "想念": "💭", "开心": "😄", "安心": "😊",
        "松弛感": "🧘", "满血复活": "💪", "电量满格": "🔋", "小确幸": "🍀",
        "人间清醒": "☕", "元气满满": "⚡", "治愈瞬间": "🌿", "稳稳的幸福": "🫶",
    ]

    /// 新打卡时间文本（toast 用 · 末尾心情揭晓，随机结果即时可见）
    static func checkInToast(title: String, streak: Int, mood: String) -> String {
        let emoji = moodEmoji[mood] ?? "😊"
        return "打卡成功 💛 \(title) 连续第 \(streak) 天 · \(emoji) \(mood)"
    }
}
