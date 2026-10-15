import XCTest
@testable import FlipCompass

/// 方向翻转引擎单元测试（R8 · V2.1 抬起-复位方向事件：
/// 静止校准 → 快速尖峰（分轴单向积分判方向）→ 停稳窗口 → 确认 direction + finalOrientation）
@MainActor
final class FlipStateEngineTests: XCTestCase {

    /// 静置武装（> armStillFrames=18 帧）；默认手持竖正姿态
    private func arm(_ kit: MotionKit, as orientation: DeviceOrientation = .portrait) {
        for _ in 0..<21 { kit.stepState(velocity: 0.05, rotationRate: (0, 0, 0), target: orientation) }
    }

    func testInitialStateIsIdle() {
        let kit = MotionKit(preview: true)
        XCTAssertEqual(kit.flipState, .idle)
        XCTAssertFalse(kit.armed, "初始未静止校准，不应武装")
    }

    /// 初始化不急：未武装前任何快速动作都不触发方向事件
    func testInitNotArmedNoTrigger() {
        let kit = MotionKit(preview: true)
        kit.stepState(velocity: 2.5, rotationRate: (2.5, 0, 0), target: .portrait)
        XCTAssertEqual(kit.flipState, .idle, "未校准零位前的尖峰（如拿起手机的晃动）不应触发")
    }

    /// 静止武装 → 快速尖峰触发挥转事件
    func testArmAfterStillThenTrigger() {
        let kit = MotionKit(preview: true)
        arm(kit)
        XCTAssertTrue(kit.armed)
        XCTAssertEqual(kit.originOrientation, .portrait, "零位朝向 = 静止时的朝向")
        kit.stepState(velocity: 2.5, rotationRate: (2.5, 0, 0), target: .portrait)
        guard case .flipping = kit.flipState else {
            return XCTFail("武装后快速尖峰应触发方向事件，实际：\(kit.flipState)")
        }
        XCTAssertFalse(kit.armed, "事件触发后解除武装")
    }

    /// ★ 抬起-复位核心：绕 X 正转 40° 再反转 40°（净位移≈0，回原位）——
    ///   靠单向积分（正向 40° ≥35°）应确认 direction = .up
    func testLiftAndReturnConfirmsUp() {
        let kit = MotionKit(preview: true)
        kit.settleWindowOverrideFastForTest()
        arm(kit, as: .faceUp)                                     // 零位平放（桌面拿起看）
        // 抬起段：绕 X+ 旋转 40°（多帧高速，rate.x > 0）
        for _ in 0..<20 { kit.stepState(velocity: 3.0, rotationRate: (3.0, 0, 0), target: nil, dt: 0.012) }
        // 复位段：绕 X- 旋转 40°（速度低于尖峰阈值但仍在转）
        for _ in 0..<28 { kit.stepState(velocity: 1.4, rotationRate: (-1.4, 0, 0), target: nil, dt: 0.012) }
        // 静止 + 窗口期满
        for _ in 0..<6 { kit.stepState(velocity: 0.05, rotationRate: (0, 0, 0), target: .faceUp) } // 复位朝向回平放(模糊→faceUp)
        let exp = expectation(description: "confirmed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            kit.stepState(velocity: 0.05, rotationRate: (0, 0, 0), target: .faceUp)
            XCTAssertEqual(kit.confirmedDirection, .up,
                           "抬起-复位（X+ 单向 40°，净位移 0）应确认 up —— 本期映射 M1")
            XCTAssertEqual(kit.confirmedOrientation, .faceUp, "停稳朝向=复位后的平放")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// 纯下压动作（绕 X- 主导）→ direction = .down（本期 App 层忽略，但引擎输出正确）
    func testDownFlickDirectionValue() {
        let kit = MotionKit(preview: true)
        kit.settleWindowOverrideFastForTest()
        arm(kit)
        for _ in 0..<20 { kit.stepState(velocity: 3.0, rotationRate: (-3.0, 0, 0), target: .portrait, dt: 0.012) }
        for _ in 0..<6 { kit.stepState(velocity: 0.05, rotationRate: (0, 0, 0), target: .portrait) }
        let exp = expectation(description: "confirmed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            kit.stepState(velocity: 0.05, rotationRate: (0, 0, 0), target: .portrait)
            XCTAssertEqual(kit.confirmedDirection, .down)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// 手腕内旋（绕 Z+ 主导）→ direction = .left
    func testTwistLeftDirectionValue() {
        let kit = MotionKit(preview: true)
        kit.settleWindowOverrideFastForTest()
        arm(kit)
        for _ in 0..<20 { kit.stepState(velocity: 3.0, rotationRate: (0, 0, 3.0), target: .portrait, dt: 0.012) }
        for _ in 0..<6 { kit.stepState(velocity: 0.05, rotationRate: (0, 0, 0), target: .landscapeLeft) }
        let exp = expectation(description: "confirmed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            kit.stepState(velocity: 0.05, rotationRate: (0, 0, 0), target: .landscapeLeft)
            XCTAssertEqual(kit.confirmedDirection, .left)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// 假动作：单帧尖峰但单向积分 <35° → 不确认
    func testFakeFlickIgnored() {
        let kit = MotionKit(preview: true)
        arm(kit)
        kit.stepState(velocity: 2.0, rotationRate: (2.0, 0, 0), target: .portrait)  // 单帧 ≈1.9°
        XCTAssertEqual(kit.flipState, .flipping(target: .portrait))
        kit.stepState(velocity: 0.1, rotationRate: (0, 0, 0), target: .portrait, dt: 0.01)
        XCTAssertEqual(kit.flipState, .idle, "偶发小尖峰（单向 ~2° < 35°）不应进入确认")
        XCTAssertFalse(kit.armed)
        XCTAssertNil(kit.confirmedDirection, "假动作不应产出方向")
    }

    /// 幅度不足的完整往复（抬起 20° 复位 20°）→ 不确认
    func testSmallLiftReturnIgnored() {
        let kit = MotionKit(preview: true)
        arm(kit)
        for _ in 0..<6 { kit.stepState(velocity: 3.0, rotationRate: (3.0, 0, 0), target: nil, dt: 0.012) }  // 抬起 ~20°~
        for _ in 0..<6 { kit.stepState(velocity: 1.4, rotationRate: (-1.4, 0, 0), target: nil, dt: 0.012) } // 复位 ~-20°
        kit.stepState(velocity: 0.05, rotationRate: (0, 0, 0), target: .portrait)
        XCTAssertEqual(kit.flipState, .idle, "往复单向 20° < 35° 门槛 → 假动作忽略")
        XCTAssertNil(kit.confirmedDirection)
    }

    /// 序列内再翻（连续把玩不需重新武装）
    func testReflipDuringSettling() {
        let kit = MotionKit(preview: true)
        arm(kit)
        for _ in 0..<20 { kit.stepState(velocity: 3.0, rotationRate: (3.0, 0, 0), target: .portrait, dt: 0.012) }
        for _ in 0..<3 { kit.stepState(velocity: 0.1, rotationRate: (0, 0, 0), target: .portrait) }   // settling
        kit.stepState(velocity: 2.8, rotationRate: (0, 0, 2.8), target: .portrait, dt: 0.3)           // 再翻（换轴）
        XCTAssertEqual(kit.flipState, .flipping(target: .portrait), "settle 中尖峰应回 flipping（同序列）")
    }

    func testAdaptiveWindowPicksShorterForHigherVelocity() {
        let kit = MotionKit(preview: true)
        kit.fastSettleWindowMs = 100
        kit.slowSettleWindowMs = 400
        kit.angularVelocityThreshold = 1.6
        XCTAssertLessThan(kit.pickWindowMs(velocity: 1.5), kit.pickWindowMs(velocity: 0.1))
        XCTAssertEqual(kit.pickWindowMs(velocity: 1.5), 100)
        XCTAssertEqual(kit.pickWindowMs(velocity: 0.1), 400)
    }

    func testOrientationFromGravity() {
        XCTAssertEqual(MotionKit.orientation(fromGravityX: 0, y: 0, z: -1), .faceUp)
        XCTAssertEqual(MotionKit.orientation(fromGravityX: 0, y: 0, z: 1), .faceDown)
        XCTAssertEqual(MotionKit.orientation(fromGravityX: 0, y: -1, z: 0), .portrait)
        XCTAssertEqual(MotionKit.orientation(fromGravityX: 0, y: 1, z: 0), .portraitUpsideDown)
        XCTAssertEqual(MotionKit.orientation(fromGravityX: -1, y: 0, z: 0), .landscapeLeft)
        XCTAssertEqual(MotionKit.orientation(fromGravityX: 1, y: 0, z: 0), .landscapeRight)
        XCTAssertNil(MotionKit.orientation(fromGravityX: 0.577, y: 0.577, z: 0.577))
    }

    /// 方向映射纯函数
    func testFlipDirectionMapping() {
        let pos = (x: 40.0, y: 0.0, z: 0.0), neg = (x: 0.0, y: 0.0, z: 0.0)
        XCTAssertEqual(MotionKit.flipDirection(pos: pos, neg: neg), .up, "X+ 主导 = 上")
        XCTAssertEqual(MotionKit.flipDirection(pos: (0,0,0), neg: (40,0,0)), .down, "X- 主导 = 下")
        XCTAssertEqual(MotionKit.flipDirection(pos: (0,0,40), neg: (0,0,0)), .left, "Z+ 主导 = 左")
        XCTAssertEqual(MotionKit.flipDirection(pos: (0,0,0), neg: (0,0,40)), .right, "Z- 主导 = 右")
        XCTAssertNil(MotionKit.flipDirection(pos: (0,40,0), neg: (0,0,0)), "纯 Y 滚转不映射四向")
        XCTAssertNil(MotionKit.flipDirection(pos: (30,35,0), neg: (0,0,0)), "Y 轴占比过高（复合抖动）不判向")
    }
}

// 测试辅助：缩短确认窗口等待
extension MotionKit {
    func settleWindowOverrideFastForTest() {
        fastSettleWindowMs = 100
        slowSettleWindowMs = 150
    }
}
