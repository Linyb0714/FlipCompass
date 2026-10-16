import XCTest
import UserNotifications
@testable import FlipCompass

// MARK: - 通知展开单测
// 每日/每月 → 1 条周期重复；每周（不跳假）→ 逐星期重复；每周（跳假·工作日）→ 逐日期单次

final class CheckInNotifyTests: XCTestCase {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }

    private func d(_ y: Int, _ mo: Int, _ day: Int, _ h: Int, _ mi: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: day, hour: h, minute: mi))!
    }

    private func trigger(_ req: UNNotificationRequest) -> UNCalendarNotificationTrigger? {
        req.trigger as? UNCalendarNotificationTrigger
    }

    func testIdentifierPrefix() {
        let id = UUID()
        XCTAssertTrue(CheckInNotify.identifierPrefix(for: id).hasPrefix("checkin-"))
        XCTAssertTrue(CheckInNotify.identifierPrefix(for: id).hasSuffix(id.uuidString))
    }

    func testDailySingleRepeating() {
        let item = CheckInItem(title: "抱抱宝宝")
        let reqs = CheckInNotify.makeRequests(
            item: item, rule: .daily(hour: 20, minute: 0),
            now: d(2026, 10, 12, 10, 0), calendar: cal
        )
        XCTAssertEqual(reqs.count, 1)
        // identifier 无后缀（与历史通知标识完全一致）
        XCTAssertEqual(reqs[0].identifier, CheckInNotify.identifierPrefix(for: item.id))
        let t = trigger(reqs[0])
        XCTAssertEqual(t?.repeats, true)
        XCTAssertEqual(t?.dateComponents.hour, 20)
        XCTAssertEqual(t?.dateComponents.minute, 0)
        XCTAssertNil(t?.dateComponents.weekday)
    }

    func testMonthlySingleRepeating() {
        let item = CheckInItem(title: "抱抱宝宝")
        let base = CheckInNotify.identifierPrefix(for: item.id)
        let reqs = CheckInNotify.makeRequests(
            item: item, rule: .monthly(days: [15], hour: 9, minute: 30),
            now: d(2026, 10, 12, 10, 0), calendar: cal
        )
        XCTAssertEqual(reqs.count, 1)
        XCTAssertEqual(reqs[0].identifier, "\(base)-m15")
        let t = trigger(reqs[0])
        XCTAssertEqual(t?.repeats, true)
        XCTAssertEqual(t?.dateComponents.day, 15)
        XCTAssertEqual(t?.dateComponents.hour, 9)
        XCTAssertEqual(t?.dateComponents.minute, 30)
    }

    func testMonthlyMultiDayRepeating() {
        let item = CheckInItem(title: "抱抱宝宝")
        let base = CheckInNotify.identifierPrefix(for: item.id)
        let reqs = CheckInNotify.makeRequests(
            item: item, rule: .monthly(days: [1, 15], hour: 9, minute: 30),
            now: d(2026, 10, 12, 10, 0), calendar: cal
        )
        // 每个选中日期一条日期重复通知（后缀 -m<d>）
        XCTAssertEqual(reqs.count, 2)
        XCTAssertEqual(reqs[0].identifier, "\(base)-m1")
        XCTAssertEqual(trigger(reqs[0])?.dateComponents.day, 1)
        XCTAssertEqual(reqs[1].identifier, "\(base)-m15")
        XCTAssertEqual(trigger(reqs[1])?.dateComponents.day, 15)
        for req in reqs {
            XCTAssertEqual(trigger(req)?.repeats, true)
            XCTAssertEqual(trigger(req)?.dateComponents.hour, 9)
            XCTAssertEqual(trigger(req)?.dateComponents.minute, 30)
        }
    }

    func testWeeklyPerWeekdayRepeating() {
        let item = CheckInItem(title: "抱抱宝宝")
        let base = CheckInNotify.identifierPrefix(for: item.id)
        let reqs = CheckInNotify.makeRequests(
            item: item,
            rule: .weekly(weekdays: [2, 4, 6], skipHolidays: false, hour: 20, minute: 0),
            now: d(2026, 10, 12, 10, 0), calendar: cal
        )
        XCTAssertEqual(reqs.count, 3)
        // 每个选中星期一条，identifier 后缀 -w<weekday>，trigger.weekday 对应
        for (i, w) in [2, 4, 6].enumerated() {
            XCTAssertEqual(reqs[i].identifier, "\(base)-w\(w)")
            let t = trigger(reqs[i])
            XCTAssertEqual(t?.repeats, true)
            XCTAssertEqual(t?.dateComponents.weekday, w)
            XCTAssertEqual(t?.dateComponents.hour, 20)
            XCTAssertEqual(t?.dateComponents.minute, 0)
        }
    }

    func testWorkdaySkipHolidayPerDateSingle() {
        let item = CheckInItem(title: "抱抱宝宝")
        let base = CheckInNotify.identifierPrefix(for: item.id)
        // 2026-09-28（周一）10:00 · 工作日 20:00 · 国庆 10/1~10/7 整周跳过
        let reqs = CheckInNotify.makeRequests(
            item: item, rule: .workday(hour: 20, minute: 0),
            now: d(2026, 9, 28, 10, 0), calendar: cal
        )
        XCTAssertEqual(reqs.count, CheckInNotify.skipHolidayHorizon)   // 8 条
        for req in reqs {
            XCTAssertEqual(trigger(req)?.repeats, false)               // 单次通知
            XCTAssertTrue(req.identifier.hasPrefix("\(base)-d"))
        }
        // 首条 = 9/28 20:00； identifiers 后缀日期串 12 位
        XCTAssertEqual(trigger(reqs[0])?.dateComponents.month, 9)
        XCTAssertEqual(trigger(reqs[0])?.dateComponents.day, 28)
        XCTAssertEqual(trigger(reqs[0])?.dateComponents.hour, 20)
        XCTAssertTrue(reqs[0].identifier.hasSuffix("-d202609282000"))
        // 第 4 条跨过国庆 = 10/8
        XCTAssertEqual(trigger(reqs[3])?.dateComponents.month, 10)
        XCTAssertEqual(trigger(reqs[3])?.dateComponents.day, 8)
        // 无任何一条落在 10/1~10/7
        for req in reqs {
            let c = trigger(req)?.dateComponents
            if c?.month == 10 {
                XCTAssertTrue((c?.day ?? 0) > 7, "国庆假期不应排通知：\(req.identifier)")
            }
        }
    }

    func testContent() {
        let item = CheckInItem(title: "睡前刷牙")
        let reqs = CheckInNotify.makeRequests(
            item: item, rule: .daily(hour: 21, minute: 30),
            now: d(2026, 10, 12, 10, 0), calendar: cal
        )
        XCTAssertEqual(reqs[0].content.title, "温情打卡")
        XCTAssertEqual(reqs[0].content.body, "该打卡啦：睡前刷牙")
    }
}
