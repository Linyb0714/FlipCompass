import Foundation

// MARK: - M3 业务逻辑（纯决策函数，可单测；写库在 View 层用 modelContext 执行）

enum M3Store {

    // MARK: 券状态（原型 CP_STATE 四态 · B3 只读展示标签，C4 落地状态机交互）

    static func couponLabel(state: String) -> String {
        switch state {
        case "claimed": return "已领取"
        case "used": return "已使用"
        case "expired": return "已过期"
        default: return "未领取"
        }
    }

    /// used/expired → 卡片置灰（is-dim）
    static func couponDimmed(state: String) -> Bool {
        state == "used" || state == "expired"
    }

    // MARK: 头部胶囊（V0.4.2 实算：今日条数 = 券 + 情报 的 inFeed 合计）

    static func headline(feedCount: Int, couponCount: Int) -> (text: String, value: Int) {
        let n = feedCount + couponCount
        return ("今日 \(n) 条", n)
    }

    // MARK: 今日推送（p0：券在前，情报随后 —— 原型 items 顺序）
    // 完善轮：情报按偏好加权排序（taste/takeout 选中标签命中多者靠前；同权重保持
    // 创建时间升序）—— 兑现 d7 保存 toast「偏好已保存 · 情报推荐会重新排序」承诺。

    /// 偏好命中权重：tags 与选中偏好标签的交集数
    static func prefWeight(tags: [String], liked: Set<String>) -> Int {
        tags.reduce(0) { $0 + (liked.contains($1) ? 1 : 0) }
    }

    static func feedList(coupons: [CouponCard], feeds: [FeedItem],
                         likedTags: Set<String> = []) -> (coupons: [CouponCard], feeds: [FeedItem]) {
        let c = coupons.filter(\.inFeed).sorted { $0.daysLeft < $1.daysLeft }
        let f = feeds.filter(\.inFeed).sorted { a, b in
            let wa = prefWeight(tags: a.tags, liked: likedTags)
            let wb = prefWeight(tags: b.tags, liked: likedTags)
            if wa != wb { return wa > wb }
            return a.createdAt < b.createdAt
        }
        return (c, f)
    }

    // MARK: p1 收藏筛选（chips 真筛选联动 tags + 空态）

    /// 筛选档位：「全部」 + 各条目 tags 去重（按出现顺序，稳定）
    static func filterTags(feeds: [FeedItem]) -> [String] {
        var seen: Set<String> = []
        return feeds.reduce(into: ["全部"]) { acc, it in
            for t in it.tags where !seen.contains(t) {
                seen.insert(t)
                acc.append(t)
            }
        }
    }

    /// 收藏条目按标签筛选（「全部」= 不过滤）
    static func favFeeds(feeds: [FeedItem], tag: String) -> [FeedItem] {
        let list = feeds.filter(\.fav)
        if tag == "全部" { return list }
        return list.filter { $0.tags.contains(tag) }
    }

    // MARK: 券状态机（C5 · 原型 CP_STATE/cpAdvance：none → claimed → used；expired 终态）

    /// 主 CTA 文案随状态切换
    static func couponCTA(state: String) -> String {
        switch state {
        case "claimed": return "标记已使用"
        case "used": return "已使用"
        case "expired": return "已过期"
        default: return "领取"
        }
    }

    /// 状态流转决策：none → claimed（领取）→ used（核销）；used/expired 终态不动
    static func cpAdvance(state: String) -> (next: String?, toast: String?) {
        switch state {
        case "none": return ("claimed", "已领取 ✓ 券码已生成，到店出示即可")
        case "claimed": return ("used", "已标记为已使用 · 感谢支持")
        default: return (nil, nil)
        }
    }

    /// 领取时生成券码（8 位数字 · 4+4 分组，如「8246 3917」）
    static func cpGenerateCode() -> String {
        let d = (0..<8).map { _ in Int.random(in: 0...9) }
        let s = d.map(String.init).joined()
        return String(s.prefix(4)) + " " + s.dropFirst(4)
    }

    // MARK: p2 偏好行文案

    static let priceTiers = ["只看低价", "适中", "看品质"]

    /// 偏好行值文案：多选 = 「偏甜 · 少辣 · 汤水党」；price = 档位文字
    static func prefValue(_ p: Preference) -> String {
        if p.key == "price" {
            guard priceTiers.indices.contains(p.level) else { return "适中" }
            return priceTiers[p.level]
        }
        return p.selected.isEmpty ? "未设置" : p.selected.joined(separator: " · ")
    }
}