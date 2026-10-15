import Foundation
import CoreMotion
import Combine
import SwiftUI

/// CoreMotion 四朝向判定引擎（R8 + T1）
/// 四态状态机：IDLE → FLIPPING（主动动作识别）→ SETTLING（角速度自然衰减）
/// → CONFIRMED（朝向稳定 + 自适应停留窗口）
///
/// 真机调优参数（R8）：角速度阈值 / 衰减阈值 / 自适应窗口极值
/// 所有判定过程全量记录到 MotionLogEntry（本地 SwiftData）
@MainActor
final class MotionKit: ObservableObject {
    @Published private(set) var flipState: FlipState = .idle
    @Published private(set) var confirmedOrientation: DeviceOrientation = .faceUp
    @Published private(set) var currentAngle: Double = 0
    @Published private(set) var currentAngularVelocity: Double = 0
    @Published var loggingEnabled: Bool = true

    // 调优参数（R8 真机标定）
    var angularVelocityThreshold: Double = 1.6       // rad/s，主动翻转识别
    var settlingVelocityThreshold: Double = 0.35    // 角速度衰减到此值以下视为停稳
    var fastSettleWindowMs: Int = 180                // 快翻短窗口
    var slowSettleWindowMs: Int = 600                // 慢倾斜长窗口
    var stabilizationTimeoutMs: Int = 3000          // 长时间不稳定回 IDLE
    var hysteresisAngle: Double = 12                // 迟滞防边界抖动（度）
    var faceDownAsIdle: Bool = true                  // faceDown 也回待机

    // 自适应窗口状态：窗口由"本次翻转的峰值速度"定档（翻得多快），
    // 而非当前已衰减速度——否则进入 settle 时速度必低于停稳阈值，快窗口永远选不中
    private var peakFlipVelocity: Double = 0
    private var settleWindowMs: Int = 600

    private let manager = CMMotionManager()
    private var stateTimer: Date? = nil
    private var lastStateChange: Date = .now
    private var lastLogTime: Date = .now
    private let updateInterval: TimeInterval = 1.0 / 60.0
    private(set) var isPreview: Bool

    init(preview: Bool = false) {
        self.isPreview = preview
    }

    func start() {
        guard !isPreview else { return }
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = updateInterval
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            self.process(data: data)
        }
    }

    func stop() {
        if manager.isDeviceMotionActive {
            manager.stopDeviceMotionUpdates()
        }
        flipState = .idle
    }

    // MARK: - 单元测试入口（同步喂入 motion 数据）
    func process(data: CMDeviceMotion) {
        let attitude = data.attitude
        let roll = attitude.roll    // 绕 X 轴（左右倾）
        let pitch = attitude.pitch  // 绕 Y 轴（前后倾）
        let yaw = attitude.yaw      // 绕 Z 轴
        let rotationRate = data.rotationRate
        let magnitude = sqrt(rotationRate.x * rotationRate.x
                             + rotationRate.y * rotationRate.y
                             + rotationRate.z * rotationRate.z)
        currentAngle = computeAzimuth(pitch: pitch, roll: roll, yaw: yaw)
        currentAngularVelocity = magnitude
        let target = computeOrientation(pitch: pitch, roll: roll)
        stepState(velocity: magnitude, target: target)
        if loggingEnabled, Date().timeIntervalSince(lastLogTime) > 0.1 {
            lastLogTime = Date()
            // 日志只入内存，由 AppState/调试页持久化（避免主线程 IO）
            NotificationCenter.default.post(
                name: .motionLogTick,
                object: nil,
                userInfo: ["state": flipState.rawValue as Any,
                           "velocity": magnitude as Any,
                           "angle": currentAngle as Any,
                           "target": target.rawValue as Any]
            )
        }
    }

    // MARK: - 四态状态机核心
    func stepState(velocity: Double, target: DeviceOrientation?) {
        let now = Date()
        let target = target ?? .faceUp
        switch flipState {
        case .idle:
            if velocity > angularVelocityThreshold {
                peakFlipVelocity = velocity
                enter(.flipping(target: target), reason: "velocity \(velocity) > threshold")
            }
        case .flipping(let current):
            peakFlipVelocity = max(peakFlipVelocity, velocity)
            if velocity < settlingVelocityThreshold {
                // 窗口按本次翻转峰值速度定档：快翻→短窗口，慢倾→长窗口
                settleWindowMs = pickWindowMs(velocity: peakFlipVelocity)
                enter(.settling(target: current), reason: "velocity decayed \(velocity)")
            } else if target != current {
                // 翻转中改变目标
                enter(.flipping(target: target), reason: "retarget to \(target.rawValue)")
            }
            if elapsedMs(now) > stabilizationTimeoutMs {
                enter(.idle, reason: "timeout")
            }
        case .settling(let current):
            if velocity > angularVelocityThreshold {
                peakFlipVelocity = velocity
                enter(.flipping(target: target), reason: "re-flip \(velocity)")
                return
            }
            let elapsed = elapsedMs(now)
            if elapsed >= settleWindowMs && target == current {
                enter(.confirmed, reason: "settled \(elapsed)ms")
                confirmedOrientation = current
                // 一次性事件，立即回 IDLE 等待下次
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.enter(.idle, reason: "post-confirm reset")
                }
            } else if elapsed > stabilizationTimeoutMs {
                enter(.idle, reason: "settle timeout")
            }
        case .confirmed:
            // 一次性态，已在 above 异步复位
            break
        }
    }

    // MARK: - 自适应窗口（R8 核心：快翻短窗口、慢倾斜长窗口）
    /// 极值吸附：≤停稳阈值 → 慢窗口；≥0.9×翻转阈值 → 快窗口；中间线性过渡。
    /// 入参应为本次翻转的峰值速度（定档依据是"翻得多快"，而非当前衰减速度）
    func pickWindowMs(velocity: Double) -> Int {
        if velocity <= settlingVelocityThreshold { return slowSettleWindowMs }
        let fastZone = angularVelocityThreshold * 0.9
        guard fastZone > settlingVelocityThreshold else { return fastSettleWindowMs }
        if velocity >= fastZone { return fastSettleWindowMs }
        let ratio = (velocity - settlingVelocityThreshold) / (fastZone - settlingVelocityThreshold)
        let win = Int(Double(slowSettleWindowMs) - ratio * Double(slowSettleWindowMs - fastSettleWindowMs))
        return max(fastSettleWindowMs, win)
    }

    // MARK: - 朝向计算（基于 pitch/roll，简化版；真机调优再细化）
    func computeOrientation(pitch: Double, roll: Double) -> DeviceOrientation {
        // pitch 接近 ±π/2 = faceUp/faceDown
        let pitchDeg = pitch * 180 / .pi
        let rollDeg = roll * 180 / .pi
        if abs(pitchDeg) > 60 {
            return pitchDeg > 0 ? .faceUp : .faceDown
        }
        // 四向判定：以 roll 为主轴（左横/右横），pitch 区分竖正/竖倒
        if abs(rollDeg) > 45 {
            return rollDeg > 0 ? .landscapeRight : .landscapeLeft
        } else {
            return pitchDeg > 0 ? .portraitUpsideDown : .portrait
        }
    }

    func computeAzimuth(pitch: Double, roll: Double, yaw: Double) -> Double {
        // 简化：以 roll 为主方位角
        return roll * 180 / .pi
    }

    private func enter(_ next: FlipState, reason: String) {
        let prev = flipState
        flipState = next
        lastStateChange = Date()
        if loggingEnabled {
            NotificationCenter.default.post(
                name: .motionStateChange,
                object: nil,
                userInfo: ["prev": prev.rawValue as Any,
                           "next": next.rawValue as Any,
                           "reason": reason as Any]
            )
        }
    }

    private func elapsedMs(_ now: Date) -> Int {
        Int(now.timeIntervalSince(lastStateChange) * 1000)
    }
}

extension Notification.Name {
    static let motionLogTick = Notification.Name("flipcompass.motion.logTick")
    static let motionStateChange = Notification.Name("flipcompass.motion.stateChange")
}
