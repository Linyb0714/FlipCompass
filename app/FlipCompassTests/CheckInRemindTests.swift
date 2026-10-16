import XCTest
@testable import FlipCompass

// MARK: - 提醒规则单测（每日 / 每周多选·工作日跳假 / 每月 · 解析 / 编码 / 文案 / 历史格式兼容）

final class CheckInRemindTests: XCTestCase {

    // MARK: parseRule 各格式

    func testParseRule_Empty() {
        XCTAssertNil(CheckInRemind.parseRule(""))
        XCTAssertNil(CheckInRemind.parseRule("   "))
    }

    func testParseRule_DailyCompat() {
        // 旧格式 "HH:mm" 视为每日（历史数据兼容）
        XCTAssertEqual(CheckInRemind.parseRule("20:00"), .daily(hour: 20, minute: 0))
        XCTAssertEqual(CheckInRemind.parseRule("07:30"), .daily(hour: 7, minute: 30))
    }

    func testParseRule_WeeklySingleCompat() {
        // 第二版单天格式（历史数据兼容）→ 单元素集合
        XCTAssertEqual(
            CheckInRemind.parseRule("weekly|2|20:00"),
            .weekly(weekdays: [2], skipHolidays: false, hour: 20, minute: 0)
        )
        XCTAssertEqual(
            CheckInRemind.parseRule("weekly|7|09:05"),
            .weekly(weekdays: [7], skipHolidays: false, hour: 9, minute: 5)
        )
    }

    func testParseRule_WeeklyMulti() {
        XCTAssertEqual(
            CheckInRemind.parseRule("weekly|2,4,6|20:00"),
            .weekly(weekdays: [2, 4, 6], skipHolidays: false, hour: 20, minute: 0)
        )
        // 乱序输入 → 规范化升序
        XCTAssertEqual(
            CheckInRemind.parseRule("weekly|6,2,4|09:05"),
            .weekly(weekdays: [2, 4, 6], skipHolidays: false, hour: 9, minute: 5)
        )
        // 重复输入 → 去重
        XCTAssertEqual(
            CheckInRemind.parseRule("weekly|3,3,5|20:00"),
            .weekly(weekdays: [3, 5], skipHolidays: false, hour: 20, minute: 0)
        )
    }

    func testParseRule_WeeklySkipHoliday() {
        XCTAssertEqual(
            CheckInRemind.parseRule("weekly|2,3,4,5,6|20:00|hol"),
            .weekly(weekdays: [2, 3, 4, 5, 6], skipHolidays: true, hour: 20, minute: 0)
        )
        XCTAssertEqual(
            CheckInRemind.parseRule("weekly|1,7|09:05|hol"),
            .weekly(weekdays: [1, 7], skipHolidays: true, hour: 9, minute: 5)
        )
    }

    func testParseRule_Monthly() {
        // 单日沿用历史格式
        XCTAssertEqual(CheckInRemind.parseRule("monthly|1|08:00"), .monthly(days: [1], hour: 8, minute: 0))
        XCTAssertEqual(CheckInRemind.parseRule("monthly|31|23:59"), .monthly(days: [31], hour: 23, minute: 59))
        // 多日 CSV（升序规范化 / 去重）
        XCTAssertEqual(CheckInRemind.parseRule("monthly|1,15|08:30"), .monthly(days: [1, 15], hour: 8, minute: 30))
        XCTAssertEqual(CheckInRemind.parseRule("monthly|15,1,15|08:30"), .monthly(days: [1, 15], hour: 8, minute: 30))
    }

    // MARK: 非法输入

    func testParseRule_Invalid() {
        XCTAssertNil(CheckInRemind.parseRule("abc"))
        XCTAssertNil(CheckInRemind.parseRule("weekly|9|20:00"))        // weekday 越界（1~7）
        XCTAssertNil(CheckInRemind.parseRule("weekly|0|20:00"))
        XCTAssertNil(CheckInRemind.parseRule("weekly|x|20:00"))
        XCTAssertNil(CheckInRemind.parseRule("weekly|2,9|20:00"))      // 多选中混入越界值
        XCTAssertNil(CheckInRemind.parseRule("weekly|2,,6|20:00"))     // 空段
        XCTAssertNil(CheckInRemind.parseRule("weekly||20:00"))         // 空集合
        XCTAssertNil(CheckInRemind.parseRule("weekly|2|20:00|x"))      // 第 4 段只认 hol
        XCTAssertNil(CheckInRemind.parseRule("weekly|2|20:00|HOL"))    // 大小写敏感
        XCTAssertNil(CheckInRemind.parseRule("monthly|0|20:00"))       // day 越界（1~31）
        XCTAssertNil(CheckInRemind.parseRule("monthly|32|20:00"))
        XCTAssertNil(CheckInRemind.parseRule("monthly|10|20:00|hol"))  // monthly 不带第 4 段
        XCTAssertNil(CheckInRemind.parseRule("monthly|0,5|20:00"))     // 多日混入越界值
        XCTAssertNil(CheckInRemind.parseRule("monthly|1,32|20:00"))
        XCTAssertNil(CheckInRemind.parseRule("monthly|1,,7|20:00"))    // 空段
        XCTAssertNil(CheckInRemind.parseRule("monthly|x,7|20:00"))     // 非数字
        XCTAssertNil(CheckInRemind.parseRule("weekly|2|25:00"))        // 时越界
        XCTAssertNil(CheckInRemind.parseRule("yearly|2|20:00"))        // 未知类型
        XCTAssertNil(CheckInRemind.parseRule("weekly|2"))              // 缺段
    }

    // MARK: 编码 ⇄ 解析往返

    func testStorageRoundTrip() {
        let rules: [RemindRule] = [
            .daily(hour: 20, minute: 0),
            .weekly(weekdays: [2], skipHolidays: false, hour: 7, minute: 30),
            .weekly(weekdays: [1, 3, 5], skipHolidays: false, hour: 20, minute: 0),
            .weekly(weekdays: [2, 3, 4, 5, 6], skipHolidays: true, hour: 20, minute: 0),
            .weekly(weekdays: [1, 7], skipHolidays: true, hour: 9, minute: 5),
            .monthly(days: [15], hour: 9, minute: 0),
            .monthly(days: [1, 15], hour: 9, minute: 0),
            .monthly(days: [28, 29, 30, 31], hour: 23, minute: 45),
        ]
        for r in rules {
            XCTAssertEqual(CheckInRemind.parseRule(r.storage), r, "往返失败：\(r.storage)")
        }
    }

    func testStorageEncoding() {
        XCTAssertEqual(RemindRule.daily(hour: 20, minute: 0).storage, "20:00")
        // 单天沿用第二版格式（历史兼容）；多天 CSV；跳假日第 4 段标记
        XCTAssertEqual(
            RemindRule.weekly(weekdays: [3], skipHolidays: false, hour: 20, minute: 0).storage,
            "weekly|3|20:00"
        )
        XCTAssertEqual(
            RemindRule.weekly(weekdays: [2, 4, 6], skipHolidays: false, hour: 20, minute: 0).storage,
            "weekly|2,4,6|20:00"
        )
        XCTAssertEqual(
            RemindRule.weekly(
                weekdays: RemindRule.workdayWeekdays, skipHolidays: true, hour: 20, minute: 0
            ).storage,
            "weekly|2,3,4,5,6|20:00|hol"
        )
        XCTAssertEqual(RemindRule.monthly(days: [15], hour: 9, minute: 0).storage, "monthly|15|09:00")
        XCTAssertEqual(RemindRule.monthly(days: [1, 15], hour: 9, minute: 0).storage, "monthly|1,15|09:00")
    }

    // MARK: 展示文案

    func testText() {
        XCTAssertEqual(RemindRule.daily(hour: 20, minute: 0).text, "每日 20:00")
        XCTAssertEqual(
            RemindRule.weekly(weekdays: [1], skipHolidays: false, hour: 8, minute: 5).text,
            "每周日 08:05"
        )
        XCTAssertEqual(
            RemindRule.weekly(weekdays: [3], skipHolidays: false, hour: 20, minute: 0).text,
            "每周二 20:00"
        )
        // 工作日预设 → 专属文案
        XCTAssertEqual(RemindRule.workday(hour: 20, minute: 0).text, "工作日 20:00")
        XCTAssertEqual(
            RemindRule.weekly(weekdays: [2, 3, 4, 5, 6], skipHolidays: false, hour: 20, minute: 0).text,
            "每周一至五 20:00"
        )
        // 周末 / 多段 / 跳假日尾注
        XCTAssertEqual(
            RemindRule.weekly(weekdays: [1, 7], skipHolidays: false, hour: 20, minute: 0).text,
            "每周六日 20:00"
        )
        XCTAssertEqual(
            RemindRule.weekly(weekdays: [1, 3, 5], skipHolidays: false, hour: 20, minute: 0).text,
            "每周日、二、四 20:00"
        )
        XCTAssertEqual(
            RemindRule.weekly(weekdays: [2, 3, 4, 6], skipHolidays: false, hour: 20, minute: 0).text,
            "每周一至三、五 20:00"
        )
        XCTAssertEqual(
            RemindRule.weekly(weekdays: [2, 4], skipHolidays: true, hour: 20, minute: 0).text,
            "每周一、三 20:00（跳假日）"
        )
        XCTAssertEqual(RemindRule.monthly(days: [15], hour: 9, minute: 0).text, "每月 15 日 09:00")
        XCTAssertEqual(RemindRule.monthly(days: [1, 15], hour: 9, minute: 0).text, "每月 1、15 日 09:00")
        XCTAssertEqual(RemindRule.monthly(days: [1, 2], hour: 9, minute: 0).text, "每月 1、2 日 09:00")
        XCTAssertEqual(RemindRule.monthly(days: [28, 29, 30, 31], hour: 23, minute: 45).text, "每月 28至31 日 23:45")
    }

    // MARK: 访问器与预设

    func testHourMinute() {
        XCTAssertEqual(RemindRule.weekly(weekdays: [2, 4], skipHolidays: true, hour: 7, minute: 30).hour, 7)
        XCTAssertEqual(RemindRule.weekly(weekdays: [2, 4], skipHolidays: true, hour: 7, minute: 30).minute, 30)
        XCTAssertEqual(RemindRule.monthly(days: [1, 31], hour: 23, minute: 59).hour, 23)
    }

    func testAccessorsAndWorkdayPreset() {
        XCTAssertNil(RemindRule.daily(hour: 20, minute: 0).weekdays)
        XCTAssertFalse(RemindRule.daily(hour: 20, minute: 0).skipHolidays)

        let w = RemindRule.weekly(weekdays: [2, 4], skipHolidays: false, hour: 1, minute: 2)
        XCTAssertEqual(w.weekdays, [2, 4])
        XCTAssertFalse(w.skipHolidays)
        XCTAssertFalse(w.isWorkdayPreset)

        let wd = RemindRule.workday(hour: 20, minute: 0)
        XCTAssertTrue(wd.isWorkdayPreset)
        XCTAssertEqual(wd.weekdays, [2, 3, 4, 5, 6])
        XCTAssertTrue(wd.skipHolidays)

        // 一至五但不跳假 → 非工作日预设态
        XCTAssertFalse(
            RemindRule.weekly(weekdays: [2, 3, 4, 5, 6], skipHolidays: false, hour: 20, minute: 0)
                .isWorkdayPreset
        )
        XCTAssertEqual(RemindRule.weekendWeekdays, [1, 7])
    }

    // MARK: 星期集合规范化与摘要

    func testNormalizeWeekdays() {
        XCTAssertEqual(RemindRule.normalizeWeekdays([3, 1, 2]), [1, 2, 3])
        XCTAssertEqual(RemindRule.normalizeWeekdays([5, 5]), [5])
        XCTAssertNil(RemindRule.normalizeWeekdays([]))
        XCTAssertNil(RemindRule.normalizeWeekdays([0]))
        XCTAssertNil(RemindRule.normalizeWeekdays([8]))
        XCTAssertNil(RemindRule.normalizeWeekdays([2, 8]))
    }

    func testNormalizeWeekdaysCSV() {
        XCTAssertEqual(RemindRule.normalizeWeekdaysCSV("2,4,6"), [2, 4, 6])
        XCTAssertEqual(RemindRule.normalizeWeekdaysCSV("6,2"), [2, 6])
        XCTAssertEqual(RemindRule.normalizeWeekdaysCSV("5"), [5])
        XCTAssertNil(RemindRule.normalizeWeekdaysCSV(""))
        XCTAssertNil(RemindRule.normalizeWeekdaysCSV("2,,6"))
        XCTAssertNil(RemindRule.normalizeWeekdaysCSV("2,x"))
        XCTAssertNil(RemindRule.normalizeWeekdaysCSV("9"))
        XCTAssertNil(RemindRule.normalizeWeekdaysCSV(","))
    }

    func testNormalizeDays() {
        XCTAssertEqual(RemindRule.normalizeDays([15, 1, 15]), [1, 15])
        XCTAssertEqual(RemindRule.normalizeDays([31]), [31])
        XCTAssertNil(RemindRule.normalizeDays([]))
        XCTAssertNil(RemindRule.normalizeDays([0]))
        XCTAssertNil(RemindRule.normalizeDays([32]))
        XCTAssertNil(RemindRule.normalizeDays([1, 32]))
    }

    func testNormalizeDaysCSV() {
        XCTAssertEqual(RemindRule.normalizeDaysCSV("1,15"), [1, 15])
        XCTAssertEqual(RemindRule.normalizeDaysCSV("15,1"), [1, 15])
        XCTAssertEqual(RemindRule.normalizeDaysCSV("7"), [7])
        XCTAssertNil(RemindRule.normalizeDaysCSV(""))
        XCTAssertNil(RemindRule.normalizeDaysCSV("1,,7"))
        XCTAssertNil(RemindRule.normalizeDaysCSV("x"))
        XCTAssertNil(RemindRule.normalizeDaysCSV("32"))
    }

    func testDaySummary() {
        XCTAssertEqual(RemindRule.daySummary([15]), "15")
        XCTAssertEqual(RemindRule.daySummary([1, 15]), "1、15")
        XCTAssertEqual(RemindRule.daySummary([1, 2]), "1、2")
        XCTAssertEqual(RemindRule.daySummary([28, 29, 30, 31]), "28至31")
        XCTAssertEqual(RemindRule.daySummary([1, 2, 3, 10, 11, 25]), "1至3、10、11、25")   // 2 天并列（与星期摘要同约定），≥3 才折叠
    }

    func testWeekdaySummary() {
        XCTAssertEqual(RemindRule.weekdaySummary([3]), "二")
        XCTAssertEqual(RemindRule.weekdaySummary([1, 7]), "六日")
        XCTAssertEqual(RemindRule.weekdaySummary([2, 3, 4, 5, 6]), "一至五")
        XCTAssertEqual(RemindRule.weekdaySummary([2, 4]), "一、三")
        XCTAssertEqual(RemindRule.weekdaySummary([1, 3, 5]), "日、二、四")
        XCTAssertEqual(RemindRule.weekdaySummary([2, 3, 4, 6]), "一至三、五")
        XCTAssertEqual(RemindRule.weekdaySummary([1, 2, 3]), "日至二")
    }

    func testWeekdayChars() {
        XCTAssertEqual(RemindRule.weekdayChars, ["日", "一", "二", "三", "四", "五", "六"])
        XCTAssertEqual(RemindRule.weekdayChars.count, 7)
    }
}
