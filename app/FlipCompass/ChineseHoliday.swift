import Foundation

// MARK: - 内置中国法定节假日表（离线 · M1「工作日 · 跳过假日」排期依据）
//
// 数据源：国务院办公厅《关于 2026 年部分节假日安排的通知》（国办发明电〔2025〕7 号）。
// 只收录「放假」日期；调休补班的上班日无需收录——跳假排期只做减法（假日当天不提醒），
// 不做补班日增提醒（未选中的星期不会被补上，语义自洽）。
// 维护：每年 11~12 月国务院公布次年安排后随 App 版本更新补表；
// 无数据年份 isOffDay 恒 false → 自动降级为「只按所选星期排期」，不会漏提醒。

enum ChineseHoliday {
    /// 2026 年放假日（33 天 · 元旦 3 + 春节 9 + 清明 3 + 劳动 5 + 端午 3 + 中秋 3 + 国庆 7）
    static let offDays2026: Set<String> = [
        // 元旦（1/1 周四 ~ 1/3 周六）
        "2026-01-01", "2026-01-02", "2026-01-03",
        // 春节（2/15 周日 ~ 2/23 周一 · 腊月廿八至正月初七）
        "2026-02-15", "2026-02-16", "2026-02-17", "2026-02-18", "2026-02-19",
        "2026-02-20", "2026-02-21", "2026-02-22", "2026-02-23",
        // 清明节（4/4 周六 ~ 4/6 周一）
        "2026-04-04", "2026-04-05", "2026-04-06",
        // 劳动节（5/1 周五 ~ 5/5 周二）
        "2026-05-01", "2026-05-02", "2026-05-03", "2026-05-04", "2026-05-05",
        // 端午节（6/19 周五 ~ 6/21 周日）
        "2026-06-19", "2026-06-20", "2026-06-21",
        // 中秋节（9/25 周五 ~ 9/27 周日）
        "2026-09-25", "2026-09-26", "2026-09-27",
        // 国庆节（10/1 周四 ~ 10/7 周三）
        "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04",
        "2026-10-05", "2026-10-06", "2026-10-07",
    ]

    /// date 是否法定放假日（无数据年份恒 false → 不跳过任何日子）
    static func isOffDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        offDays2026.contains(dayKey(date, calendar: calendar))
    }

    /// 「跳过法定假日」版每周排期（纯函数）：
    /// 自 now 起逐日向未来扫描（当日触发时刻已过则该日不计，从命中的下一日起算），
    /// 命中「星期 ∈ weekdays 且非放假日」即合成当天的触发时刻（hour:minute），
    /// 至多 limit 个；扫描窗口上限 400 天（防数据缺失年空转）。
    static func upcomingSkipHolidayTriggers(
        weekdays: [Int],
        hour: Int,
        minute: Int,
        from now: Date,
        limit: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        let set = Set(weekdays)
        guard !set.isEmpty, limit > 0 else { return [] }
        var day = calendar.startOfDay(for: now)
        var results: [Date] = []
        for _ in 0..<400 {
            let weekday = calendar.component(.weekday, from: day)
            if set.contains(weekday), !isOffDay(day, calendar: calendar),
               let trigger = calendar.date(
                   bySettingHour: hour, minute: minute, second: 0, of: day
               ), trigger > now {
                results.append(trigger)
                if results.count >= limit { break }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return results
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
