import Foundation
import SwiftData

// MARK: - M2 SwiftData 模型（V0.4.3 架构：Thought + Draft 两实体）
// thought = 一条想法；draft = 草稿（R8 三件套：moduleKey+pageKey 定位，永久保留至发布/删除）。
// 今日 = date 为当天零时；月视图按年月过滤；time = 展示时刻 HH:mm。

@Model
final class Thought {
    @Attribute(.unique) var id: UUID
    /// 想法全文
    var text: String
    /// 心情（晴朗/平静/心动/疲惫/雀跃）
    var mood: String
    /// 当天零时（今日 / 月过滤键）
    var date: Date
    /// 时刻（"HH:mm" 展示源）
    var time: Date
    var createdAt: Date

    init(id: UUID = UUID(), text: String, mood: String, date: Date, time: Date, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.mood = mood
        self.date = date
        self.time = time
        self.createdAt = createdAt
    }
}

@Model
final class Draft {
    @Attribute(.unique) var id: UUID
    var text: String
    var mood: String
    var date: Date
    var time: Date
    var createdAt: Date
    /// R8：草稿归属定位（M2 记录一条 = "m2"/"write"）
    var moduleKey: String
    var pageKey: String

    init(id: UUID = UUID(), text: String, mood: String, date: Date, time: Date,
         createdAt: Date = Date(), moduleKey: String = "m2", pageKey: String = "write") {
        self.id = id
        self.text = text
        self.mood = mood
        self.date = date
        self.time = time
        self.createdAt = createdAt
        self.moduleKey = moduleKey
        self.pageKey = pageKey
    }
}

// MARK: - 时刻格式化（"21:32"）与心情（V0.4.3 MOODS_M2）

enum ThoughtFormat {
    private static func formatter(_ fmt: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")   // 防 12 小时制环境漂移
        f.dateFormat = fmt
        return f
    }
    /// Date → "HH:mm"
    static func hhmm(_ d: Date) -> String { formatter("HH:mm").string(from: d) }
    /// Date → "MM-dd"
    static func mmdd(_ d: Date) -> String { formatter("MM-dd").string(from: d) }
}