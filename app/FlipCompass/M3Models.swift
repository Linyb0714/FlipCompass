import Foundation
import SwiftData

// MARK: - M3 SwiftData 模型（V0.4.2 架构：FeedItem + CouponCard + Preference 三实体）
// feed = 情报条目（正文段落 d5 用）；coupon = 券卡（状态机四态，B3 只读展示，C4 落地交互）；
// preference = 偏好设置（taste/takeout 多选 + price 三档单选）。

@Model
final class FeedItem {
    @Attribute(.unique) var id: UUID
    /// 主标签（信息卡 tag 行）
    var tag: String
    var title: String
    var sub: String
    var source: String
    var time: String
    /// 全部标签（p1 筛选用）
    var tags: [String]
    /// 是否收藏（p1 收藏夹 + 卡片 ♥ 角标）
    var fav: Bool
    /// 是否今日推送（p0 渲染用；收藏条目 p0 不出现）
    var inFeed: Bool
    /// 段落正文（d5 详情 C 阶段用，B3 数据即备）
    var paragraphs: [String]
    var createdAt: Date

    init(id: UUID = UUID(), tag: String, title: String, sub: String,
         source: String = "", time: String = "", tags: [String] = [],
         fav: Bool = false, inFeed: Bool = true, paragraphs: [String] = [],
         createdAt: Date = Date()) {
        self.id = id
        self.tag = tag
        self.title = title
        self.sub = sub
        self.source = source
        self.time = time
        self.tags = tags
        self.fav = fav
        self.inFeed = inFeed
        self.paragraphs = paragraphs
        self.createdAt = createdAt
    }
}

@Model
final class CouponCard {
    @Attribute(.unique) var id: UUID
    var tag: String
    var title: String
    var sub: String
    /// 券面金额/权益（「买一送一」）
    var value: String
    var threshold: String
    /// 剩余天数（倒计时）
    var daysLeft: Int
    var valid: String
    var scope: String
    /// 进度（% 状态条）
    var progress: Int
    /// 状态机（none/claimed/used/expired；B3 只读，C4 交互流转）
    var state: String
    var code: String
    /// 门店「名称：距离」拼接串
    var shops: [String]
    var fav: Bool
    var inFeed: Bool
    var createdAt: Date

    init(id: UUID = UUID(), tag: String = "优惠券", title: String, sub: String,
         value: String, threshold: String, daysLeft: Int, valid: String,
         scope: String, progress: Int, state: String = "none", code: String = "",
         shops: [String] = [], fav: Bool = false, inFeed: Bool = true,
         createdAt: Date = Date()) {
        self.id = id
        self.tag = tag
        self.title = title
        self.sub = sub
        self.value = value
        self.threshold = threshold
        self.daysLeft = daysLeft
        self.valid = valid
        self.scope = scope
        self.progress = progress
        self.state = state
        self.code = code
        self.shops = shops
        self.fav = fav
        self.inFeed = inFeed
        self.createdAt = createdAt
    }
}

@Model
final class RssSource {
    @Attribute(.unique) var id: UUID
    /// 源显示名（如「少数派」）
    var title: String
    /// RSS/Atom 订阅地址
    var url: String
    /// 是否启用（停用不拉取）
    var enabled: Bool
    /// 最近一次成功拉取时间
    var lastFetched: Date
    var createdAt: Date

    init(id: UUID = UUID(), title: String, url: String, enabled: Bool = true,
         lastFetched: Date? = nil, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.url = url
        self.enabled = enabled
        self.lastFetched = lastFetched ?? Date.distantPast
        self.createdAt = createdAt
    }
}

@Model
final class Preference {
    @Attribute(.unique) var key: String       // taste / takeout / price
    var title: String
    var sub: String
    /// 可选项（taste/takeout = 标签；price = 三档文案）
    var options: [String]
    /// 多选已选（price 为空数组）
    var selected: [String]
    /// price 档位 0/1/2（taste/takeout 恒 0）
    var level: Int
    var sortOrder: Int
    /// RSS 源管理本轮后置（不可进）
    var disabled: Bool

    init(key: String, title: String, sub: String, options: [String] = [],
         selected: [String] = [], level: Int = 0, sortOrder: Int = 0,
         disabled: Bool = false) {
        self.key = key
        self.title = title
        self.sub = sub
        self.options = options
        self.selected = selected
        self.level = level
        self.sortOrder = sortOrder
        self.disabled = disabled
    }
}