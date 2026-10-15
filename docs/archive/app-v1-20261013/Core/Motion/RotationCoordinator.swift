import Foundation
import UIKit

/// 受控系统旋转（T1 方案 B）
/// MotionKit 判定确认后调用 requestGeometryUpdate 解锁对应朝向
/// 键盘/系统 UI 永远正确朝向；碰撞/水滴效果叠加图层
final class RotationCoordinator {
    static let shared = RotationCoordinator()

    func request(orientation: DeviceOrientation) {
        guard !orientation.isFlat else {
            // 平放回待机：请求 portrait，让系统正确呈现
            requestSystemPortrait()
            return
        }
        let mask: UIInterfaceOrientationMask
        switch orientation {
        case .portrait: mask = .portrait
        case .portraitUpsideDown: mask = .portraitUpsideDown
        case .landscapeLeft: mask = .landscapeLeft
        case .landscapeRight: mask = .landscapeRight
        default: mask = .portrait
        }
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        window?.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
            // 失败原因统一入调试日志体系（T1 用户要求）
            NotificationCenter.default.post(
                name: .rotationSystemLog,
                object: nil,
                userInfo: ["orientation": orientation.rawValue,
                           "error": error.localizedDescription]
            )
        }
    }

    private func requestSystemPortrait() {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        window?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
    }
}

extension DeviceOrientation {
    var isFlat: Bool { self == .faceUp || self == .faceDown }
}

extension Notification.Name {
    static let rotationSystemLog = Notification.Name("flipcompass.rotation.systemLog")
}
