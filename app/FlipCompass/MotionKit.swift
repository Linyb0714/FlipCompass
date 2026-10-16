import Foundation
import CoreMotion
import Combine
import SwiftUI

/// 翻转方向（四向导航语义 · 抬起-复位往复动作的主导旋转方向）
/// 设备坐标系：x 右（短边）、y 上（长边顶部）、z 出屏幕朝用户。
/// 绕 X+（俯仰，顶部朝自己/朝上翘）= .up；绕 X- = .down；
/// 绕 Z+（手腕内旋，用户视角逆时针）= .left；绕 Z- = .right；绕 Y（沿长边滚转）不映射。
enum FlipDirection: String {
    case up, down, left, right
}

/// CoreMotion 四朝向翻转引擎（R8 + T1 · V2.1 抬起-复位方向事件模型）
///
/// **用户定稿（2026-10-13）**：实际把玩的动作是「抬起-复位」往复运动，
/// 事件特征清晰；本期仅监听「上」方向（→ M1）。
///
/// 1. 静止校准（armed）：IDLE 下角速度连续 ~300ms 低于 0.15 rad/s → 武装并记录零位。
///    手机任何姿态可作零位，初始化不急着判角度；拿起手机的尖峰不触发。
/// 2. 方向事件：armed 后尖峰 > 阈值进入 FLIPPING，期间对角速度**分轴单向积分**
///    （抬起 +30° 复位 -30° 净位移≈0，但单向积分保留 30°——往复动作的方向靠它判定）；
///    衰减时最大单向积分 ≥35° 才进 SETTLING（假动作过滤）。
/// 3. 动作确认：自适应窗口期满（不再要求朝向变化/一致——抬起-复位可回原位）
///    → CONFIRMED 输出 **flipDirection（主导旋转方向）+ finalOrientation（停稳时重力朝向）**
///    → 0.05s 后回 IDLE 并解除武装。
///    消费方（AppState）：up → M1；finalOrientation 为平放 → 收拢回待机；其余本期忽略。
///
/// 四态：IDLE → FLIPPING → SETTLING → CONFIRMED
///
/// 真机调优参数（R8）与全量日志（MotionLog · B 阶段接调试页）
@MainActor
final class MotionKit: ObservableObject {
    @Published private(set) var flipState: FlipState = .idle
    @Published private(set) var confirmedOrientation: DeviceOrientation = .faceUp
    @Published private(set) var confirmedDirection: FlipDirection? = nil   // 最近确认的翻转方向
    // 性能修复（全局迟滞 2026-10-16）：两高频量降级为普通存储——每帧（60Hz）@Published 写入
    // 会广播 objectWillChange 驱动订阅视图全树重 diff；App 内除调试日志外零消费方，
    // 待机页动画已由 TimelineView 局部驱动，不需要它们参与视图更新（读时取快照即可）
    private(set) var currentAngle: Double = 0
    private(set) var currentAngularVelocity: Double = 0
    @Published private(set) var armed: Bool = false   // 静止已校准，可触发翻转事件
    @Published var loggingEnabled: Bool = true

    // 调优参数（R8 真机标定）
    var angularVelocityThreshold: Double = 1.6       // rad/s，主动翻转尖峰识别
    var settlingVelocityThreshold: Double = 0.35    // 角速度衰减到此值以下视为停稳
    var fastSettleWindowMs: Int = 180                // 快翻短窗口
    var slowSettleWindowMs: Int = 600                // 慢倾斜长窗口
    var stabilizationTimeoutMs: Int = 3000          // 长时间不稳定回 IDLE
    var hysteresisAngle: Double = 12                // 迟滞防边界抖动（度）
    var faceDownAsIdle: Bool = true                  // faceDown 也回待机

    // —— 事件模型参数 ——
    var stillVelocityThreshold: Double = 0.15       // rad/s，低于此视为静止
    var armStillFrames: Int = 18                    // 连续静止帧数（~300ms @60Hz）武装零位
    var minFlipRotationDeg: Double = 35             // 单向最小旋角门槛（防偶发尖峰；往复动作看单向积分）

    // —— 事件模型状态 ——
    /// 零位（静止基准）：最近一次静止时的重力向量；手机任何姿态可作零位
    private(set) var originGravity: (x: Double, y: Double, z: Double)? = nil
    /// 零位朝向（origin 重力判定的朝向）
    private(set) var originOrientation: DeviceOrientation = .faceUp
    private var stillFrames = 0
    /// 分轴单向积分（度）：抬起-复位往复动作净位移≈0，方向判定靠单向累计
    private(set) var accumPos = (x: 0.0, y: 0.0, z: 0.0)   // 正向累计
    private(set) var accumNeg = (x: 0.0, y: 0.0, z: 0.0)   // 反向累计

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
        // 幂等：重复 start 不叠加回调链
        guard !manager.isDeviceMotionActive else { return }
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
        let rotationRate = data.rotationRate
        let magnitude = sqrt(rotationRate.x * rotationRate.x
                             + rotationRate.y * rotationRate.y
                             + rotationRate.z * rotationRate.z)
        let g = data.gravity
        currentAngle = computeAzimuth(gx: g.x, gy: g.y)
        currentAngularVelocity = magnitude
        // R8：朝向由重力向量判定（attitude.pitch 语义是平放=0°/竖持=±90°，
        // 若把 |pitch|>60° 当作平放会把竖正拿误判成 faceUp，四向翻转全部失灵；
        // gravity 直接给出重力在设备系的投影，六朝向判定稳定无漂移）
        let target = Self.orientation(fromGravityX: g.x, y: g.y, z: g.z)
        stepState(
            velocity: magnitude,
            rotationRate: (rotationRate.x, rotationRate.y, rotationRate.z),
            target: target,
            dt: updateInterval,
            gravity: (g.x, g.y, g.z)
        )
        if loggingEnabled, Date().timeIntervalSince(lastLogTime) > 0.1 {
            lastLogTime = Date()
            // 日志只入内存，由 AppState/调试页持久化（避免主线程 IO）
            NotificationCenter.default.post(
                name: .motionLogTick,
                object: nil,
                userInfo: ["state": flipState.rawValue as Any,
                           "velocity": magnitude as Any,
                           "angle": currentAngle as Any,
                           "target": (target?.rawValue ?? "-") as Any,
                           "armed": armed as Any]
            )
        }
    }

    // MARK: - 状态机核心（抬起-复位方向事件模型）
    /// - Parameters:
    ///   - rotationRate: 本帧角速度分量（分轴单向积分判方向）
    ///   - dt: 本帧时间步长（默认 60Hz 一帧）
    ///   - gravity: 本帧重力向量（静止武装时记录零位）
    ///   - target: 本帧重力判定的朝向（可 nil —— 约 45° 斜持模糊区）
    func stepState(velocity: Double, rotationRate: (x: Double, y: Double, z: Double), target: DeviceOrientation?, dt: TimeInterval = 1.0 / 60.0, gravity: (x: Double, y: Double, z: Double)? = nil) {
        let now = Date()

        // —— 静止校准（仅 IDLE）：持续 ~300ms 低速 → 武装 + 刷新零位（当前位置与角度）——
        if flipState == .idle {
            if velocity < stillVelocityThreshold {
                stillFrames += 1
                if stillFrames >= armStillFrames {
                    if !armed { armed = true }
                    if let g = gravity { originGravity = g }
                    if let t = target { originOrientation = t }
                }
            } else {
                stillFrames = 0
            }
        }

        // 分轴单向积分（度）：正向/反向分别累计，不抵消——
        // 「抬起+30° 复位-30°」净位移≈0，但正向积分保留 30°（方向判定的依据）
        let dx = rotationRate.x * dt * 180 / .pi
        let dy = rotationRate.y * dt * 180 / .pi
        let dz = rotationRate.z * dt * 180 / .pi
        if dx > 0 { accumPos.x += dx } else { accumNeg.x += -dx }
        if dy > 0 { accumPos.y += dy } else { accumNeg.y += -dy }
        if dz > 0 { accumPos.z += dz } else { accumNeg.z += -dz }

        switch flipState {
        case .idle:
            // 事件先决：必须静止武装（初始化不急着判角度；拿起手机的晃动尖峰不触发）
            guard armed, velocity > angularVelocityThreshold else { break }
            // 方向事件开始
            armed = false
            stillFrames = 0
            peakFlipVelocity = velocity
            enter(.flipping(target: target ?? originOrientation), reason: "flip event v=\(velocity)")

        case .flipping:
            peakFlipVelocity = max(peakFlipVelocity, velocity)
            if velocity < settlingVelocityThreshold {
                if Self.maxOneWayAccumDeg(pos: accumPos, neg: accumNeg) >= minFlipRotationDeg {
                    // 窗口按本次翻转峰值速度定档：快翻→短窗口，慢倾→长窗口
                    settleWindowMs = pickWindowMs(velocity: peakFlipVelocity)
                    enter(.settling(target: target ?? originOrientation),
                          reason: "decayed, one-way \(Int(Self.maxOneWayAccumDeg(pos: accumPos, neg: accumNeg)))°")
                } else {
                    // 偶发尖峰但单向幅度不足 → 假动作，清积分回 IDLE 重新静止校准
                    resetAccum()
                    stillFrames = 0
                    enter(.idle, reason: "flick too small")
                }
            } else if elapsedMs(now) > stabilizationTimeoutMs {
                resetAccum()
                enter(.idle, reason: "timeout")
            }

        case .settling:
            if velocity > angularVelocityThreshold {
                // 同一序列内再翻（不需重新武装，翻转事件本就连续）
                peakFlipVelocity = max(peakFlipVelocity, velocity)
                enter(.flipping(target: target ?? originOrientation), reason: "re-flip \(velocity)")
                return
            }
            // 窗口期满 → 动作完成确认（不要求朝向变化/一致——抬起-复位可回原位）
            let elapsed = elapsedMs(now)
            if elapsed >= settleWindowMs {
                let direction = Self.flipDirection(pos: accumPos, neg: accumNeg)
                let final = target ?? originOrientation
                let dirText = direction?.rawValue ?? "nil"
                enter(.confirmed, reason: "settled \(elapsed)ms, dir=\(dirText), \(final.rawValue)")
                confirmedDirection = direction
                confirmedOrientation = final
                resetAccum()
                // 一次性事件完成 → 回 IDLE 并解除武装（下次方向事件需重新静止校准）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.enter(.idle, reason: "post-confirm reset")
                }
            } else if elapsed > stabilizationTimeoutMs {
                resetAccum()
                enter(.idle, reason: "settle timeout")
            }

        case .confirmed:
            // 一次性态，已在 above 异步复位
            break
        }
    }

    // MARK: - 方向判定（分轴单向积分）

    private func resetAccum() {
        accumPos = (0, 0, 0)
        accumNeg = (0, 0, 0)
    }

    /// 最大单向积分（度）—— 幅度门槛（假动作过滤）
    static func maxOneWayAccumDeg(pos: (x: Double, y: Double, z: Double), neg: (x: Double, y: Double, z: Double)) -> Double {
        max(max(pos.x, neg.x), max(pos.y, neg.y), max(pos.z, neg.z))
    }

    /// 主导旋转方向：取单向积分最大的轴与符号映射四向。
    /// X+/X- = 俯仰（上抬/下压）；Z+/Z- = 手腕内旋（左/右）；绕 Y（长边滚转）不映射 → nil。
    /// 本期消费方仅启用 .up（→ M1），其余返回后由 AppState 忽略。
    static func flipDirection(pos: (x: Double, y: Double, z: Double), neg: (x: Double, y: Double, z: Double)) -> FlipDirection? {
        var candidates: [(Double, FlipDirection)] = [
            (pos.x, .up), (neg.x, .down),
            (pos.z, .left), (neg.z, .right),
        ]
        candidates.sort { $0.0 > $1.0 }
        guard let best = candidates.first, best.0 > 0 else { return nil }
        // 主导优势检验：比第二名（含 Y 轴滚转）至少大 20%，避免复合方向抖动
        let yMax = max(pos.y, neg.y)
        if best.0 < yMax * 1.2 { return nil }
        return best.1
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

    // MARK: - 朝向判定（重力向量 · R8 四向翻转核心）
    /// 设备坐标系：x 右、y 上沿长边、z 出屏幕；g = 重力在设备系的单位向量。
    /// 平放屏幕朝上 g=(0,0,-1)；竖正(home 键在下) g=(0,-1,0)；竖倒 g=(0,1,0)；
    /// 左横（逆时针转 90°、顶边朝左）g=(-1,0,0)；右横 g=(1,0,0)。
    /// 约 45° 斜持（最大分量 <0.6）为模糊区，返回 nil 不判向（翻转过程中间态不误导航）。
    static func orientation(fromGravityX gx: Double, y gy: Double, z gz: Double) -> DeviceOrientation? {
        let ax = abs(gx), ay = abs(gy), az = abs(gz)
        let m = max(ax, ay, az)
        guard m > 0.6 else { return nil }
        if az == m { return gz < 0 ? .faceUp : .faceDown }
        if ay == m { return gy < 0 ? .portrait : .portraitUpsideDown }
        return gx < 0 ? .landscapeLeft : .landscapeRight
    }

    /// 方位角（调试展示用）：重力相对竖正位的角
    func computeAzimuth(gx: Double, gy: Double) -> Double {
        return atan2(gx, -gy) * 180 / .pi
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
