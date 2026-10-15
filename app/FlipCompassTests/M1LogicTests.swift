import XCTest
import SwiftData
@testable import FlipCompass

// MARK: - M1 逻辑单测（B1）：统计纯函数 / 提醒解析 / pager 手势决策 / 打卡决策

final class M1LogicTests: XCTestCase {

    // 固定日历（公历 · 周日起始）与锚点日期，测试不依赖运行当天
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // MARK: streak（温情语义：今天未打不断连，从昨天起算进行中连续）

    func testStreak_含今天() {
        let today = date(2026, 10, 14)
        let days: Set<Date> = [
            CheckInStats.startOfDay(date(2026, 10, 14), cal: cal),
            CheckInStats.startOfDay(date(2026, 10, 13), cal: cal),
            CheckInStats.startOfDay(date(2026, 10, 12), cal: cal),
        ]
        XCTAssertEqual(CheckInStats.streak(days: days, today: today, cal: cal), 3)
    }

    func testStreak_今天未打从昨天起算() {
        let today = date(2026, 10, 14)
        let days: Set<Date> = [
            CheckInStats.startOfDay(date(2026, 10, 13), cal: cal),
            CheckInStats.startOfDay(date(2026, 10, 12), cal: cal),
        ]
        XCTAssertEqual(CheckInStats.streak(days: days, today: today, cal: cal), 2)
    }

    func testStreak_断档() {
        let today = date(2026, 10, 14)
        let days: Set<Date> = [
            CheckInStats.startOfDay(date(2026, 10, 14), cal: cal),
            CheckInStats.startOfDay(date(2026, 10, 12), cal: cal),   // 昨天缺 → 断
        ]
        XCTAssertEqual(CheckInStats.streak(days: days, today: today, cal: cal), 1)
    }

    func testStreak_空记录() {
        XCTAssertEqual(CheckInStats.streak(days: [], today: date(2026, 10, 14), cal: cal), 0)
    }

    func testMaxStreak_取各条目最大() {
        let today = date(2026, 10, 14)
        let a: Set<Date> = [CheckInStats.startOfDay(date(2026, 10, 14), cal: cal),
                            CheckInStats.startOfDay(date(2026, 10, 13), cal: cal)]
        let b: Set<Date> = [CheckInStats.startOfDay(date(2026, 10, 14), cal: cal),
                            CheckInStats.startOfDay(date(2026, 10, 13), cal: cal),
                            CheckInStats.startOfDay(date(2026, 10, 12), cal: cal)]
        XCTAssertEqual(CheckInStats.maxStreak(itemDays: [a, b, []], today: today, cal: cal), 3)
    }

    // MARK: 今日统计

    func testTodayCount() {
        let today = date(2026, 10, 14)
        let t0 = CheckInStats.startOfDay(today, cal: cal)
        let itemDays: [Set<Date>] = [
            [t0],
            [t0, CheckInStats.startOfDay(date(2026, 10, 13), cal: cal)],
            [],
        ]
        let r = CheckInStats.todayCount(itemDays: itemDays, today: today, cal: cal)
        XCTAssertEqual(r.done, 2)
        XCTAssertEqual(r.total, 3)
    }

    // MARK: 本周打卡次数（周一起算含今天，按次数求和）

    func testWeekCount_按次数求和且只计本周() {
        let today = date(2026, 10, 14)   // 周三（周一起始）
        let weekday = (cal.component(.weekday, from: today) + 6) % 7
        let weekStart = cal.date(byAdding: .day, value: -weekday, to: CheckInStats.startOfDay(today, cal: cal))!
        let counts: [Date: Int] = [
            weekStart: 2,                                                // 周一 · 2 次
            cal.date(byAdding: .day, value: 1, to: weekStart)!: 1,       // 周二 · 1 次
            CheckInStats.startOfDay(today, cal: cal): 3,                  // 今天 · 3 次
            cal.date(byAdding: .day, value: -1, to: weekStart)!: 99,      // 上周日（不计）
        ]
        XCTAssertEqual(CheckInStats.weekCount(dayCounts: counts, today: today, cal: cal), 6)
    }

    // MARK: 近 N 天比率与周条

    func testDailyRatios_末位为今天() {
        let today = date(2026, 10, 14)
        let t0 = CheckInStats.startOfDay(today, cal: cal)
        let ratios = CheckInStats.dailyRatios(daysAgo: 3, dayCounts: [t0: 2], total: 4, today: today, cal: cal)
        XCTAssertEqual(ratios.count, 3)
        XCTAssertEqual(ratios.last ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(ratios.first ?? -1, 0, accuracy: 0.0001)
    }

    func testStrip_状态判定与今天标记() {
        let today = date(2026, 10, 14)
        let t0 = CheckInStats.startOfDay(today, cal: cal)
        let y1 = cal.date(byAdding: .day, value: -1, to: t0)!
        let y2 = cal.date(byAdding: .day, value: -2, to: t0)!
        // 4 条目：今天 3/4=0.75 hit；昨天 0 miss；前天 1/4=0.25 plain
        let cells = CheckInStats.strip(daysAgo: 3, dayCounts: [t0: 3, y1: 0, y2: 1],
                                      total: 4, today: today, cal: cal)
        XCTAssertEqual(cells.count, 3)
        XCTAssertEqual(cells[2].state, .hit)
        XCTAssertTrue(cells[2].isToday)
        XCTAssertEqual(cells[1].state, .miss)
        XCTAssertEqual(cells[0].state, .plain)
    }

    func testStrip_无条目全为plain() {
        let cells = CheckInStats.strip(daysAgo: 7, dayCounts: [:], total: 0,
                                      today: date(2026, 10, 14), cal: cal)
        XCTAssertEqual(cells.count, 7)
        XCTAssertTrue(cells.allSatisfy { $0.state == .plain })
    }

    func testHeat_四十二格() {
        let ratios = CheckInStats.heat(dayCounts: [:], total: 2, today: date(2026, 10, 14), cal: cal)
        XCTAssertEqual(ratios.count, 42)
        XCTAssertTrue(ratios.allSatisfy { $0 == 0 })
    }

    // MARK: 提醒时间解析

    func testRemindParse_合法() {
        XCTAssertEqual(CheckInRemind.parse("21:00")?.hour, 21)
        XCTAssertEqual(CheckInRemind.parse("21:00")?.minute, 0)
        XCTAssertEqual(CheckInRemind.parse("09:05")?.minute, 5)
    }

    func testRemindParse_非法与空() {
        XCTAssertNil(CheckInRemind.parse(""))
        XCTAssertNil(CheckInRemind.parse("不提醒"))
        XCTAssertNil(CheckInRemind.parse("24:00"))
        XCTAssertNil(CheckInRemind.parse("21:60"))
        XCTAssertNil(CheckInRemind.parse("2100"))
    }

    // MARK: PagerLogic（手势决策）

    func testLockAxis() {
        XCTAssertNil(PagerLogic.lockAxis(dx: 5, dy: 3))          // 未过 8pt 阈值
        XCTAssertEqual(PagerLogic.lockAxis(dx: 20, dy: 5), .horizontal)
        XCTAssertEqual(PagerLogic.lockAxis(dx: 5, dy: 20), .vertical)
    }

    // （B1c：rubberX 跟手预览已随「拖动零位移」方案废弃，测试移除）

    func testSettlePage_位移切页() {
        XCTAssertEqual(PagerLogic.settlePage(dragX: -200, width: 350, fastNext: false, fastPrev: false,
                                             page: 0, pageCount: 3).page, 1)
        XCTAssertEqual(PagerLogic.settlePage(dragX: 120, width: 350, fastNext: false, fastPrev: false,
                                             page: 1, pageCount: 3).page, 0)
    }

    func testSettlePage_快扫切页() {
        // 小位移但快扫方向明确也切页
        XCTAssertEqual(PagerLogic.settlePage(dragX: -20, width: 350, fastNext: true, fastPrev: false,
                                             page: 0, pageCount: 3).page, 1)
    }

    func testSettlePage_越界bump() {
        let r = PagerLogic.settlePage(dragX: -200, width: 350, fastNext: false, fastPrev: false,
                                       page: 2, pageCount: 3)
        XCTAssertEqual(r.page, 2)
        XCTAssertTrue(r.bumped)
        let r0 = PagerLogic.settlePage(dragX: 120, width: 350, fastNext: false, fastPrev: false,
                                        page: 0, pageCount: 3)
        XCTAssertEqual(r0.page, 0)
        XCTAssertTrue(r0.bumped)
    }

    func testSettlePage_未过阈值回弹() {
        XCTAssertEqual(PagerLogic.settlePage(dragX: -50, width: 350, fastNext: false, fastPrev: false,
                                             page: 0, pageCount: 3).page, 0)
    }

    func testStepSel_逐行步进（焦点跟手势方向）() {
        // 下滑 → sel+1（焦点下移）；上滑 → sel-1；未跨整行不动（原型「下滑 sel 0→1」）
        XCTAssertEqual(PagerLogic.stepSel(dragY: 70, rowHeight: 63, startSel: 0, count: 4), 1)
        XCTAssertEqual(PagerLogic.stepSel(dragY: 140, rowHeight: 63, startSel: 0, count: 4), 2)
        XCTAssertEqual(PagerLogic.stepSel(dragY: -50, rowHeight: 63, startSel: 1, count: 4), 1)
        XCTAssertEqual(PagerLogic.stepSel(dragY: -70, rowHeight: 63, startSel: 1, count: 4), 0)
    }

    func testStepSel_边界clamp() {
        XCTAssertEqual(PagerLogic.stepSel(dragY: 500, rowHeight: 63, startSel: 2, count: 3), 2)
        XCTAssertEqual(PagerLogic.stepSel(dragY: -500, rowHeight: 63, startSel: 0, count: 3), 0)
    }

    func testStepSel_空列表与无焦点原位() {
        XCTAssertEqual(PagerLogic.stepSel(dragY: 100, rowHeight: 63, startSel: -1, count: 0), -1)
        XCTAssertEqual(PagerLogic.stepSel(dragY: 100, rowHeight: 63, startSel: 0, count: 0), 0)
    }

    func testFlickStep_快扫补步进（正向为下滑）() {
        // 小拖快扫 → 至少步进一档；下滑快扫 → +1，上滑快扫 → -1
        XCTAssertEqual(PagerLogic.flickStep(dragY: 35, fastDown: true, fastUp: false,
                                            sel: 0, startSel: 0, count: 3), 1)
        XCTAssertEqual(PagerLogic.flickStep(dragY: -35, fastDown: false, fastUp: true,
                                            sel: 1, startSel: 1, count: 3), 0)
        // 已步进过（拖动中跨过行）→ 不补
        XCTAssertNil(PagerLogic.flickStep(dragY: 35, fastDown: true, fastUp: false,
                                          sel: 1, startSel: 0, count: 3))
        // 非快扫 → 不动
        XCTAssertNil(PagerLogic.flickStep(dragY: 35, fastDown: false, fastUp: false,
                                          sel: 0, startSel: 0, count: 3))
    }

    func testSettleSwipe_展开与收起() {
        // B1d：reveal 默认 56（红字「删除」区域）
        XCTAssertEqual(PagerLogic.settleSwipe(swipeX: -40), -56)
        XCTAssertEqual(PagerLogic.settleSwipe(swipeX: -20), 0)
        XCTAssertEqual(PagerLogic.settleSwipe(swipeX: -56), -56)
    }

    // MARK: 打卡决策（checkInDecision · in-memory SwiftData 容器）

    /// @Model 关系操作必须在 ModelContainer 内（容器外 append records 会崩溃）；mainContext 主线程隔离
    @MainActor
    private func makeItemContext() -> (ModelContext, ModelContainer) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: CheckInItem.self, CheckInRecord.self, configurations: config
        )
        return (container.mainContext, container)
    }

    @MainActor
    func testCheckInDecision_首次打卡() {
        let (context, container) = makeItemContext()
        defer { container.deleteAllData() }
        context.insert(CheckInItem(title: "抱抱宝宝"))
        let item = try! context.fetch(FetchDescriptor<CheckInItem>())[0]
        let now = date(2026, 10, 14, 21, 30)   // 21:30
        context.insert(CheckInRecord(
            day: CheckInStats.startOfDay(date(2026, 10, 13), cal: cal), time: now, item: item
        ))   // 昨天 1 次 → streak 1，打卡后 2
        let d = M1Store.checkInDecision(item: item, now: now, cal: cal)
        XCTAssertTrue(d.inserted)
        XCTAssertEqual(d.streak, 2)
        XCTAssertEqual(d.time, "21:30")
    }

    @MainActor
    func testCheckInDecision_今日已打不重复() {
        let (context, container) = makeItemContext()
        defer { container.deleteAllData() }
        context.insert(CheckInItem(title: "抱抱宝宝"))
        let item = try! context.fetch(FetchDescriptor<CheckInItem>())[0]
        let now = date(2026, 10, 14, 21)
        context.insert(CheckInRecord(
            day: CheckInStats.startOfDay(now, cal: cal),
            time: date(2026, 10, 14, 19, 42), item: item
        ))
        let d = M1Store.checkInDecision(item: item, now: now, cal: cal)
        XCTAssertFalse(d.inserted)
        XCTAssertEqual(d.time, "19:42")
    }

    // MARK: 鼓励语与胶囊文案拆解

    func testEncourage_分档() {
        XCTAssertEqual(M1Store.encourage(streak: 0), "「从今天的一次打卡开始」")
        XCTAssertTrue(M1Store.encourage(streak: 3).contains("3"))
        XCTAssertTrue(M1Store.encourage(streak: 8).contains("8"))
    }

    func testHeadChipText_拆解() {
        XCTAssertEqual(HeadChipText.prefix(text: "连续 7 天"), "连续 ")
        XCTAssertEqual(HeadChipText.suffix(text: "连续 7 天"), " 天")
        XCTAssertEqual(HeadChipText.prefix(text: "3 条想法"), "")
        XCTAssertEqual(HeadChipText.suffix(text: "3 条想法"), " 条想法")
    }

    // MARK: C1 d1 · 本月分布月历（monthCalendar：blank 对齐 + 五态判定）

    func testMonthCalendar_结构与首日对齐() {
        // 2026-10-01 是周四（周日起始 → 前 4 格 blank）+ 10 月 31 天 = 35 格
        let cells = CheckInStats.monthCalendar(days: [], today: date(2026, 10, 14), cal: cal)
        XCTAssertEqual(cells.count, 35)
        XCTAssertTrue(cells.prefix(4).allSatisfy { $0 == .blank })
        XCTAssertEqual(cells[4], .miss)   // 10-1 过去未打 → 红环
    }

    func testMonthCalendar_五态判定() {
        let t0 = CheckInStats.startOfDay(date(2026, 10, 14), cal: cal)
        let y1 = cal.date(byAdding: .day, value: -1, to: t0)!   // 10-13 昨天已打
        let cells = CheckInStats.monthCalendar(days: [t0, y1], today: date(2026, 10, 14), cal: cal)
        XCTAssertEqual(cells[4 + 12 - 1], .miss)                     // 10-12 过去未打
        XCTAssertEqual(cells[4 + 13 - 1], .hit(alpha: 0.9))          // 10-13 已打 → 橙点
        XCTAssertEqual(cells[4 + 14 - 1], .today(hasHit: true))      // 10-14 今天已打 → 描边
        XCTAssertEqual(cells[4 + 15 - 1], .future)                   // 10-15 未来 → 弱数字
    }

    // MARK: C1 d1 · 心情时间线（recentRecords 按时刻降序 + limit 截断）

    @MainActor
    func testRecentRecords_按时刻降序且limit截断() {
        let (context, container) = makeItemContext()
        defer { container.deleteAllData() }
        // 乱序插入 4 条（跨 3 天），mood 记插入序号；fetch 顺序不作假设
        for (i, t) in [date(2026, 10, 13, 22), date(2026, 10, 14, 21, 30),
                       date(2026, 10, 12, 8, 15), date(2026, 10, 14, 7, 5)].enumerated() {
            context.insert(CheckInRecord(
                day: CheckInStats.startOfDay(t, cal: cal), time: t, mood: "m\(i)"
            ))
        }
        let all = try! context.fetch(FetchDescriptor<CheckInRecord>())
        let recs = CheckInStats.recentRecords(all, limit: 3)
        XCTAssertEqual(recs.count, 3)
        // 降序：10-14 21:30(m1) → 10-14 07:05(m3) → 10-13 22:00(m0)
        XCTAssertEqual(recs.map(\.mood), ["m1", "m3", "m0"])
    }

    // MARK: 拓展优化轮 · 心情池（经典 + 热词潮词 + 剔除上次防连抽）

    func testMoodPool_Integrity() {
        // 经典池 = 原型六心情（回归）
        XCTAssertEqual(M1Store.moodClassic, ["温暖", "感动", "平静", "想念", "开心", "安心"])
        // 全池无重复、热词池非空且 ⊆ 全池
        let pool = M1Store.moodClassic + M1Store.moodTrendy
        XCTAssertEqual(Set(pool).count, pool.count)
        XCTAssertFalse(M1Store.moodTrendy.isEmpty)
        XCTAssertTrue(M1Store.moodTrendy.allSatisfy { pool.contains($0) })
    }

    func testMoodPool_EmojiCovered() {
        // emoji 映射覆盖全池（新增热词必须配 emoji，防时间线 fallback 😊）
        for mood in M1Store.moodClassic + M1Store.moodTrendy {
            XCTAssertNotNil(M1Store.moodEmoji[mood], "缺 emoji：\(mood)")
        }
    }

    func testMoodCandidates_剔除上次() {
        // 上次是热词 → 热词段剔除；经典段不受影响
        let t = M1Store.moodCandidates(trendy: true, previous: "松弛感")
        XCTAssertFalse(t.contains("松弛感"))
        XCTAssertEqual(t.count, M1Store.moodTrendy.count - 1)
        XCTAssertEqual(M1Store.moodCandidates(trendy: false, previous: "松弛感"), M1Store.moodClassic)
        // 上次是经典 → 经典段剔除
        let c = M1Store.moodCandidates(trendy: false, previous: "温暖")
        XCTAssertFalse(c.contains("温暖"))
        // previous 为 nil / 空串 → 原池不动
        XCTAssertEqual(M1Store.moodCandidates(trendy: true, previous: nil), M1Store.moodTrendy)
        XCTAssertEqual(M1Store.moodCandidates(trendy: true, previous: ""), M1Store.moodTrendy)
    }

    func testPickMood_InPoolAndNoRepeat() {
        // 大样本：结果必在池内；previous 在池内时不再返回 previous（经典段剔除 + 热词段天然不含）
        let pool = Set(M1Store.moodClassic + M1Store.moodTrendy)
        for _ in 0..<300 {
            let m = M1Store.pickMood(previous: "安心")
            XCTAssertTrue(pool.contains(m))
            XCTAssertNotEqual(m, "安心")
        }
    }
}
