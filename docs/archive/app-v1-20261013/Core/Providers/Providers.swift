import Foundation
import SwiftData
import SwiftUI

/// Provider 层（T3 定稿）
/// 内置模块直连 SwiftData；市场模块（二三期）仅 KV
/// 提供函数式查询：checkin.todayItems / checkin.weekStats / thoughts.today / 等
protocol Provider {
    var key: String { get }
}

final class CheckInProvider: Provider {
    let key = "checkin"
    let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func todayItems() throws -> [CheckInItem] {
        let desc = FetchDescriptor<CheckInItem>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try context.fetch(desc)
    }

    func todayDoneCount(_ items: [CheckInItem]) -> Int {
        let cal = Calendar.current
        return items.reduce(0) { acc, item in
            let doneToday = item.records.contains { cal.isDateInToday($0.doneAt) }
            return acc + (doneToday ? 1 : 0)
        }
    }

    func todayRecords(item: CheckInItem) -> [CheckInRecord] {
        let cal = Calendar.current
        return item.records.filter { cal.isDateInToday($0.doneAt) }
    }

    func streak(of item: CheckInItem) -> Int {
        let cal = Calendar.current
        let days = Set(item.records.map { cal.startOfDay(for: $0.doneAt) })
        var streak = 0
        var cursor = cal.startOfDay(for: .now)
        while days.contains(cursor) {
            streak += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    func maxStreak(_ items: [CheckInItem]) -> Int {
        items.map { streak(of: $0) }.max() ?? 0
    }

    func checkToday(item: CheckInItem, mood: String? = nil) throws -> CheckInRecord {
        let record = CheckInRecord(item: item, mood: mood)
        context.insert(record)
        try context.save()
        return record
    }

    func uncheckToday(item: CheckInItem) throws {
        let cal = Calendar.current
        let toRemove = item.records.filter { cal.isDateInToday($0.doneAt) }
        for r in toRemove { context.delete(r) }
        try context.save()
    }

    func nextReminder(_ items: [CheckInItem]) -> (hour: Int, minute: Int)? {
        let now = Calendar.current.dateComponents([.hour, .minute], from: .now)
        let upcoming = items.compactMap { item -> (Int, Int)? in
            guard let h = item.remindHour, let m = item.remindMinute else { return nil }
            if (h > now.hour!) || (h == now.hour! && m > (now.minute ?? 0)) {
                return (h, m)
            }
            return nil
        }.sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
        return upcoming.first
    }

    func pendingCount(_ items: [CheckInItem]) -> Int {
        let cal = Calendar.current
        return items.reduce(0) { acc, item in
            let done = item.records.contains { cal.isDateInToday($0.doneAt) }
            return acc + (done ? 0 : 1)
        }
    }
}

final class ThoughtProvider: Provider {
    let key = "thoughts"
    let context: ModelContext
    init(context: ModelContext) { self.context = context }
    func today() throws -> [Thought] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let desc = FetchDescriptor<Thought>(
            predicate: #Predicate { $0.createdAt >= start && $0.createdAt < end },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(desc)
    }

    /// V0.4.3：按月归档（createdAt 该月内的全部想法）
    func inMonth(year: Int, month: Int) throws -> [Thought] {
        let cal = Calendar.current
        var comp = DateComponents()
        comp.year = year; comp.month = month; comp.day = 1
        guard let start = cal.date(from: comp),
              let end = cal.date(byAdding: .month, value: 1, to: start) else { return [] }
        let desc = FetchDescriptor<Thought>(
            predicate: #Predicate { $0.createdAt >= start && $0.createdAt < end },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(desc)
    }

    func all() throws -> [Thought] {
        try context.fetch(FetchDescriptor<Thought>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
    }

    func insert(_ t: Thought) throws {
        context.insert(t)
        try context.save()
    }

    func update(_ t: Thought, content: String, mood: String?) throws {
        t.content = content
        t.mood = mood
        try context.save()
    }

    func delete(_ t: Thought) throws {
        context.delete(t)
        try context.save()
    }
}

/// R8 草稿三件套 Provider（V0.4.3 落地）
final class DraftProvider: Provider {
    let key = "draft"
    let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func drafts(module: String, page: String) throws -> [Draft] {
        let desc = FetchDescriptor<Draft>(
            predicate: #Predicate { $0.moduleKey == module && $0.pageKey == page },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(desc)
    }

    /// 字级落盘：同 fieldKey 已有草稿则更新，否则新建
    @discardableResult
    func upsert(module: String, page: String, field: String, payload: String) throws -> Draft? {
        if payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 空内容 → 删除对应草稿
            try remove(module: module, page: page, field: field)
            return nil
        }
        let existing = try drafts(module: module, page: page)
            .first { $0.fieldKey == field }
        if let d = existing {
            if d.payload == payload { return d }  // 同内容不重复写
            d.payload = payload
            d.updatedAt = .now
            try context.save()
            return d
        }
        let d = Draft(moduleKey: module, pageKey: page, fieldKey: field, payload: payload)
        context.insert(d)
        try context.save()
        return d
    }

    func remove(module: String, page: String, field: String) throws {
        let items = try drafts(module: module, page: page).filter { $0.fieldKey == field }
        for d in items { context.delete(d) }
        try context.save()
    }

    func remove(_ draft: Draft) throws {
        context.delete(draft)
        try context.save()
    }
}

final class HubProvider: Provider {
    let key = "hub"
    let context: ModelContext
    init(context: ModelContext) { self.context = context }
    func coupons() throws -> [CouponCard] {
        try context.fetch(FetchDescriptor<CouponCard>(
            sortBy: [SortDescriptor(\.expireAt)]
        ))
    }
    func collections() throws -> [CollectionItem] {
        try context.fetch(FetchDescriptor<CollectionItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
    }
    func preferences() throws -> [Preference] {
        try context.fetch(FetchDescriptor<Preference>(
            sortBy: [SortDescriptor(\.category)]
        ))
    }

    // MARK: - V0.4.2 券状态机
    func claim(_ coupon: CouponCard) throws {
        coupon.claimedAt = .now
        try context.save()
    }
    func markUsed(_ coupon: CouponCard) throws {
        coupon.usedAt = .now
        try context.save()
    }

    // MARK: - V0.4.2 收藏联动
    func toggleFav(_ item: CollectionItem) throws {
        item.isFav.toggle()
        try context.save()
    }
    func favs() throws -> [CollectionItem] {
        try context.fetch(FetchDescriptor<CollectionItem>(
            predicate: #Predicate { $0.isFav == true },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
    }

    // MARK: - V0.4.2 偏好编辑
    func setPreference(key: String, value: String, category: String) throws {
        let existing = try preferences().first { $0.key == key }
        if let p = existing {
            p.value = value
            p.updatedAt = .now
        } else {
            let p = Preference(key: key, value: value, category: category)
            context.insert(p)
        }
        try context.save()
    }
}

final class GameProvider: Provider {
    let key = "games"
    let context: ModelContext
    init(context: ModelContext) { self.context = context }
    func list() throws -> [GameProgress] {
        try context.fetch(FetchDescriptor<GameProgress>(
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        ))
    }

    // MARK: - V0.4.4 战绩/统计/勋章/设置
    func records() throws -> [GameRecord] {
        try context.fetch(FetchDescriptor<GameRecord>(
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        ))
    }

    func records(of gameKey: String, limit: Int = 6) throws -> [GameRecord] {
        let desc = FetchDescriptor<GameRecord>(
            predicate: #Predicate { $0.gameKey == gameKey },
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        )
        var d = desc
        d.fetchLimit = limit
        return try context.fetch(d)
    }

    func badges() throws -> [GameBadge] {
        try context.fetch(FetchDescriptor<GameBadge>(
            sortBy: [SortDescriptor(\.key)]
        ))
    }

    func settings() throws -> GameSettings {
        let all = try context.fetch(FetchDescriptor<GameSettings>())
        if let s = all.first { return s }
        let s = GameSettings()
        context.insert(s)
        try context.save()
        return s
    }

    func addRecord(gameKey: String, score: Int, stars: Int, durationSec: Int) throws {
        let r = GameRecord(gameKey: gameKey, score: score, stars: stars, durationSec: durationSec)
        context.insert(r)
        // 同步 GameProgress 累计
        let list = try context.fetch(FetchDescriptor<GameProgress>(
            predicate: #Predicate { $0.gameKey == gameKey }
        ))
        if let p = list.first {
            p.totalPlays += 1
            if stars > p.bestScore { p.bestScore = stars }
            p.lastPlayedAt = .now
        } else {
            context.insert(GameProgress(gameKey: gameKey, bestScore: stars, totalPlays: 1))
        }
        try context.save()
    }

    func clearRecords() throws {
        let rs = try records()
        for r in rs { context.delete(r) }
        try context.save()
    }
}

/// 待机页轻提醒聚合：四模块未完成 / 草稿未保存
struct IdleReminders {
    let checkInProvider: CheckInProvider
    let thoughtProvider: ThoughtProvider
    var draftProvider: DraftProvider? = nil

    struct Reminder: Identifiable, Hashable {
        let id = UUID()
        let module: ModuleKey
        let text: String
        let subtitle: String?
    }

    func reminders() throws -> [Reminder] {
        var items: [Reminder] = []
        let checkinItems = try checkInProvider.todayItems()
        let pending = checkInProvider.pendingCount(checkinItems)
        if pending > 0 {
            if let next = checkInProvider.nextReminder(checkinItems) {
                items.append(Reminder(
                    module: .checkIn,
                    text: "温情打卡 · 还有 \(pending) 项",
                    subtitle: "下次提醒 \(String(format: "%02d", next.hour)):\(String(format: "%02d", next.minute))"
                ))
            } else {
                items.append(Reminder(
                    module: .checkIn,
                    text: "温情打卡 · 还有 \(pending) 项",
                    subtitle: nil
                ))
            }
        } else if !checkinItems.isEmpty {
            items.append(Reminder(
                module: .checkIn,
                text: "温情打卡全部完成 ✓ 真棒",
                subtitle: nil
            ))
        }
        let thoughts = try thoughtProvider.today()
        if thoughts.isEmpty {
            items.append(Reminder(module: .thought, text: "今天的想法 · 还没记录", subtitle: nil))
        } else {
            items.append(Reminder(module: .thought, text: "今天的想法 · \(thoughts.count) 条", subtitle: nil))
        }

        // V0.4.3：草稿标记看得见（待机轻提醒）
        if let draftProvider {
            let drafts = (try? draftProvider.drafts(module: "thought", page: "compose")) ?? []
            if !drafts.isEmpty {
                let latest = drafts.first!
                let f = DateFormatter()
                f.dateFormat = "MM-dd"
                items.append(Reminder(
                    module: .thought,
                    text: "想法草稿中 · \(drafts.count) 条",
                    subtitle: "上次 \(f.string(from: latest.updatedAt))"
                ))
            }
        }
        return items
    }
}
