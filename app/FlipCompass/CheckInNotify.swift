import Foundation
import UserNotifications

// MARK: - M1 本地通知（原型：真机 UNUserNotificationCenter 按 item.remind 每日触发）
// 权限请求时机（B1 定稿）：被动进模块不弹权限——sync 仅在「已授权」时静默注册；
// 用户主动配置提醒（新建/编辑保存）时 registerItem 才发起授权请求，拒绝后不再打扰。

enum CheckInNotify {
    static let idPrefix = "checkin-"

    /// item.id → 通知 identifier
    static func identifier(for itemId: UUID) -> String {
        idPrefix + itemId.uuidString
    }

    /// 全量同步（进 M1 / 条目增删时）：清掉已删条目的旧通知 → 已授权则全量注册。
    /// notDetermined / denied 均静默跳过（不弹窗）。
    static func sync(items: [CheckInItem]) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            center.getPendingNotificationRequests { pending in
                let stale = pending
                    .filter { $0.identifier.hasPrefix(idPrefix) }
                    .map(\.identifier)
                    .filter { id in
                        let uuid = String(id.dropFirst(idPrefix.count))
                        return !items.contains { $0.id.uuidString == uuid }
                    }
                if !stale.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: stale)
                }
                for item in items {
                    guard let (h, m) = CheckInRemind.parse(item.remind) else { continue }
                    center.add(makeRequest(item: item, hour: h, minute: m))
                }
            }
        }
    }

    /// 单项注册（新建/编辑保存带提醒时）：此刻才发起授权请求（用户主动行为 = 合理弹窗时机）
    static func registerItem(_ item: CheckInItem) {
        guard let (h, m) = CheckInRemind.parse(item.remind) else {
            cancel(itemId: item.id)
            return
        }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized else { return }
                center.add(makeRequest(item: item, hour: h, minute: m))
            }
        }
    }

    private static func makeRequest(item: CheckInItem, hour: Int, minute: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "温情打卡"
        content.body = "该打卡啦：\(item.title)"
        content.sound = .default
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return UNNotificationRequest(
            identifier: identifier(for: item.id),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        )
    }

    /// 删除条目时取消其通知
    static func cancel(itemId: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(for: itemId)])
    }
}
