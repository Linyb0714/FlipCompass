import XCTest
@testable import FlipCompass

// MARK: - 内置节假日表与「工作日跳假」排期单测
// 2026 数据依据：国务院办公厅《关于 2026 年部分节假日安排的通知》（国办发明电〔2025〕7 号）

final class ChineseHolidayTests: XCTestCase {

    /// 固定 Asia/Shanghai 日历（与中国用户真机一致，测试不随系统时区漂移）
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }

    private func d(_ y: Int, _ mo: Int, _ day: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: day, hour: h, minute: mi))!
    }

    private func dayKey(_ date: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: 2026 内置数据

    func testOffDays2026Count() {
        // 元旦 3 + 春节 9 + 清明 3 + 劳动 5 + 端午 3 + 中秋 3 + 国庆 7
        XCTAssertEqual(ChineseHoliday.offDays2026.count, 33)
    }

    func testIsOffDay_2026Holidays() {
        // 元旦（1/1~1/3；1/4 周日为调休上班日）
        XCTAssertTrue(ChineseHoliday.isOffDay(d(2026, 1, 1), calendar: cal))
        XCTAssertTrue(ChineseHoliday.isOffDay(d(2026, 1, 3), calendar: cal))
        XCTAssertFalse(ChineseHoliday.isOffDay(d(2026, 1, 4), calendar: cal))
        // 春节（2/15~2/23；2/14、2/28 周六为调休上班日）
        XCTAssertTrue(ChineseHoliday.isOffDay(d(2026, 2, 15), calendar: cal))
        XCTAssertTrue(ChineseHoliday.isOffDay(d(2026, 2, 23), calendar: cal))
        XCTAssertFalse(ChineseHoliday.isOffDay(d(2026, 2, 24), calendar: cal))
        XCTAssertFalse(ChineseHoliday.isOffDay(d(2026, 2, 14), calendar: cal))
        // 清明 / 端午 / 中秋
        XCTAssertTrue(ChineseHoliday.isOffDay(d(2026, 4, 6), calendar: cal))
        XCTAssertFalse(ChineseHoliday.isOffDay(d(2026, 4, 7), calendar: cal))
        XCTAssertTrue(ChineseHoliday.isOffDay(d(2026, 6, 21), calendar: cal))
        XCTAssertTrue(ChineseHoliday.isOffDay(d(2026, 9, 25), calendar: cal))
        // 国庆（10/1~10/7）
        XCTAssertTrue(ChineseHoliday.isOffDay(d(2026, 10, 1), calendar: cal))
        XCTAssertTrue(ChineseHoliday.isOffDay(d(2026, 10, 7), calendar: cal))
        XCTAssertFalse(ChineseHoliday.isOffDay(d(2026, 10, 8), calendar: cal))
        // 普通工作日
        XCTAssertFalse(ChineseHoliday.isOffDay(d(2026, 3, 2), calendar: cal))
    }

    func testIsOffDay_NoDataYearDegrades() {
        // 2025 / 2027 无内置数据：降级为「不跳过」（只按星期排期，不会漏提醒）
        XCTAssertFalse(ChineseHoliday.isOffDay(d(2025, 12, 31), calendar: cal))
        XCTAssertFalse(ChineseHoliday.isOffDay(d(2027, 1, 1), calendar: cal))
    }

    // MARK: 跳假排期（upcomingSkipHolidayTriggers）

    func testTriggers_SkipNationalDayWeek() {
        // 2026-09-28 周一 10:00 · 工作日 20:00 · 国庆 10/1~10/7 全部跳过
        let now = d(2026, 9, 28, 10, 0)
        let triggers = ChineseHoliday.upcomingSkipHolidayTriggers(
            weekdays: RemindRule.workdayWeekdays, hour: 20, minute: 0,
            from: now, limit: 8, calendar: cal
        )
        XCTAssertEqual(triggers.count, 8)
        let days = triggers.map { dayKey($0) }
        // 9/28（一）29（二）30（三）→ 国庆整周跳过 → 10/8（四）9（五）12（一）13（二）14（三）
        XCTAssertEqual(Array(days.prefix(3)), ["2026-09-28", "2026-09-29", "2026-09-30"])
        XCTAssertEqual(Array(days.dropFirst(3).prefix(2)), ["2026-10-08", "2026-10-09"])
        XCTAssertEqual(days.last, "2026-10-14")
        // 全部命中周一至周五且时刻为 20:00
        for t in triggers {
            let wd = cal.component(.weekday, from: t)
            XCTAssertTrue((2...6).contains(wd), "非工作日命中：\(t)")
            XCTAssertEqual(cal.component(.hour, from: t), 20)
            XCTAssertEqual(cal.component(.minute, from: t), 0)
        }
    }

    func testTriggers_CurrentDayPastTimeDeferToNextDay() {
        // 周一 21:00 已过 20:00 触发时刻 → 当日不排，首个 = 次日周二 9/29
        let now = d(2026, 9, 28, 21, 0)
        let triggers = ChineseHoliday.upcomingSkipHolidayTriggers(
            weekdays: [3], hour: 20, minute: 0, from: now, limit: 3, calendar: cal
        )
        XCTAssertEqual(dayKey(triggers[0]), "2026-09-29")
        // 恰好等于触发时刻也不触发（严格 > now）：周一 20:00 整点 → 当日不排；
        // 下一周一 10/5 逢国庆跳过 → 10/12
        let exact = d(2026, 9, 28, 20, 0)
        let t2 = ChineseHoliday.upcomingSkipHolidayTriggers(
            weekdays: [2], hour: 20, minute: 0, from: exact, limit: 1, calendar: cal
        )
        XCTAssertEqual(dayKey(t2[0]), "2026-10-12")
    }

    func testTriggers_YearEndBoundary() {
        // 2025-12-31（周三，2025 无数据不跳）→ 元旦 1/1（四）1/2（五）为假日 → 1/5 起恢复
        let now = d(2025, 12, 31, 10, 0)
        let triggers = ChineseHoliday.upcomingSkipHolidayTriggers(
            weekdays: RemindRule.workdayWeekdays, hour: 20, minute: 0,
            from: now, limit: 6, calendar: cal
        )
        let days = triggers.map { dayKey($0) }
        XCTAssertEqual(days, [
            "2025-12-31", "2026-01-05", "2026-01-06",
            "2026-01-07", "2026-01-08", "2026-01-09",
        ])
    }

    func testTriggers_SpringFestivalNineDays() {
        // 春节 2/15~2/23 共 9 天横跨两个工作周
        let now = d(2026, 2, 9, 10, 0)   // 2/9 周一
        let triggers = ChineseHoliday.upcomingSkipHolidayTriggers(
            weekdays: RemindRule.workdayWeekdays, hour: 20, minute: 0,
            from: now, limit: 8, calendar: cal
        )
        let days = triggers.map { dayKey($0) }
        XCTAssertEqual(days, [
            "2026-02-09", "2026-02-10", "2026-02-11", "2026-02-12", "2026-02-13",   // 假期前一周
            "2026-02-24", "2026-02-25", "2026-02-26",                                // 假期后（2/23 周一仍是假日）
        ])
    }

    func testTriggers_EdgeInputs() {
        let now = d(2026, 10, 10, 10, 0)
        XCTAssertTrue(ChineseHoliday.upcomingSkipHolidayTriggers(
            weekdays: [], hour: 20, minute: 0, from: now, limit: 5, calendar: cal
        ).isEmpty)
        XCTAssertTrue(ChineseHoliday.upcomingSkipHolidayTriggers(
            weekdays: [2], hour: 20, minute: 0, from: now, limit: 0, calendar: cal
        ).isEmpty)
        XCTAssertTrue(ChineseHoliday.upcomingSkipHolidayTriggers(
            weekdays: [2], hour: 20, minute: 0, from: now, limit: -1, calendar: cal
        ).isEmpty)
    }
}
