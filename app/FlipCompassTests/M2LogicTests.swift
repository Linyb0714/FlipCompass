import XCTest
@testable import FlipCompass

// MARK: - M2 业务逻辑单测（B2：草稿三件套 / 今日·月过滤 / 发布 / 月导航）

final class M2LogicTests: XCTestCase {

    var cal: Calendar {
        // 与 ThoughtFormat 的 DateFormatter 同默认时区（构造与格式化一致，跨时区稳定）
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        return cal.date(from: c)!
    }

    private func makeThought(_ text: String, mood: String = "心动",
                             _ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Thought {
        let t = date(y, mo, d, h, mi)
        return Thought(text: text, mood: mood, date: cal.startOfDay(for: t), time: t)
    }

    // MARK: 月导航（跨年正确）

    func testShiftMonth() {
        XCTAssertEqual(M2Store.shiftMonth(year: 2026, month: 10, by: -1).month, 9)
        XCTAssertEqual(M2Store.shiftMonth(year: 2026, month: 10, by: +1).month, 11)
        // 跨年
        let p = M2Store.shiftMonth(year: 2026, month: 1, by: -1)
        XCTAssertEqual(p.year, 2025); XCTAssertEqual(p.month, 12)
        let n = M2Store.shiftMonth(year: 2026, month: 12, by: +1)
        XCTAssertEqual(n.year, 2027); XCTAssertEqual(n.month, 1)
        // 多步
        let m = M2Store.shiftMonth(year: 2026, month: 11, by: +3)
        XCTAssertEqual(m.year, 2027); XCTAssertEqual(m.month, 2)
    }

    func testMonthLabels() {
        XCTAssertEqual(M2Store.monthLabel(year: 2026, month: 10), "2026年10月")
        XCTAssertEqual(M2Store.prevLabel(month: 9), "‹ 9月")
        XCTAssertEqual(M2Store.nextLabel(month: 11), "11月 ›")
    }

    func testMonthKey() {
        XCTAssertEqual(M2Store.monthKey(date(2026, 10, 12), cal: cal), "2026-10")
        XCTAssertEqual(M2Store.monthKey(date(2026, 1, 1), cal: cal), "2026-01")
    }

    // MARK: 今日 / 月过滤

    func testTodayThoughtsFilterAndOrder() {
        let today = date(2026, 10, 12, 21, 0)
        let list = [
            makeThought("morning", 2026, 10, 12, 7, 5),
            makeThought("yesterday", 2026, 10, 11, 22, 0),
            makeThought("night", 2026, 10, 12, 21, 32),
        ]
        let r = M2Store.todayThoughts(list, today: today, cal: cal)
        XCTAssertEqual(r.map(\.text), ["night", "morning"])   // 今日两条 · 时刻降序
    }

    func testMonthThoughtsFilterAndOrder() {
        let list = [
            makeThought("a", 2026, 10, 1, 9, 0),
            makeThought("b", 2026, 9, 30, 9, 0),       // 9 月（排他）
            makeThought("c", 2026, 10, 10, 20, 0),
            makeThought("d", 2026, 9, 15, 9, 0),       // 9 月（排他）
            makeThought("e", 2025, 10, 12, 9, 0),      // 去年 10 月（排他）
        ]
        let r = M2Store.monthThoughts(list, year: 2026, month: 10, cal: cal)
        XCTAssertEqual(r.map(\.text), ["c", "a"])             // 日期降序
    }

    // MARK: B2b 时间轴分组（按日分组 · 组间日期降序 · 组内时刻降序）

    func testMonthGroupsByDay() {
        let list = [
            makeThought("晚", 2026, 10, 12, 21, 32),
            makeThought("早", 2026, 10, 12, 7, 5),
            makeThought("隔天", 2026, 10, 10, 22, 10),
        ]
        let g = M2Store.monthGroups(list, year: 2026, month: 10, cal: cal)
        XCTAssertEqual(g.count, 2)
        XCTAssertEqual(g[0].thoughts.map(\.text), ["晚", "早"])   // 组内时刻降序
        XCTAssertEqual(g[1].thoughts.map(\.text), ["隔天"])       // 组间日期降序
        // 跨月/跨年排除
        let mixed = list + [
            makeThought("上月", 2026, 9, 30, 9, 0),
            makeThought("去年", 2025, 10, 12, 9, 0),
        ]
        XCTAssertEqual(M2Store.monthGroups(mixed, year: 2026, month: 10, cal: cal).count, 2)
    }

    func testDayTitle() {
        XCTAssertEqual(M2Store.dayTitle(date(2026, 10, 12), cal: cal), "10月12日")
        XCTAssertEqual(M2Store.dayTitle(date(2026, 1, 3), cal: cal), "1月3日")
    }

    // MARK: 头部胶囊 / 记录卡副标（R8 ③）

    func testHeadline() {
        XCTAssertEqual(M2Store.headline(todayCount: 3), "3 条想法")
        XCTAssertEqual(M2Store.headline(todayCount: 0), "0 条想法")
    }

    func testComposeSubtitleHasDrafts() {
        let s = M2Store.composeSubtitle(
            draftCount: 2, latestDate: date(2026, 10, 12, 20, 5), cal: cal
        )
        XCTAssertEqual(s, "有草稿 2 条 · 上次 10-12")
    }

    func testComposeSubtitleNoDrafts() {
        // 无草稿 → 回退引导文案
        XCTAssertEqual(
            M2Store.composeSubtitle(draftCount: 0, latestDate: nil, cal: cal),
            "写一句就好 · 写一半也没关系"
        )
        // 计数 0 但有日期（数据异常）→ 仍回退
        XCTAssertEqual(
            M2Store.composeSubtitle(draftCount: 0, latestDate: date(2026, 10, 12), cal: cal),
            "写一句就好 · 写一半也没关系"
        )
    }

    // MARK: R8 ① 草稿自动落盘决策

    private let ref = (text: "想写一篇随笔", mood: "心动")
    private var refDate: Date { date(2026, 10, 12, 9, 0) }

    func testDraftDecisionEmptyNoLatest() {
        // 空文本且无草稿 → none（无事发生）
        XCTAssertEqual(
            M2Store.draftDecision(currentText: "", latestDraftText: nil, latestDraftMood: nil,
                                  mood: "心动", date: refDate, time: refDate),
            .none
        )
    }

    func testDraftDecisionClear() {
        // 清空 → 删除最新草稿
        XCTAssertEqual(
            M2Store.draftDecision(currentText: "", latestDraftText: ref.text, latestDraftMood: ref.mood,
                                  mood: "心动", date: refDate, time: refDate),
            .clear
        )
        // 纯空白 = 清空
        XCTAssertEqual(
            M2Store.draftDecision(currentText: "   \n ", latestDraftText: ref.text, latestDraftMood: ref.mood,
                                  mood: "心动", date: refDate, time: refDate),
            .clear
        )
    }

    func testDraftDecisionSameContentNoRepeat() {
        // 同文本同心情 → none（不重复插入）
        XCTAssertEqual(
            M2Store.draftDecision(currentText: ref.text, latestDraftText: ref.text, latestDraftMood: ref.mood,
                                  mood: "心动", date: refDate, time: refDate),
            .none
        )
    }

    func testDraftDecisionMoodChangeUpserts() {
        // 同文本换心情 → 落盘（心情也是草稿态的一部分）
        let r = M2Store.draftDecision(currentText: ref.text, latestDraftText: ref.text,
                                      latestDraftMood: "心动", mood: "雀跃",
                                      date: refDate, time: refDate)
        XCTAssertEqual(r, .upsert(text: ref.text, mood: "雀跃", date: refDate, time: refDate))
    }

    func testDraftDecisionNewContentUpserts() {
        // 新文本（无既有草稿）→ 新建
        let r = M2Store.draftDecision(currentText: "第一句", latestDraftText: nil, latestDraftMood: nil,
                                      mood: "平静", date: refDate, time: refDate)
        XCTAssertEqual(r, .upsert(text: "第一句", mood: "平静", date: refDate, time: refDate))
        // 新文本（覆盖既有草稿）
        let r2 = M2Store.draftDecision(currentText: "改了", latestDraftText: ref.text, latestDraftMood: ref.mood,
                                       mood: "心动", date: refDate, time: refDate)
        XCTAssertEqual(r2, .upsert(text: "改了", mood: "心动", date: refDate, time: refDate))
    }

    // MARK: 发布决策

    func testPublishDecisionEmpty() {
        XCTAssertEqual(M2Store.publishDecision(text: "", isEditing: false), .empty)
        XCTAssertEqual(M2Store.publishDecision(text: "  \n ", isEditing: true), .empty)
    }

    func testPublishDecisionCreateAndUpdate() {
        XCTAssertEqual(M2Store.publishDecision(text: "新想法", isEditing: false), .create)
        XCTAssertEqual(M2Store.publishDecision(text: "改后的想法", isEditing: true), .update)
    }

    // MARK: 心情

    func testMoodsList() {
        XCTAssertEqual(M2Store.moods, ["晴朗", "平静", "心动", "疲惫", "雀跃"])
        XCTAssertEqual(M2Store.defaultMood, "心动")
    }

    // MARK: 时刻格式化

    func testThoughtFormat() {
        XCTAssertEqual(ThoughtFormat.hhmm(date(2026, 10, 12, 21, 32)), "21:32")
        XCTAssertEqual(ThoughtFormat.hhmm(date(2026, 10, 12, 8, 5)), "08:05")
        XCTAssertEqual(ThoughtFormat.mmdd(date(2026, 10, 12, 21, 32)), "10-12")
    }
}