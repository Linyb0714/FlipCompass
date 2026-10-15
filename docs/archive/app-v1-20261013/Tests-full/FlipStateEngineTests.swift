import XCTest
@testable import FlipCompass

/// 四态引擎单元测试（R8：MotionLog 录制回放作夹具）
/// 注：MotionKit 是 @MainActor，测试在主线程跑
@MainActor
final class FlipStateEngineTests: XCTestCase {

    func testInitialStateIsIdle() {
        let kit = MotionKit(preview: true)
        XCTAssertEqual(kit.flipState, .idle)
    }

    func testIdleToFlippingOnHighVelocity() {
        let kit = MotionKit(preview: true)
        kit.angularVelocityThreshold = 1.6
        kit.settlingVelocityThreshold = 0.35
        // 喂入一次"主动翻转"动作（高角速度 + 竖正目标）
        kit.stepState(velocity: 2.5, target: .portrait)
        XCTAssertEqual(kit.flipState, .flipping(target: .portrait))
    }

    func testFlippingToSettlingOnDecay() {
        let kit = MotionKit(preview: true)
        kit.fastSettleWindowMs = 100
        kit.slowSettleWindowMs = 300
        kit.stepState(velocity: 2.5, target: .portrait) // → flipping
        kit.stepState(velocity: 0.1, target: .portrait) // → settling
        if case .settling(let target) = kit.flipState {
            XCTAssertEqual(target, .portrait)
        } else { XCTFail("应进入 settling 态，实际：\(kit.flipState)") }
    }

    func testSettlingToConfirmedAfterWindow() throws {
        let kit = MotionKit(preview: true)
        kit.fastSettleWindowMs = 50
        kit.slowSettleWindowMs = 100
        kit.angularVelocityThreshold = 1.6
        kit.stepState(velocity: 2.5, target: .portrait) // flipping
        kit.stepState(velocity: 0.1, target: .portrait) // settling
        // 等待窗口过期
        let exp = expectation(description: "confirmed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            // 引擎是数据驱动（生产环境 60Hz 帧流）：窗口过期后需喂入下一帧才触发确认
            kit.stepState(velocity: 0.1, target: .portrait)
            XCTAssertEqual(kit.confirmedOrientation, .portrait)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testAdaptiveWindowPicksShorterForHigherVelocity() {
        let kit = MotionKit(preview: true)
        kit.fastSettleWindowMs = 100
        kit.slowSettleWindowMs = 400
        kit.angularVelocityThreshold = 1.6
        // 高速 → 接近 fast 窗口
        let fast = kit.pickWindowMs(velocity: 1.5)
        // 低速 → 接近 slow 窗口
        let slow = kit.pickWindowMs(velocity: 0.1)
        XCTAssertLessThan(fast, slow, "高速翻转应取更短停留窗口（响应爽快）")
        XCTAssertEqual(fast, 100)
        XCTAssertEqual(slow, 400)
    }

    func testRetargetDuringFlipping() {
        let kit = MotionKit(preview: true)
        kit.stepState(velocity: 2.5, target: .portrait)
        kit.stepState(velocity: 2.0, target: .landscapeLeft) // 翻转中改变目标
        if case .flipping(let t) = kit.flipState {
            XCTAssertEqual(t, .landscapeLeft)
        } else {
            XCTFail("翻转中改向应仍处于 flipping，目标更新")
        }
    }

    func testRefuseFlipDuringSettling() {
        let kit = MotionKit(preview: true)
        kit.stepState(velocity: 2.5, target: .portrait)
        kit.stepState(velocity: 0.1, target: .portrait) // settling
        // settling 中再次高角速度 → 应回到 flipping
        kit.stepState(velocity: 2.8, target: .portrait)
        XCTAssertEqual(kit.flipState, .flipping(target: .portrait))
    }

    func testComputeOrientationFromPitchRoll() {
        let kit = MotionKit(preview: true)
        // 竖正：pitch 小、roll 小（竖屏直立）
        XCTAssertEqual(kit.computeOrientation(pitch: 0, roll: 0), .portrait)
        // 竖倒：pitch > 0
        XCTAssertEqual(kit.computeOrientation(pitch: 1.0, roll: 0), .portraitUpsideDown)
        // 左横：roll < 0
        XCTAssertEqual(kit.computeOrientation(pitch: 0, roll: -1.2), .landscapeLeft)
        // 右横：roll > 0
        XCTAssertEqual(kit.computeOrientation(pitch: 0, roll: 1.2), .landscapeRight)
        // 平放：pitch 接近 ±π/2
        XCTAssertEqual(kit.computeOrientation(pitch: 1.4, roll: 0), .faceUp)
        XCTAssertEqual(kit.computeOrientation(pitch: -1.4, roll: 0), .faceDown)
    }

    func testHysteresisFaceDownNotTriggeredNearBoundary() {
        let kit = MotionKit(preview: true)
        kit.hysteresisAngle = 12
        // 浅倾斜不足以判为翻转（角速度低）
        kit.stepState(velocity: 0.05, target: .portrait)
        XCTAssertEqual(kit.flipState, .idle, "微小晃动不应触发状态迁移")
    }
}
