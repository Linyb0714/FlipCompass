import XCTest
@testable import FlipCompass

// MARK: - M3 业务逻辑单测（B3：今日计数 / 收藏筛选 / tag 去重 / 券态 / 偏好文案）

final class M3LogicTests: XCTestCase {

    private func makeFeed(_ id: String, tag: String, tags: [String],
                          fav: Bool = false, inFeed: Bool = true,
                          title: String = "标题") -> FeedItem {
        let f = FeedItem(tag: tag, title: title, sub: "副题", tags: tags,
                         fav: fav, inFeed: inFeed, paragraphs: ["段落一"])
        return f
    }

    private func makeCoupon(daysLeft: Int = 3, state: String = "none", inFeed: Bool = true) -> CouponCard {
        CouponCard(title: "券", sub: "s", value: "v", threshold: "t",
                   daysLeft: daysLeft, valid: "v", scope: "s",
                   progress: 72, state: state, inFeed: inFeed)
    }

    // MARK: 头部胶囊（实算）

    func testHeadline() {
        let r = M3Store.headline(feedCount: 3, couponCount: 1)
        XCTAssertEqual(r.text, "今日 4 条")
        XCTAssertEqual(r.value, 4)
        let r0 = M3Store.headline(feedCount: 0, couponCount: 0)
        XCTAssertEqual(r0.text, "今日 0 条")
    }

    // MARK: p0 今日推送（券在前 · 情报随后 · inFeed 过滤）

    func testFeedListOrderAndFilter() {
        let c1 = makeCoupon(daysLeft: 3)
        let c2 = makeCoupon(daysLeft: 1, inFeed: false)          // 非推送排除
        let f1 = makeFeed("a", tag: "亲子", tags: ["亲子"])
        let f2 = makeFeed("b", tag: "好物", tags: ["好物"], fav: true, inFeed: false)  // 收藏条目排除
        let r = M3Store.feedList(coupons: [c1, c2], feeds: [f1, f2])
        XCTAssertEqual(r.coupons.map(\.id), [c1.id])
        XCTAssertEqual(r.feeds.map(\.id), [f1.id])
    }

    // MARK: p1 筛选档位与收藏过滤

    func testFilterTagsDedupOrder() {
        let feeds = [
            makeFeed("a", tag: "亲子", tags: ["亲子", "目的地"]),
            makeFeed("b", tag: "好物", tags: ["亲子", "买菜"]),
            makeFeed("c", tag: "应季", tags: ["炖汤"]),
        ]
        XCTAssertEqual(M3Store.filterTags(feeds: feeds), ["全部", "亲子", "目的地", "买菜", "炖汤"])
        // 空列表 → 只有「全部」
        XCTAssertEqual(M3Store.filterTags(feeds: []), ["全部"])
    }

    func testFavFeedsFilter() {
        let favA = makeFeed("a", tag: "美食", tags: ["美食", "夜宵"], fav: true, inFeed: false)
        let favB = makeFeed("b", tag: "目的地", tags: ["目的地"], fav: true, inFeed: false)
        let notFav = makeFeed("c", tag: "好物", tags: ["好物"])            // 未收藏
        let list = [favA, favB, notFav]

        let all = M3Store.favFeeds(feeds: list, tag: "全部")
        XCTAssertEqual(all.map(\.id), [favA.id, favB.id])

        let night = M3Store.favFeeds(feeds: list, tag: "夜宵")
        XCTAssertEqual(night.map(\.id), [favA.id])

        let none = M3Store.favFeeds(feeds: list, tag: "炖汤")
        XCTAssertTrue(none.isEmpty)
    }

    // MARK: 券状态

    func testCouponStateLabels() {
        XCTAssertEqual(M3Store.couponLabel(state: "none"), "未领取")
        XCTAssertEqual(M3Store.couponLabel(state: "claimed"), "已领取")
        XCTAssertEqual(M3Store.couponLabel(state: "used"), "已使用")
        XCTAssertEqual(M3Store.couponLabel(state: "expired"), "已过期")
        XCTAssertEqual(M3Store.couponLabel(state: "未知"), "未领取")       // fallback
    }

    func testCouponDimmed() {
        XCTAssertFalse(M3Store.couponDimmed(state: "none"))
        XCTAssertFalse(M3Store.couponDimmed(state: "claimed"))
        XCTAssertTrue(M3Store.couponDimmed(state: "used"))
        XCTAssertTrue(M3Store.couponDimmed(state: "expired"))
    }

    // MARK: 偏好行文案

    func testPrefValueMultiSelect() {
        let p = Preference(key: "taste", title: "口味偏好", sub: "s",
                           options: ["偏甜", "少辣"], selected: ["偏甜", "少辣", "汤水党"])
        XCTAssertEqual(M3Store.prefValue(p), "偏甜 · 少辣 · 汤水党")
        let empty = Preference(key: "taste", title: "口味偏好", sub: "s", selected: [])
        XCTAssertEqual(M3Store.prefValue(empty), "未设置")
    }

    func testPrefValuePriceLevel() {
        let p0 = Preference(key: "price", title: "价格敏感度", sub: "s", options: M3Store.priceTiers, level: 0)
        let p1 = Preference(key: "price", title: "价格敏感度", sub: "s", options: M3Store.priceTiers, level: 1)
        let p2 = Preference(key: "price", title: "价格敏感度", sub: "s", options: M3Store.priceTiers, level: 2)
        XCTAssertEqual(M3Store.prefValue(p0), "只看低价")
        XCTAssertEqual(M3Store.prefValue(p1), "适中")
        XCTAssertEqual(M3Store.prefValue(p2), "看品质")
        // 越界 fallback
        let bad = Preference(key: "price", title: "价格敏感度", sub: "s", options: M3Store.priceTiers, level: 9)
        XCTAssertEqual(M3Store.prefValue(bad), "适中")
    }

    func testPriceTiers() {
        XCTAssertEqual(M3Store.priceTiers, ["只看低价", "适中", "看品质"])
    }

    // MARK: B3b 头部胶囊数字拆解回归（`\d`→`\d+` 修复：两位数曾拆成两组数字「今日 100 条」）

    func testHeadChipTextSplitSingleDigit() {
        // M1「连续 7 天」/ M2「3 条想法」（个位数 · 一直正常）
        XCTAssertEqual(HeadChipText.prefix(text: "连续 7 天"), "连续 ")
        XCTAssertEqual(HeadChipText.suffix(text: "连续 7 天"), " 天")
        XCTAssertEqual(HeadChipText.prefix(text: "3 条想法"), "")
        XCTAssertEqual(HeadChipText.suffix(text: "3 条想法"), " 条想法")
    }

    func testHeadChipTextSplitMultiDigit() {
        // M3「今日 10 条」（两位数 · 修复前 suffix 从 "0 条" 开始 → 胶囊渲染「今日 100 条」）
        XCTAssertEqual(HeadChipText.prefix(text: "今日 10 条"), "今日 ")
        XCTAssertEqual(HeadChipText.suffix(text: "今日 10 条"), " 条")
        // 更大计数（后续真实数据量级）与 0 条
        XCTAssertEqual(HeadChipText.prefix(text: "今日 128 条"), "今日 ")
        XCTAssertEqual(HeadChipText.suffix(text: "今日 128 条"), " 条")
        XCTAssertEqual(HeadChipText.suffix(text: "今日 0 条"), " 条")
        // 无数字（纯文案胶囊 fallback 路径）
        XCTAssertEqual(HeadChipText.prefix(text: "无数字文案"), "")
        XCTAssertEqual(HeadChipText.suffix(text: "无数字文案"), "无数字文案")
    }

    // MARK: C5 券状态机（cpAdvance 流转 · CTA 切换 · 券码格式）

    func testCpAdvance_流转与终态() {
        // none → claimed → used
        let a = M3Store.cpAdvance(state: "none")
        XCTAssertEqual(a.next, "claimed")
        XCTAssertFalse(a.toast!.isEmpty)
        let b = M3Store.cpAdvance(state: "claimed")
        XCTAssertEqual(b.next, "used")
        XCTAssertFalse(b.toast!.isEmpty)
        // used / expired 终态：不流转无提示
        XCTAssertNil(M3Store.cpAdvance(state: "used").next)
        XCTAssertNil(M3Store.cpAdvance(state: "expired").next)
    }

    func testCouponCTA_四态文案() {
        XCTAssertEqual(M3Store.couponCTA(state: "none"), "领取")
        XCTAssertEqual(M3Store.couponCTA(state: "claimed"), "标记已使用")
        XCTAssertEqual(M3Store.couponCTA(state: "used"), "已使用")
        XCTAssertEqual(M3Store.couponCTA(state: "expired"), "已过期")
    }

    func testCpGenerateCode_格式() {
        let code = M3Store.cpGenerateCode()
        XCTAssertEqual(code.count, 9)                     // 8 位数字 + 1 空格
        XCTAssertEqual(code[code.index(code.startIndex, offsetBy: 4)], " ")
        let digits = code.replacingOccurrences(of: " ", with: "")
        XCTAssertEqual(digits.count, 8)
        XCTAssertTrue(digits.allSatisfy { $0.isNumber })
    }

    // MARK: 完善轮 · 偏好加权排序（d7 保存承诺兑现）

    func testPrefWeight() {
        XCTAssertEqual(M3Store.prefWeight(tags: ["炖汤", "买菜"], liked: ["炖汤", "偏甜"]), 1)
        XCTAssertEqual(M3Store.prefWeight(tags: ["炖汤", "偏甜"], liked: ["炖汤", "偏甜", "少辣"]), 2)
        XCTAssertEqual(M3Store.prefWeight(tags: [], liked: ["炖汤"]), 0)
        XCTAssertEqual(M3Store.prefWeight(tags: ["好物"], liked: []), 0)
    }

    func testFeedListPrefWeightedOrder() {
        // createdAt 显式错开：a 最早 → b → c
        let a = FeedItem(tag: "好物", title: "命中0", sub: "s",
                         tags: ["好物"], paragraphs: [],
                         createdAt: Date(timeIntervalSinceNow: -300))
        let b = FeedItem(tag: "应季", title: "命中1", sub: "s",
                         tags: ["炖汤", "汤水党"], paragraphs: [],
                         createdAt: Date(timeIntervalSinceNow: -200))
        let c = FeedItem(tag: "美食", title: "命中2", sub: "s",
                         tags: ["汤水党", "糖水", "亲子"], paragraphs: [],
                         createdAt: Date(timeIntervalSinceNow: -100))
        let liked: Set<String> = ["汤水党", "糖水"]
        // 命中多者在前：c(2 命中) → b(1) → a(0)
        let r = M3Store.feedList(coupons: [], feeds: [a, b, c], likedTags: liked)
        XCTAssertEqual(r.feeds.map(\.id), [c.id, b.id, a.id])
        // 无偏好（likedTags 缺省）→ 保持创建时间升序（原行为回归，不破现有调用）
        let plain = M3Store.feedList(coupons: [], feeds: [a, b, c])
        XCTAssertEqual(plain.feeds.map(\.id), [a.id, b.id, c.id])
    }
}