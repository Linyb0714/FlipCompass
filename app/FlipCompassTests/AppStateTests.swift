import XCTest
@testable import FlipCompass

// MARK: - 导航状态机单测（红线修复：无操作自动退回待机/上级）

final class AppStateTests: XCTestCase {

    // MARK: 翻转进入（仅待机页）

    func testFlip_待机up进入M1() {
        let app = AppState()
        XCTAssertEqual(app.level, .idle)
        app.handleFlipEvent(direction: .up, orientation: .portrait)
        XCTAssertEqual(app.level, .module)
        XCTAssertEqual(app.module, .m1)
    }

    // MARK: 红线：模块内平放不再自动回待机（放下手机不再被误判）

    func testFlip_模块内平放不回退() {
        let app = AppState()
        app.enterModule(.m1)
        app.handleFlipEvent(direction: nil, orientation: .faceUp)
        XCTAssertEqual(app.level, .module, "模块内平放不应回待机（红线修复）")
        XCTAssertEqual(app.module, .m1)
        app.handleFlipEvent(direction: nil, orientation: .faceDown)
        XCTAssertEqual(app.level, .module, "faceDown 同样不回退")
    }

    // MARK: 红线：模块内翻转不再切换模块

    func testFlip_模块内up不切换() {
        let app = AppState()
        app.enterModule(.m2)
        app.handleFlipEvent(direction: .up, orientation: .portrait)
        XCTAssertEqual(app.module, .m2, "模块内翻转不应被误判为切模块（红线修复）")
    }

    // MARK: 红线：二级页（hero）期间忽略一切翻转

    func testFlip_详情打开时忽略() {
        let app = AppState()
        app.enterModule(.m1)
        app.enterDetail()
        app.handleFlipEvent(direction: .up, orientation: .portrait)
        XCTAssertEqual(app.module, .m1, "二级页中翻转不改变导航")
        app.handleFlipEvent(direction: nil, orientation: .faceUp)
        XCTAssertEqual(app.level, .module, "二级页中平放不回待机")
        app.exitDetail()
        app.handleFlipEvent(direction: nil, orientation: .faceUp)
        XCTAssertEqual(app.level, .module, "关闭二级页后仍遵守模块内不受翻转影响")
    }

    func testFlip_详情中回到待机后仍忽略() {
        // 二级页未关闭但被强制回待机（异常路径）：进入待机后 up 也不应重复进入
        let app = AppState()
        app.enterModule(.m1)
        app.enterDetail()
        app.backToIdle()
        app.handleFlipEvent(direction: .up, orientation: .portrait)
        XCTAssertEqual(app.level, .idle, "详情计数未清零时不应响应翻转")
        app.exitDetail()
        app.handleFlipEvent(direction: .up, orientation: .portrait)
        XCTAssertEqual(app.level, .module, "计数清零后恢复待机页翻转进入")
    }

    // MARK: 详情层计数

    func testDetailDepth() {
        let app = AppState()
        XCTAssertEqual(app.detailDepth, 0)
        app.enterDetail()
        app.enterDetail()
        XCTAssertEqual(app.detailDepth, 2)
        app.exitDetail()
        XCTAssertEqual(app.detailDepth, 1)
        app.exitDetail()
        app.exitDetail()   // 多余关闭不应为负
        XCTAssertEqual(app.detailDepth, 0)
    }

    // MARK: 待机页平放保持待机（原本就待机，无副作用）

    func testFlip_待机平放保持待机() {
        let app = AppState()
        app.handleFlipEvent(direction: nil, orientation: .faceUp)
        XCTAssertEqual(app.level, .idle)
    }
}