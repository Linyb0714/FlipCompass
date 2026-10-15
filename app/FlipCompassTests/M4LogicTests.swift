import XCTest
@testable import FlipCompass

// MARK: - M4 业务逻辑单测（B4：今日局数 / 连胜 / 三星 / 勋章进度 / 文案）

final class M4LogicTests: XCTestCase {

    var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        return cal.date(from: c)!
    }

    /// 便捷构造（day 自动取零时）
    private func rec(_ key: String, _ y: Int, _ mo: Int, _ d: Int,
                     score: String = "84 步", stars: Int = 3) -> GameProgress {
        let t = date(y, mo, d, 15, 0)
        return GameProgress(gameKey: key, day: cal.startOfDay(for: t),
                            playedAt: t, score: score, stars: stars)
    }

    private var badgeB1: BadgeDef { M4Static.badges[0] }   // plays need 1
    private var badgeB2: BadgeDef { M4Static.badges[1] }   // streak need 7
    private var badgeB3: BadgeDef { M4Static.badges[2] }   // plays need 30
    private var badgeB4: BadgeDef { M4Static.badges[3] }   // maxstar need 3

    // MARK: 今日局数

    func testTodayCount() {
        let today = date(2026, 10, 14, 20)
        let recs = [
            rec("hrd", 2026, 10, 14),
            rec("maze", 2026, 10, 14, score: "58s"),
            rec("hrd", 2026, 10, 13),
        ]
        XCTAssertEqual(M4Store.todayCount(recs, today: today, cal: cal), 2)
        XCTAssertEqual(M4Store.todayCount([], today: today, cal: cal), 0)
    }

    // MARK: 连续天数（今天没玩不断连 · 从昨天起算）

    func testStreakDays() {
        let today = date(2026, 10, 14, 20)
        // 今天 + 昨天 + 前天 → 3
        let r3 = [
            rec("hrd", 2026, 10, 14),
            rec("hrd", 2026, 10, 13),
            rec("hrd", 2026, 10, 12),
        ]
        XCTAssertEqual(M4Store.streakDays(r3, today: today, cal: cal), 3)
        // 今天没玩 → 从昨天起算不断连（10-13~10-11 → 3）
        let rYesterday = [
            rec("hrd", 2026, 10, 13),
            rec("hrd", 2026, 10, 12),
            rec("hrd", 2026, 10, 11),
        ]
        XCTAssertEqual(M4Store.streakDays(rYesterday, today: today, cal: cal), 3)
        // 断档：10-13 与 10-11（缺 12）→ 1
        let rGap = [
            rec("hrd", 2026, 10, 13),
            rec("hrd", 2026, 10, 11),
        ]
        XCTAssertEqual(M4Store.streakDays(rGap, today: today, cal: cal), 1)
        // 空记录 → 0
        XCTAssertEqual(M4Store.streakDays([], today: today, cal: cal), 0)
    }

    // MARK: 星星统计

    func testStarCounts() {
        let recs = [
            rec("hrd", 2026, 10, 14, stars: 3),
            rec("maze", 2026, 10, 14, score: "58s", stars: 3),
            rec("hrd", 2026, 10, 13, stars: 2),
            rec("one", 2026, 10, 11, stars: 1),
        ]
        XCTAssertEqual(M4Store.threeStarCount(recs), 2)
        XCTAssertEqual(M4Store.totalStars(recs), 9)
        XCTAssertEqual(M4Store.maxStar(recs), 3)
        XCTAssertEqual(M4Store.maxStar([]), 0)
    }

    func testHeadline() {
        XCTAssertEqual(M4Store.headline(threeStar: 2).text, "三星 2 局")
        XCTAssertEqual(M4Store.headline(threeStar: 2).value, 2)
        XCTAssertEqual(M4Store.headline(threeStar: 0).text, "三星 0 局")
    }

    // MARK: 勋章进度（实算解锁）

    func testBadgeProgressPlays() {
        let recs = (0..<8).map { rec("hrd", 2026, 10, $0 % 28 + 1) }
        XCTAssertEqual(M4Store.badgeProgress(badgeB1, records: recs, streak: 0).cur, 8)
        XCTAssertTrue(M4Store.badgeUnlocked(badgeB1, records: recs, streak: 0))   // 8 ≥ 1
        XCTAssertEqual(M4Store.badgeProgress(badgeB3, records: recs, streak: 0).cur, 8)
        XCTAssertFalse(M4Store.badgeUnlocked(badgeB3, records: recs, streak: 0))  // 8 < 30
    }

    func testBadgeProgressStreak() {
        let recs = [rec("hrd", 2026, 10, 14)]
        XCTAssertEqual(M4Store.badgeProgress(badgeB2, records: recs, streak: 5).cur, 5)
        XCTAssertFalse(M4Store.badgeUnlocked(badgeB2, records: recs, streak: 5))  // 5 < 7
        XCTAssertTrue(M4Store.badgeUnlocked(badgeB2, records: recs, streak: 7))   // 7 ≥ 7
    }

    func testBadgeProgressMaxStar() {
        let recs = [
            rec("hrd", 2026, 10, 14, stars: 3),
            rec("one", 2026, 10, 11, stars: 1),
        ]
        XCTAssertEqual(M4Store.badgeProgress(badgeB4, records: recs, streak: 0).cur, 3)
        XCTAssertTrue(M4Store.badgeUnlocked(badgeB4, records: recs, streak: 0))
        let lowStars = [rec("one", 2026, 10, 11, stars: 2)]
        XCTAssertFalse(M4Store.badgeUnlocked(badgeB4, records: lowStars, streak: 0))
    }

    // MARK: p0 文案

    func testTodayStatSub() {
        XCTAssertEqual(M4Store.todayStatSub(0), "今天还没开局 · 来一局")
        XCTAssertEqual(M4Store.todayStatSub(3), "点按看全部战绩")
    }

    func testStreakStatSub() {
        XCTAssertEqual(M4Store.streakStatSub(5), "再连 2 天解锁「七日之约」")
        XCTAssertEqual(M4Store.streakStatSub(7), "「七日之约」已解锁 ✦")
        XCTAssertEqual(M4Store.streakStatSub(9), "「七日之约」已解锁 ✦")   // 超额不回退
    }

    // MARK: 静态表完整性

    func testStaticTables() {
        XCTAssertEqual(M4Static.games.count, 4)
        XCTAssertEqual(M4Static.games.map(\.key), ["hrd", "maze", "g2048", "one"])
        XCTAssertEqual(M4Static.badges.count, 4)
        XCTAssertEqual(M4Static.badges.map(\.kind), [.plays, .streak, .plays, .maxstar])
        // 每款游戏图标渐变/星级数据齐备
        for g in M4Static.games {
            XCTAssertFalse(g.continueLevel.isEmpty)
            XCTAssertFalse(g.continueChips.isEmpty)
            XCTAssertTrue((0...M4Store.starMax).contains(g.stars))
        }
    }
}
