import Foundation
import UserNotifications

// MARK: - M1 本地通知（每日 / 每周多选 · 工作日跳假 / 每月）
// 权限请求时机（B1 定稿）：被动进模块不弹权限——sync 仅在「已授权」时静默注册；
// 用户主动配置提醒（新建/编辑保存）时 registerItem 才发起授权请求，拒绝后不再打扰。
//
// 通知条数模型：一个条目按规则展开为 1~N 条通知（identifier = "checkin-<uuid>" + 后缀）：
//   每日 → 1 条周期重复（identifier 不带后缀，与历史通知标识完全一致）
//   每月 → 每个选中日期 1 条日期重复（后缀 "-m15"）；当月无该日该月自动不触发
//   每周（不跳假）→ 每个选中星期 1 条星期重复（后缀 "-w2"）
//   每周（跳假·工作日）→ 按具体日期排 N 条单次通知（后缀 "-d202610192000"），
//     依据内置假日表（ChineseHoliday）跳过法定假日；每次 sync / registerItem 全删全排，
//     刷新临近批次；iOS pending 通知上限 64 条/app，故每条目只排未来 8 个触发日。

enum CheckInNotify {
    static let idPrefix = "checkin-"

    /// 「工作日跳假」每条目排期的未来触发日数（64 条 pending 上限内的保守取值）
    static let skipHolidayHorizon = 8

    /// item.id → 该条目全部通知的 identifier 公共前缀
    static func identifierPrefix(for itemId: UUID) -> String {
        idPrefix + itemId.uuidString
    }

    /// 全量同步（进 M1 / 条目增删时）：清掉全部既有通知 → 按最新规则全量重排
    /// （规则可能改变星期集合 / 跳假排期窗口，统一重建最稳；
    ///   已删条目的通知随全清一并移除）。notDetermined / denied 均静默跳过（不弹窗）。
    static func sync(items: [CheckInItem]) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            center.getPendingNotificationRequests { pending in
                let mine = pending
                    .map(\.identifier)
                    .filter { $0.hasPrefix(idPrefix) }
                if !mine.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: mine)
                }
                for item in items {
                    guard let rule = CheckInRemind.parseRule(item.remind) else { continue }
                    for request in makeRequests(item: item, rule: rule) {
                        center.add(request)
                    }
                }
            }
        }
    }

    /// 单项注册（新建/编辑保存带提醒时）：此刻才发起授权请求（用户主动行为 = 合理弹窗时机）；
    /// 先清该条目既有通知再按最新规则重排（rule 解析失败 = 不提醒 → 仅清不排）。
    static func registerItem(_ item: CheckInItem) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized else { return }
                reschedule(item: item)
            }
        }
    }

    /// 删除条目时取消其全部通知（可能多条：逐星期重复 / 跳假逐日）
    static func cancel(itemId: UUID) {
        let center = UNUserNotificationCenter.current()
        let prefix = identifierPrefix(for: itemId)
        center.getPendingNotificationRequests { pending in
            let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            guard !ids.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// 清空该条目通知 → 按规则重排
    private static func reschedule(item: CheckInItem) {
        let center = UNUserNotificationCenter.current()
        let prefix = identifierPrefix(for: item.id)
        center.getPendingNotificationRequests { pending in
            let mine = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            if !mine.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: mine)
            }
            guard let rule = CheckInRemind.parseRule(item.remind) else { return }
            for request in makeRequests(item: item, rule: rule) {
                center.add(request)
            }
        }
    }

    /// 规则 → 通知请求列表（internal 供单测；now/calendar 可注入固定值）
    static func makeRequests(
        item: CheckInItem,
        rule: RemindRule,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [UNNotificationRequest] {
        let content = makeContent(item: item)
        let base = identifierPrefix(for: item.id)
        switch rule {
        case .daily(let h, let m):
            var comps = DateComponents()
            comps.hour = h
            comps.minute = m
            return [request(id: base, content: content, comps: comps, repeats: true)]
        case .monthly(let ds, let h, let m):
            // 每个选中日期一条重复通知（当月无该日如 31 号之于 4 月，该月自动不触发）
            return ds.map { d in
                var comps = DateComponents()
                comps.day = d
                comps.hour = h
                comps.minute = m
                return request(id: "\(base)-m\(d)", content: content, comps: comps, repeats: true)
            }
        case .weekly(let ws, let skip, let h, let m):
            guard !ws.isEmpty else { return [] }
            if !skip {
                // 每个选中星期一条重复通知（星期触发的原生表达）
                return ws.map { w in
                    var comps = DateComponents()
                    comps.weekday = w
                    comps.hour = h
                    comps.minute = m
                    return request(id: "\(base)-w\(w)", content: content, comps: comps, repeats: true)
                }
            }
            // 工作日跳假：按具体日期排单次通知（跳过法定假日，见 ChineseHoliday）
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyyMMddHHmm"
            fmt.timeZone = calendar.timeZone
            return ChineseHoliday.upcomingSkipHolidayTriggers(
                weekdays: ws, hour: h, minute: m, from: now,
                limit: skipHolidayHorizon, calendar: calendar
            ).map { date in
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                return request(
                    id: "\(base)-d\(fmt.string(from: date))",
                    content: content, comps: comps, repeats: false
                )
            }
        }
    }

    private static func makeContent(item: CheckInItem) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "温情打卡"
        content.body = "该打卡啦：\(item.title)"
        content.sound = .default
        return content
    }

    private static func request(
        id: String,
        content: UNNotificationContent,
        comps: DateComponents,
        repeats: Bool
    ) -> UNNotificationRequest {
        UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats)
        )
    }
}
