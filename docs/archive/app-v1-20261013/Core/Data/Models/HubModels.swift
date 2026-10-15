import Foundation
import SwiftData

// MARK: - M3 生活情报站

/// 用户偏好（数据分析原料，二三期公共数据接入）
@Model
final class Preference {
    @Attribute(.unique) var id: UUID
    var key: String
    var value: String
    var category: String            // 餐饮/旅游/购物 等分类
    var updatedAt: Date

    init(id: UUID = UUID(), key: String, value: String,
         category: String = "misc", updatedAt: Date = .now) {
        self.id = id
        self.key = key
        self.value = value
        self.category = category
        self.updatedAt = updatedAt
    }
}

/// 攻略/好物收藏
@Model
final class CollectionItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var url: String?
    var summary: String
    var category: String            // 攻略/好物
    var createdAt: Date
    var tags: [String]
    var isFav: Bool                 // V0.4.2：收藏标记（p1 收藏夹）
    var source: String              // V0.4.2：来源（小红书/美团 等）
    var body: String                // V0.4.2：d5 段落正文（多段 \n\n 分隔）

    init(id: UUID = UUID(), title: String, url: String? = nil,
         summary: String = "", category: String = "guide",
         createdAt: Date = .now, tags: [String] = [],
         isFav: Bool = false, source: String = "", body: String = "") {
        self.id = id
        self.title = title
        self.url = url
        self.summary = summary
        self.category = category
        self.createdAt = createdAt
        self.tags = tags
        self.isFav = isFav
        self.source = source
        self.body = body
    }
}

/// 优惠券（手动录入，V0.4.2 加状态机）
@Model
final class CouponCard {
    @Attribute(.unique) var id: UUID
    var title: String
    var code: String
    var expireAt: Date
    var usedAt: Date?
    var claimedAt: Date?            // V0.4.2：领取时间
    var source: String              // 平台/商家
    var createdAt: Date
    var value: String               // V0.4.2：面额展示（如 ¥30 / 8 折）
    var threshold: String           // V0.4.2：使用门槛（满 50 可用）
    var scope: String               // V0.4.2：适用范围（全场通用 / 仅堂食）
    var shops: [String]             // V0.4.2：可用门店（名称+距离 字符串）

    init(id: UUID = UUID(), title: String, code: String,
         expireAt: Date, usedAt: Date? = nil, claimedAt: Date? = nil,
         source: String = "", createdAt: Date = .now,
         value: String = "", threshold: String = "",
         scope: String = "", shops: [String] = []) {
        self.id = id
        self.title = title
        self.code = code
        self.expireAt = expireAt
        self.usedAt = usedAt
        self.claimedAt = claimedAt
        self.source = source
        self.createdAt = createdAt
        self.value = value
        self.threshold = threshold
        self.scope = scope
        self.shops = shops
    }

    /// V0.4.2 券状态机：未领 / 已领 / 已用 / 过期
    enum CouponState: String, Codable {
        case unclaimed, claimed, used, expired
    }
    var state: CouponState {
        if usedAt != nil { return .used }
        if expireAt < .now { return .expired }
        if claimedAt != nil { return .claimed }
        return .unclaimed
    }
}

/// RSS 订阅源
@Model
final class FeedSource {
    @Attribute(.unique) var id: UUID
    var name: String
    var feedURL: String
    var category: String
    var lastFetchAt: Date?
    var enabled: Bool

    init(id: UUID = UUID(), name: String, feedURL: String,
         category: String = "default", lastFetchAt: Date? = nil, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.feedURL = feedURL
        self.category = category
        self.lastFetchAt = lastFetchAt
        self.enabled = enabled
    }
}

/// RSS 条目缓存
@Model
final class FeedItem {
    @Attribute(.unique) var id: UUID
    var source: FeedSource?
    var title: String
    var summary: String
    var url: String
    var publishedAt: Date
    var fetchedAt: Date
    var readAt: Date?

    init(id: UUID = UUID(), source: FeedSource? = nil,
         title: String, summary: String = "", url: String,
         publishedAt: Date, fetchedAt: Date = .now, readAt: Date? = nil) {
        self.id = id
        self.source = source
        self.title = title
        self.summary = summary
        self.url = url
        self.publishedAt = publishedAt
        self.fetchedAt = fetchedAt
        self.readAt = readAt
    }
}
