import XCTest
@testable import FlipCompass

// MARK: - 自转时钟单测（B1p：时间累加 · 冻结/无缝续转契约）
// 引擎契约：刻度环轻自转（转环不停）+ 轨迹双弧（收拢冻结相位、松手复位续转）均由此驱动。

final class SpinClockTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1000)

    // MARK: 基础角度

    func testInitialPhaseAndAdvance() {
        let c = SpinClock(period: 1, direction: 1, phase: 30, base: t0)
        XCTAssertEqual(c.angle(now: t0), 30, accuracy: 0.001)
        // 1s/圈 → 0.25s = 90°
        XCTAssertEqual(c.angle(now: t0.addingTimeInterval(0.25)), 120, accuracy: 0.001)
    }

    func testDirectionReverses() {
        let c = SpinClock(period: 1, direction: -1, phase: 0, base: t0)
        XCTAssertEqual(c.angle(now: t0.addingTimeInterval(0.25)), -90, accuracy: 0.001)
    }

    func testDifferentialPeriods() {
        // 差速契约：同 10s，42s/圈（长细弧）与 26s/圈（短粗弧）角速度不同
        let slow = SpinClock(period: 42, direction: 1, base: t0)
        let fast = SpinClock(period: 26, direction: 1, base: t0)
        let dt = 10.0
        XCTAssertEqual(slow.angle(now: t0.addingTimeInterval(dt)), 360.0 / 42 * dt, accuracy: 0.001)
        XCTAssertEqual(fast.angle(now: t0.addingTimeInterval(dt)), 360.0 / 26 * dt, accuracy: 0.001)
        XCTAssertGreaterThan(
            fast.angle(now: t0.addingTimeInterval(dt)),
            slow.angle(now: t0.addingTimeInterval(dt))
        )
    }

    // MARK: 冻结 ↔ 无缝续转（轨迹双弧收拢/复位核心契约）

    func testFreezeHoldsAndResumeContinuesSeamlessly() {
        var c = SpinClock(period: 1, direction: 1, phase: 0, base: t0)
        // 转环按住瞬间：冻结在当前角（90°）
        let frozenAt = t0.addingTimeInterval(0.25)
        let frozenAngle = c.angle(now: frozenAt)
        c = c.frozen(at: frozenAt)
        XCTAssertEqual(c.frozenAngle, frozenAngle, accuracy: 0.001)
        XCTAssertEqual(frozenAngle, 90, accuracy: 0.001)
        // 拖动期间（隐藏不渲染）：恢复后第一帧 = 冻结值（不补偿收拢期时间、不跳变）
        c = c.resumed(at: t0.addingTimeInterval(2.0))
        XCTAssertEqual(c.angle(now: t0.addingTimeInterval(2.0)), frozenAngle, accuracy: 0.001)
        // 之后照常推进（松手 0.25s 后 = 冻结值 + 90°）
        XCTAssertEqual(c.angle(now: t0.addingTimeInterval(2.25)), frozenAngle + 90, accuracy: 0.001)
    }

    func testRepeatedFreezeResumeCycles() {
        // 任意次数冻结/恢复（转环反复按、模块反复进出）
        var c = SpinClock(period: 2, direction: 1, phase: 10, base: t0)
        var now = t0
        for _ in 0..<5 {
            now = now.addingTimeInterval(0.3)
            c = c.frozen(at: now)          // 按住
            now = now.addingTimeInterval(1.0)
            c = c.resumed(at: now)         // 松手
            XCTAssertEqual(c.angle(now: now), c.frozenAngle, accuracy: 0.001)   // 复位即冻结值
        }
        // 松手后继续转
        XCTAssertEqual(c.angle(now: now.addingTimeInterval(1.0)), c.frozenAngle + 180, accuracy: 0.001)
    }

    func testResumeWithoutFreezeIsSafe() {
        // 防御：未冻结直接 resume（如首帧手势误触发）只重置 base，不错乱
        let c = SpinClock(period: 2, direction: 1, phase: 10, base: t0)
        let r = c.resumed(at: t0.addingTimeInterval(5))
        XCTAssertEqual(r.angle(now: t0.addingTimeInterval(5)), 10, accuracy: 0.001)
    }

    func testEquatableAndSnapshot() {
        // 冻结后时钟值稳定（Equatable 快照——后续 UI 断言可用）
        let c1 = SpinClock(period: 42, direction: -1, phase: 145, base: t0)
        XCTAssertEqual(c1, SpinClock(period: 42, direction: -1, phase: 145, base: t0))
        XCTAssertNotEqual(c1, c1.frozen(at: t0.addingTimeInterval(1)))
    }
}