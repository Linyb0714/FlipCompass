import Foundation
import SwiftData

// MARK: - M1 温情打卡
@Model
final class CheckInItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var desc: String
    var remindHour: Int?            // 提醒时间 19~22，nil = 不提醒
    var remindMinute: Int?
    var createdAt: Date
    var sortOrder: Int
    @Relationship(deleteRule: .cascade, inverse: \CheckInRecord.item)
    var records: [CheckInRecord]

    init(id: UUID = UUID(), title: String, desc: String = "",
         remindHour: Int? = 19, remindMinute: Int? = 0,
         createdAt: Date = .now, sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.desc = desc
        self.remindHour = remindHour
        self.remindMinute = remindMinute
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.records = []
    }
}

@Model
final class CheckInRecord {
    @Attribute(.unique) var id: UUID
    var item: CheckInItem?
    var doneAt: Date
    var mood: String?            // V0.4.1 P2 待补：打卡时选心情
    var note: String?

    init(id: UUID = UUID(), item: CheckInItem? = nil,
         doneAt: Date = .now, mood: String? = nil, note: String? = nil) {
        self.id = id
        self.item = item
        self.doneAt = doneAt
        self.mood = mood
        self.note = note
    }
}
