import XCTest
@testable import FlipCompass

// MARK: - 待机胶囊实况单测（D2：四模块统计实算文案）

final class IdleDigestTests: XCTestCase {

    private static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d
        return Calendar.current.date(from: c)!
    }

    private var today: Date { Self.date(2026, 10, 15) }

    // M1：未完成 / 全部完成 / 空清单三态
    func testPills_M1States() {
        // 2 项：1 项今日已打 → 剩 1 未完成
        let r = IdleDigest.pills(
            itemDays: [[today], []], drafts: 0, feedToday: 0, gamePlaysToday: 0,
            today: today
        )
        XCTAssertEqual(r[0].text, "今日还有 1 个温情打卡没完成")
        XCTAssertEqual(r[0].module, ModuleKey.m1)
        // 全部完成
        let done = IdleDigest.pills(
            itemDays: [[today], [today]], drafts: 0, feedToday: 0, gamePlaysToday: 0,
            today: today
        )
        XCTAssertEqual(done[0].text, "温情打卡全部完成 ✓")
        // 空清单（引导文案）
        let empty = IdleDigest.pills(
            itemDays: [], drafts: 0, feedToday: 0, gamePlaysToday: 0,
            today: today
        )
        XCTAssertEqual(empty[0].text, "打卡清单空着 · 加一件事开始")
    }

    // M2：草稿数 / 空闲
    func testPills_M2Drafts() {
        let r = IdleDigest.pills(
            itemDays: [], drafts: 2, feedToday: 0, gamePlaysToday: 0,
            today: today
        )
        XCTAssertEqual(r[1].text, "有 2 条想法写了一半 · 草稿在等你")
        let idle = IdleDigest.pills(
            itemDays: [], drafts: 0, feedToday: 0, gamePlaysToday: 0,
            today: today
        )
        XCTAssertEqual(idle[1].text, "想法都已记好 · 草稿箱空闲 ✓")
    }

    // M3：今日条数 / 无推送
    func testPills_M3Feed() {
        let r = IdleDigest.pills(
            itemDays: [], drafts: 0, feedToday: 12, gamePlaysToday: 0,
            today: today
        )
        XCTAssertEqual(r[2].text, "生活情报站 · 今日 12 条新情报")
        let none = IdleDigest.pills(
            itemDays: [], drafts: 0, feedToday: 0, gamePlaysToday: 0,
            today: today
        )
        XCTAssertEqual(none[2].text, "生活情报站 · 今天还没有新推送")
    }

    // M4：每日一局已玩 / 未玩
    func testPills_M4Daily() {
        let played = IdleDigest.pills(
            itemDays: [], drafts: 0, feedToday: 0, gamePlaysToday: 1,
            today: today
        )
        XCTAssertEqual(played[3].text, "每日一局已完成 ✓ 休息一下眼睛")
        let notPlayed = IdleDigest.pills(
            itemDays: [], drafts: 0, feedToday: 0, gamePlaysToday: 0,
            today: today
        )
        XCTAssertEqual(notPlayed[3].text, "每日一局没玩 · 益智小游戏在等你")
    }

    // 四条顺序与模块绑定（m1→m4 竖列定稿）
    func testPills_Order() {
        let r = IdleDigest.pills(
            itemDays: [], drafts: 0, feedToday: 0, gamePlaysToday: 0,
            today: today
        )
        XCTAssertEqual(r.map { $0.module }, [ModuleKey.m1, ModuleKey.m2, ModuleKey.m3, ModuleKey.m4])
    }
}
