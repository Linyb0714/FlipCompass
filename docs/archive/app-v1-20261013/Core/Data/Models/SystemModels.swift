import Foundation
import SwiftData

// MARK: - 真机调试日志（R8 + T1：四态判定 + 旋转系统层统一日志）
/// 同 MotionLog.swift 中的 SwiftData 实体（避免命名冲突，这里称为 MotionLogEntry）
@Model
final class MotionLogEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var state: String               // FlipState rawValue
    var angularVelocity: Double
    var orientationAngle: Double
    var targetOrientation: String?
    var windowDurationMs: Int?
    var triggered: Bool
    var reason: String?

    init(id: UUID = UUID(), timestamp: Date = .now,
         state: String, angularVelocity: Double = 0,
         orientationAngle: Double = 0, targetOrientation: String? = nil,
         windowDurationMs: Int? = nil, triggered: Bool = false,
         reason: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.state = state
        self.angularVelocity = angularVelocity
        self.orientationAngle = orientationAngle
        self.targetOrientation = targetOrientation
        self.windowDurationMs = windowDurationMs
        self.triggered = triggered
        self.reason = reason
    }
}
