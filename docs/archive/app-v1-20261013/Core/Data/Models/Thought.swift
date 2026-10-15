import Foundation
import SwiftData

// MARK: - M2 今天的想法
@Model
final class Thought {
    @Attribute(.unique) var id: UUID
    var content: String
    var createdAt: Date
    var mood: String?              // 情绪标签
    var reviewedAt: Date?

    init(id: UUID = UUID(), content: String, createdAt: Date = .now,
         mood: String? = nil, reviewedAt: Date? = nil) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.mood = mood
        self.reviewedAt = reviewedAt
    }
}
