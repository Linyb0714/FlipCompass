import XCTest
@testable import FlipCompass

// MARK: - 分组切换落页契约单测（B5a：用户要求「步长固定、滑不够必须复位或前进」）

final class PagerLogicTests: XCTestCase {

    private let w: CGFloat = 390

    // MARK: 距离规则（30% 阈值）

    func testDistanceThreshold() {
        // 滑过 30% → 前进
        let over = PagerLogic.settlePage(dragX: -w * 0.31, width: w,
                                         fastNext: false, fastPrev: false,
                                         page: 0, pageCount: 3)
        XCTAssertEqual(over.page, 1)
        XCTAssertFalse(over.bumped)
        // 不足 30% 且不快 → 原位回弹（复位）
        let under = PagerLogic.settlePage(dragX: -w * 0.29, width: w,
                                          fastNext: false, fastPrev: false,
                                          page: 0, pageCount: 3)
        XCTAssertEqual(under.page, 0)
        XCTAssertFalse(under.bumped)
        // 反向同理
        XCTAssertEqual(PagerLogic.settlePage(dragX: w * 0.5, width: w,
                                              fastNext: false, fastPrev: false,
                                              page: 1, pageCount: 3).page, 0)
        XCTAssertEqual(PagerLogic.settlePage(dragX: w * 0.29, width: w,
                                              fastNext: false, fastPrev: false,
                                              page: 1, pageCount: 3).page, 1)
    }

    // MARK: 快扫规则（滑动距离不足但速度快 → 仍前进）

    func testFastFlickAdvancesDespiteShortDistance() {
        // 只滑 40pt（10%）但快扫（predicted 外推）→ 前进
        let r = PagerLogic.settlePage(dragX: -40, width: w,
                                      fastNext: true, fastPrev: false,
                                      page: 0, pageCount: 3)
        XCTAssertEqual(r.page, 1)
        // 反向快扫
        let r2 = PagerLogic.settlePage(dragX: 40, width: w,
                                       fastNext: false, fastPrev: true,
                                       page: 2, pageCount: 3)
        XCTAssertEqual(r2.page, 1)
    }

    // MARK: 边界（越界 bump 回弹 · 步长不超过一页）

    func testEdgeBump() {
        // 首页继续右滑（向前页）→ bump 原位
        let r = PagerLogic.settlePage(dragX: w * 0.5, width: w,
                                      fastNext: false, fastPrev: true,
                                      page: 0, pageCount: 3)
        XCTAssertEqual(r.page, 0)
        XCTAssertTrue(r.bumped)
        // 末页继续左滑 → bump 原位
        let r2 = PagerLogic.settlePage(dragX: -w * 0.5, width: w,
                                       fastNext: true, fastPrev: false,
                                       page: 2, pageCount: 3)
        XCTAssertEqual(r2.page, 2)
        XCTAssertTrue(r2.bumped)
    }

    // MARK: 步长固定（一次最多前进/后退一页——绝不落半格）

    func testStepIsExactlyOnePage() {
        // 拖 90% 页宽 → 仍然只到下一页（+1），不是按比例多跳
        XCTAssertEqual(PagerLogic.settlePage(dragX: -w * 0.9, width: w,
                                              fastNext: true, fastPrev: false,
                                              page: 0, pageCount: 3).page, 1)
        // 快扫大幅 → 也只 +1
        XCTAssertEqual(PagerLogic.settlePage(dragX: -w * 2.0, width: w,
                                              fastNext: true, fastPrev: false,
                                              page: 1, pageCount: 3).page, 2)
    }

    // MARK: 会话结构（@GestureState 自动复位契约）

    func testSessionDefaults() {
        let s = PagerSession()
        XCTAssertFalse(s.locked)
        XCTAssertEqual(s.mode, .idle)
        XCTAssertEqual(s.offset, .zero)
        var p = PagerSession()
        p.mode = .page
        XCTAssertTrue(p.locked)
        p.mode = .vertical
        XCTAssertTrue(p.locked)
    }
}
