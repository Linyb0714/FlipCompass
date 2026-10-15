import SwiftUI
import SwiftData

/// M3 生活情报站 根视图（V0.4.2）
/// 分组页：P0 今日推送（券 + 情报卡片流） / P1 收藏（chips 真筛选） / P2 偏好
struct HubRootView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext
    @State private var pageIndex: Int = 0
    @State private var coupons: [CouponCard] = []
    @State private var feeds: [CollectionItem] = []
    @State private var favs: [CollectionItem] = []
    @State private var filterTag: String? = nil
    @State private var toast: Toast?

    private let pages = ["今日", "收藏", "偏好"]
    private let filterTags = ["全部", "攻略", "好物", "美食", "外卖", "旅游", "家电", "亲子", "健身"]

    var body: some View {
        VStack(spacing: 0) {
            tabs
            ZStack {
                switch pageIndex {
                case 0: HubTodayView(
                    coupons: coupons, feeds: feeds,
                    onCouponDetail: { c in openCoupon(c) },
                    onFeedDetail: { f in openFeed(f) }
                )
                case 1: HubFavView(
                    favs: favs, filterTag: filterTag, filterTags: filterTags,
                    onFilter: { tag in withAnimation(DesignTokens.springEase) {
                        filterTag = (tag == "全部") ? nil : tag
                    }},
                    onDetail: { f in openFeed(f) }
                )
                default: HubPreferenceView(onEdit: { openPreference() })
                }
            }
            .padding(.top, 4)
        }
        .overlay(alignment: .bottom) {
            if let toast { ToastView(toast: toast).padding(.bottom, 32) }
        }
        .task { seedIfNeeded(); refresh() }
        .onChange(of: state.level) { refresh() }
    }

    private var tabs: some View {
        HStack(spacing: 7) {
            ForEach(Array(pages.enumerated()), id: \.0) { idx, title in
                Text(title)
                    .font(.system(size: 13, weight: idx == pageIndex ? .semibold : .regular))
                    .foregroundStyle(idx == pageIndex ? DesignTokens.ink : DesignTokens.inkSecondary)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(idx == pageIndex ? DesignTokens.m3Green.opacity(0.16) : Color.clear)
                    .clipShape(Capsule())
                    .onTapGesture {
                        withAnimation(DesignTokens.springEase) { pageIndex = idx }
                    }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 7)
    }

    private func openCoupon(_ c: CouponCard) {
        state.enterDetail(DetailRoute(module: .hub, pageKey: "coupon", itemID: c.id.uuidString))
    }
    private func openFeed(_ f: CollectionItem) {
        state.enterDetail(DetailRoute(module: .hub, pageKey: "feed", itemID: f.id.uuidString))
    }
    private func openPreference() {
        state.enterDetail(DetailRoute(module: .hub, pageKey: "preference", itemID: nil))
    }

    private func refresh() {
        let hp = HubProvider(context: modelContext)
        coupons = (try? hp.coupons()) ?? []
        feeds = (try? hp.collections()) ?? []
        favs = (try? hp.favs()) ?? []
    }

    private func seedIfNeeded() {
        let hp = HubProvider(context: modelContext)
        let existing = (try? hp.collections()) ?? []
        let existingCoupons = (try? hp.coupons()) ?? []
        guard existing.isEmpty && existingCoupons.isEmpty else { return }

        // 1 券 + 5 情报 mock（V0.4.2 数据驱动种子）
        let cal = Calendar.current
        let coupon = CouponCard(
            title: "楼下咖啡店新人礼",
            code: "COFFEE2026",
            expireAt: cal.date(byAdding: .day, value: 7, to: .now) ?? .now,
            source: "星巴克",
            value: "¥ 30",
            threshold: "满 50 可用",
            scope: "全场通用",
            shops: ["万象城店 · 350m", "仓山万达店 · 1.2km"]
        )
        modelContext.insert(coupon)

        let items: [CollectionItem] = [
            CollectionItem(
                title: "周末带娃去哪玩 · 福州 5 个小众公园",
                summary: "不用排队、免费停车、适合野餐",
                category: "guide",
                tags: ["亲子", "攻略"],
                isFav: false,
                source: "小红书",
                body: "最近带娃去了几个本地人不太知道的公园，出乎意料的好。\n\n首推金山公园，有大片草坪可以野餐，娃可以放风筝。停车方便，周末也不挤。\n\n其次是茶亭公园，树荫多，适合夏天，公园里有免费儿童游乐设施。\n\n最后推荐闽江公园北园，沿江步道适合骑车，傍晚风景特别好。"
            ),
            CollectionItem(
                title: "山姆会员店值得买的 10 件家常好物",
                summary: "亲测不踩雷的厨房囤货清单",
                category: "goods",
                tags: ["好物", "美食"],
                isFav: true,
                source: "什么值得买",
                body: "山姆会员店囤货一年，总结这份回购清单。\n\n第一类是冷冻肉类，性价比远高于超市。\n\n第二类是烘焙原料，黄油和奶油的价格优势明显。\n\n第三类是日用品，纸抽和洗衣液一年买两次就够。"
            ),
            CollectionItem(
                title: "福州地铁 5 号线美食地图",
                summary: "沿线 12 家本地人推荐的小店",
                category: "guide",
                tags: ["美食", "攻略"],
                isFav: false,
                source: "福州本地宝",
                body: "5 号线开通后通勤方便了，沿线美食也陆续挖掘。\n\n帝封江站附近的鱼丸店开了 20 年，汤头一绝。\n\n浦上大道站旁的拌面扁肉，是附近上班族的午餐首选。\n\n螺洲古镇站有一家手工锅边，早上去要排队。"
            ),
            CollectionItem(
                title: "外卖党省钱攻略：会员红包叠加用法",
                summary: "每月省 200+ 的实操方法",
                category: "guide",
                tags: ["外卖", "攻略"],
                isFav: false,
                source: "美团",
                body: "外卖会员每月 15 元，但用对方法能省更多。\n\n第一招：大额红包搭配商家满减，下单前先算一下。\n\n第二招：错峰下单，下午 2-4 点红包面额更大。\n\n第三招：会员日和平台大促叠加，能省一半。"
            ),
            CollectionItem(
                title: "秋冬季保湿面霜测评 · 干皮救星",
                summary: "5 款平价面霜实测对比",
                category: "goods",
                tags: ["好物"],
                isFav: true,
                source: "B站",
                body: "干皮秋冬面霜测评，从 50 到 300 元都试过。\n\n最推荐的是适乐肤 C 乳，温和不刺激，敏感肌友好。\n\n玉泽屏障修护霜适合换季泛红期使用。\n\n预算充足可以上修丽可 AGE 面霜，抗老效果明显。"
            ),
        ]
        items.forEach { modelContext.insert($0) }
        try? modelContext.save()
    }
}

// MARK: - P0 今日推送
private struct HubTodayView: View {
    let coupons: [CouponCard]
    let feeds: [CollectionItem]
    let onCouponDetail: (CouponCard) -> Void
    let onFeedDetail: (CollectionItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacing) {
                if !coupons.isEmpty {
                    sectionHeader("今日券 · \(coupons.count)")
                    ForEach(coupons, id: \.id) { c in
                        CouponRow(coupon: c)
                            .onTapGesture { onCouponDetail(c) }
                    }
                }
                sectionHeader("情报 · \(feeds.count)")
                ForEach(feeds, id: \.id) { f in
                    FeedRow(item: f)
                        .onTapGesture { onFeedDetail(f) }
                }
            }
            .padding(.horizontal, DesignTokens.spacing)
            .padding(.vertical, DesignTokens.spacing)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DesignTokens.inkSecondary)
            .padding(.horizontal, 4)
    }
}

private struct CouponRow: View {
    let coupon: CouponCard

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(coupon.value)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignTokens.m3Green)
                    Text(stateText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(stateColor)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(stateColor.opacity(0.14))
                        .clipShape(Capsule())
                }
                Text(coupon.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignTokens.ink)
                Text("有效期至 \(dateString(coupon.expireAt))")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.inkSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignTokens.inkSecondary.opacity(0.5))
        }
        .padding(DesignTokens.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: DesignTokens.hRow)
        .glassCard(moduleColor: DesignTokens.m3Green)
    }

    private var stateText: String {
        switch coupon.state {
        case .unclaimed: return "未领取"
        case .claimed: return "已领取"
        case .used: return "已使用"
        case .expired: return "已过期"
        }
    }
    private var stateColor: Color {
        switch coupon.state {
        case .unclaimed: return DesignTokens.m3Green
        case .claimed: return DesignTokens.success
        case .used: return DesignTokens.inkSecondary
        case .expired: return DesignTokens.error
        }
    }
    private func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MM-dd"
        return f.string(from: d)
    }
}

private struct FeedRow: View {
    let item: CollectionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(item.tags.prefix(2), id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.m3Green)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(DesignTokens.m3Green.opacity(0.12))
                        .clipShape(Capsule())
                }
                if !item.source.isEmpty {
                    Text("· \(item.source)")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignTokens.inkSecondary)
                }
                Spacer()
                Image(systemName: item.isFav ? "heart.fill" : "heart")
                    .font(.system(size: 11))
                    .foregroundStyle(item.isFav ? DesignTokens.m3Green : DesignTokens.inkSecondary.opacity(0.5))
            }
            Text(item.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(2)
            Text(item.summary)
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.inkSecondary)
                .lineLimit(1)
        }
        .padding(DesignTokens.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(moduleColor: DesignTokens.m3Green)
    }
}

// MARK: - P1 收藏 + chips 真筛选
private struct HubFavView: View {
    let favs: [CollectionItem]
    let filterTag: String?
    let filterTags: [String]
    let onFilter: (String) -> Void
    let onDetail: (CollectionItem) -> Void

    private var filtered: [CollectionItem] {
        guard let tag = filterTag else { return favs }
        return favs.filter { $0.tags.contains(tag) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filterTags, id: \.self) { tag in
                        let selected = (tag == "全部" && filterTag == nil) || (tag == filterTag)
                        Text(tag)
                            .font(.system(size: 12, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? .white : DesignTokens.ink)
                            .padding(.horizontal, 11).padding(.vertical, 5)
                            .background(selected ? DesignTokens.m3Green : DesignTokens.bgSecondary)
                            .clipShape(Capsule())
                            .onTapGesture { onFilter(tag) }
                    }
                }
                .padding(.horizontal, DesignTokens.spacing)
                .padding(.vertical, 6)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacing) {
                    if filtered.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "tray")
                                .font(.system(size: 28))
                                .foregroundStyle(DesignTokens.m3Green.opacity(0.4))
                            Text(emptyText)
                                .font(.system(size: 14))
                                .foregroundStyle(DesignTokens.inkSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                    } else {
                        ForEach(filtered, id: \.id) { f in
                            FeedRow(item: f)
                                .onTapGesture { onDetail(f) }
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.spacing)
                .padding(.vertical, DesignTokens.spacing)
            }
        }
    }

    private var emptyText: String {
        if let tag = filterTag {
            return "还没有「\(tag)」相关的收藏"
        }
        return "还没有收藏内容"
    }
}

// MARK: - P2 偏好
private struct HubPreferenceView: View {
    let onEdit: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacing) {
                PreferenceRow(icon: "tag", title: "口味偏好 · 常点外卖", subtitle: "中餐 / 轻食 / 咖啡", action: onEdit)
                PreferenceRow(icon: "slider.horizontal.3", title: "价格敏感度", subtitle: "适中", action: onEdit)
                PreferenceRow(icon: "dot.radiowaves.up.forward", title: "RSS 源管理", subtitle: "（V0.4.2 后置）", action: nil)
            }
            .padding(.horizontal, DesignTokens.spacing)
            .padding(.vertical, DesignTokens.spacing)
        }
    }
}

private struct PreferenceRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(DesignTokens.m3Green)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignTokens.ink)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.inkSecondary)
            }
            Spacer()
            if action != nil {
                Text("编辑 ›")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignTokens.m3Green)
            }
        }
        .padding(DesignTokens.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: DesignTokens.hRow)
        .glassCard(moduleColor: DesignTokens.m3Green)
        .contentShape(Rectangle())
        .onTapGesture { action?() }
    }
}
