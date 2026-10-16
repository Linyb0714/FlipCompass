import SwiftUI
import SwiftData

// MARK: - M3 生活情报站 · 一级模块屏（B3）
// 三分组画布 pager：p0 今日推送（券 + 情报双列）/ p1 收藏筛选（chips + 收藏卡）/ p2 偏好设置。
// 交互沿用 M2 定稿骨架：画布平移 28pt 沟槽 · ScrollView 可滚动 + 底部渐隐 ·
// 点击选中焦点卡 · 水平切组 · 单击空白打开焦点 · 双击返回待机。#scr-m3 转录。

struct M3Screen: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\FeedItem.createdAt, order: .reverse)]) private var feeds: [FeedItem]
    @Query(sort: [SortDescriptor(\CouponCard.createdAt, order: .reverse)]) private var coupons: [CouponCard]
    @Query(sort: [SortDescriptor(\Preference.sortOrder)]) private var prefs: [Preference]
    @Query private var rssSources: [RssSource]   // C5+ 方案③：订阅源去重 seed 用

    // —— 分组 / 选中状态（三页：0 推送 / 1 收藏 / 2 偏好）——
    @State private var page = 0
    @State private var selByPage: [Int] = [0, 0, 0]
    @State private var bumpX: CGFloat = 0
    @State private var arrived = false

    // —— p1 收藏筛选 ——
    @State private var filter = "全部"

    // —— 滚动超出检测（同 M2 B2a）——
    struct ContentBottomKey: PreferenceKey {
        static var defaultValue: [Int: CGFloat] = [:]
        static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
            value.merge(nextValue()) { _, new in new }
        }
    }
    @State private var contentMaxY: [Int: CGFloat] = [:]
    @State private var viewportH: CGFloat = 0

    // —— 焦点卡几何 ——
    struct FocusKey: Hashable { let page: Int; let row: Int }
    @State private var focusFrames: [FocusKey: CGRect] = [:]
    @State private var focusPulse = false

    @State private var toast: ToastMsg? = nil
    struct ToastMsg: Identifiable, Equatable {
        let id = UUID()
        let text: String
    }

    // —— C5 hero 生长：d4 券详情会话 ——
    @State private var hero: HeroSession? = nil
    @State private var heroClosing = false
    @State private var heroTarget: M3HeroTarget? = nil
    @State private var heroSpots: [String: CGRect] = [:]

    enum M3HeroTarget {
        case coupon(CouponCard)   // d4 券详情（源卡 = p0 券卡）
        case feed(FeedItem)       // d5 情报详情（源卡 = p0 情报卡 / p1 收藏卡）
        case scan                 // 截图导入券（源卡 = p0 导入入口卡）
        case rss                  // 情报订阅源管理（源卡 = p2 rss 行）
        case nearby               // 附近好店（源卡 = p2 nearby 行）
        case pref(Preference)     // C7：d7 偏好编辑（源卡 = p2 偏好行）
    }

    // MARK: 数据派生

    /// 偏好选中标签集（taste + takeout 合并 · d7 保存后经 @Query 即时生效）
    private var likedTags: Set<String> {
        var s = Set<String>()
        for p in prefs where p.key == "taste" || p.key == "takeout" {
            s.formUnion(p.selected)
        }
        return s
    }

    /// p0：券在前 · 情报随后（情报按偏好命中加权排序）
    private var p0Coupons: [CouponCard] { M3Store.feedList(coupons: coupons, feeds: feeds, likedTags: likedTags).coupons }
    private var p0Feeds: [FeedItem] { M3Store.feedList(coupons: coupons, feeds: feeds, likedTags: likedTags).feeds }
    /// p1：收藏 + 筛选
    private var favList: [FeedItem] { M3Store.favFeeds(feeds: feeds, tag: filter) }
    /// chips 档位
    private var chipTags: [String] { M3Store.filterTags(feeds: feeds) }

    private var sel: Int { selByPage.indices.contains(page) ? selByPage[page] : -1 }

    // MARK: 布局

    var body: some View {
        ZStack {
            ModuleBackdrop(module: .m3)

            VStack(spacing: 0) {
                ModuleHeader(
                    module: .m3,
                    subtitle: "优惠券 · 攻略 · 好物",
                    chip: M3Store.headline(feedCount: p0Feeds.count, couponCount: p0Coupons.count).text,
                    chipValue: M3Store.headline(feedCount: p0Feeds.count, couponCount: p0Coupons.count).value
                )
                pagerClip
                ModuleDots(count: 3, current: page, color: DSToken.m3)
                NavHint(text: "上下滚动看更多 · 左右滑换分组 · 点击选中")
            }
            .padding(.top, 58)
            .padding(.bottom, 14)
            .padding(.horizontal, 21)

            if let t = toast {
                ModuleToast(text: t.text, color: DSToken.m3)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 120)
                    .allowsHitTesting(false)
            }

            // C5：hero 卡片生长覆盖层（d4 券详情）
            if let h = hero, let target = heroTarget {
                HeroOverlay(
                    session: h,
                    tintColor: DSToken.tintM3,
                    onBack: { heroClosing = true },
                    onClosed: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            hero = nil
                            heroClosing = false
                            heroTarget = nil
                        }
                        app.exitDetail()   // 红线修复：二级页关闭，恢复翻转导航
                    },
                    closing: heroClosing
                ) {
                    switch target {
                    case .coupon(let c):
                        M3CouponDetailPage(
                            coupon: c,
                            onBack: { heroClosing = true },
                            onAdvance: {
                                let (next, msg) = M3Store.cpAdvance(state: c.state)
                                guard let next else { return }   // used/expired 终态
                                if c.code.isEmpty { c.code = M3Store.cpGenerateCode() }   // 首领生成券码
                                c.state = next
                                showToast(msg ?? "")
                            },
                            onToast: { msg in showToast(msg) }
                        )
                        .transition(.opacity)
                    case .feed(let f):
                        M3FeedDetailPage(
                            item: f,
                            onBack: { heroClosing = true },
                            onToast: { msg in showToast(msg) }
                        )
                        .transition(.opacity)
                    case .scan:
                        M3CouponScanPage(
                            onCancel: { heroClosing = true },
                            onSave: { draft in
                                modelContext.insert(CouponCard(
                                    title: draft.title,
                                    sub: "截图导入 · 到店出示",
                                    value: draft.value.isEmpty ? draft.title : draft.value,
                                    threshold: draft.threshold.isEmpty ? "到店核销 · 不与其他优惠同享" : draft.threshold,
                                    daysLeft: draft.daysLeft,
                                    valid: draft.valid.isEmpty ? "导入后 \(draft.daysLeft) 天内有效" : draft.valid,
                                    scope: "到店核销 · 以平台券面为准",
                                    progress: 100, state: "none", code: "",
                                    shops: draft.shops.isEmpty ? ["到店核销 · 详见平台券面"] : draft.shops
                                ))
                                showToast("已导入「\(draft.title)」· 点开领取")
                                heroClosing = true
                            }
                        )
                        .transition(.opacity)
                    case .rss:
                        M3RssPage(onClose: { heroClosing = true }, onToast: { showToast($0) })
                            .transition(.opacity)
                    case .nearby:
                        M3NearbyPage(onClose: { heroClosing = true }, onToast: { showToast($0) })
                            .transition(.opacity)
                    case .pref(let p):
                        M3PrefEditPage(
                            pref: p,
                            onBack: { heroClosing = true },
                            onSaved: { msg in
                                showToast(msg)
                                heroClosing = true   // 原型 d7-save：写回 + toast + backOneLevel
                            }
                        )
                        .transition(.opacity)
                    }
                }
            }
        }
        .environment(\.heroSourceID, hero.map(\.sourceID))   // C5：生长中源卡自隐藏
        .coordinateSpace(name: "heroSpace")                   // hero 源卡/覆盖层共用坐标系
        .animation(DSToken.bounce, value: toast)
        .contentShape(Rectangle())
        .onTapGesture { handleBlankTap() }
        .onAppear {
            seedIfNeeded()
            seedExtraIfNeeded()
            withAnimation(DSToken.springSlow) { arrived = true }
            // DEBUG 后门：-m3-page 0/1/2 直达分组（模拟器截图验证）
            if let idx = CommandLine.arguments.firstIndex(of: "-m3-page"),
               let p = CommandLine.arguments.indices.contains(idx + 1) ? Int(CommandLine.arguments[idx + 1]) : nil,
               (0...2).contains(p) {
                page = p
            }
        }
        .onPreferenceChange(ContentBottomKey.self) { contentMaxY = $0 }
        .onPreferenceChange(HeroSpotKey.self) { heroSpots = $0 }   // C5：源卡几何收集
        .onChange(of: feeds.count) { _, _ in clampSelections() }
        .onChange(of: coupons.count) { _, _ in clampSelections() }
        .onChange(of: favList.count) { _, _ in clampSelections() }
    }

    // MARK: 空白点击（单击打开焦点 · 双击返回待机）

    @State private var lastBlankTap: Date? = nil
    @State private var blankTapTask: DispatchWorkItem? = nil

    private func handleBlankTap() {
        // C5：hero 详情打开时吞掉背景点击（防穿透误触双击返回待机）
        guard hero == nil else {
            lastBlankTap = nil
            blankTapTask?.cancel()
            return
        }
        let now = Date()
        if let last = lastBlankTap, now.timeIntervalSince(last) < 0.28 {
            blankTapTask?.cancel()
            lastBlankTap = nil
            app.backToIdle()
        } else {
            lastBlankTap = now
            let task = DispatchWorkItem { openFocusedRow() }
            blankTapTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: task)
        }
    }

    private func openFocusedRow() {
        guard sel >= 0 else { return }
        switch (page, sel) {
        case (0, _) where sel < p0Coupons.count:
            openCoupon(p0Coupons[sel])           // C5：券卡 → d4 券详情
        case (0, _):
            let idx = sel - p0Coupons.count
            if p0Feeds.indices.contains(idx) { openFeedDetail(p0Feeds[idx]) }   // C6：情报卡 → d5
        case (1, _):
            if favList.indices.contains(sel) { openFeedDetail(favList[sel]) }   // C6：收藏卡 → d5
        case (2, _) where prefs.indices.contains(sel):
            prefOpenAction(prefs[sel])
        default:
            break
        }
    }

    /// p2 偏好行点击动作：rss/nearby/偏好三行开二级页，其余占位提示
    private func prefOpenAction(_ p: Preference) {
        switch p.key {
        case "rss":
            openRss()
        case "nearby":
            openNearby()
        case "taste", "takeout", "price":
            openPrefEdit(p)   // C7：d7 偏好编辑（tag-picker 多选 / 三档 slider）
        default:
            if p.disabled {
                showToast(disabledHint(p))
            } else {
                showToast("「\(p.title)」编辑将在后续版本开放")
            }
        }
    }

    // MARK: C5 hero 打开（源卡几何取自 heroSpots；缺几何 fallback 全屏淡入）

    private func openHero(key: String, sourceID: String, target: M3HeroTarget) {
        blankTapTask?.cancel()   // 清掉待执行的空白单击
        app.enterDetail()        // 红线修复：二级页期间屏蔽翻转导航
        withAnimation(.easeOut(duration: 0.25)) {
            hero = HeroSession(
                key: key,
                sourceID: sourceID,
                sourceFrame: heroSpots[sourceID] ?? CGRect(x: 60, y: 300, width: 330, height: 100)
            )
            heroTarget = target
        }
    }

    private func openCoupon(_ c: CouponCard) {
        openHero(key: "d4", sourceID: "m3-p0-coupon-\(c.id.uuidString)", target: .coupon(c))
    }

    private func openFeedDetail(_ f: FeedItem) {
        // d5 情报详情：源卡 = 当前页（p0 推送 / p1 收藏）同一条目不串位
        openHero(key: "d5", sourceID: "m3-p\(page)-feed-\(f.id.uuidString)", target: .feed(f))
    }

    private func openScan() {
        openHero(key: "scan", sourceID: "m3-scan-card", target: .scan)
    }

    private func openRss() {
        openHero(key: "rss", sourceID: "m3-p2-rss", target: .rss)
    }

    private func openNearby() {
        openHero(key: "nearby", sourceID: "m3-p2-nearby", target: .nearby)
    }

    private func openPrefEdit(_ p: Preference) {
        // C7：d7 偏好编辑（源卡 = p2 对应偏好行）
        openHero(key: "d7", sourceID: "m3-p2-pref-\(p.key)", target: .pref(p))
    }

    /// 后置行提示（B3b：rss 用专属文案，cache/about 等通用）
    private func disabledHint(_ p: Preference) -> String {
        p.key == "rss" ? "RSS 源管理后续版本开放" : "「\(p.title)」后续版本开放"
    }

    // MARK: pager 横向画布（M2 定稿：平移 + 沟槽；垂直交 ScrollView 滚动）

    private let canvasGap: CGFloat = 28

    private var pagerClip: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                HStack(spacing: canvasGap) {
                    page0(width: geo.size.width)
                    page1(width: geo.size.width)
                    page2(width: geo.size.width)
                }
                .frame(width: geo.size.width * 3 + canvasGap * 2,
                       height: geo.size.height, alignment: .leading)
                .offset(x: pagerOffset(clipW: geo.size.width))
                // B5a：锁定中 1:1 跟手；松手/被抢占的归零以 pageSwitch 平滑回弹
                .animation(session.locked ? nil : DSToken.pageSwitch, value: session)
            }
            .coordinateSpace(name: "clipSpace")
            .clipped()
            .contentShape(Rectangle())
            .gesture(pagerDrag(clipW: geo.size.width))
            .onAppear { viewportH = geo.size.height }
        }
    }

    private func pagerOffset(clipW: CGFloat) -> CGFloat {
        var x = -CGFloat(page) * (clipW + canvasGap) + bumpX
        if session.mode == .page {
            let base = session.offset.width
            let atEdge = (page == 0 && base > 0) || (page == 2 && base < 0)
            x += atEdge ? base * 0.38 : base
        }
        return x
    }

    private func hasMore(page p: Int) -> Bool {
        guard viewportH > 0 else { return false }
        return (contentMaxY[p] ?? 0) > viewportH + 0.5
    }

    private func bottomFade(active: Bool) -> some View {
        Group {
            if active {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.0),
                        .init(color: .white, location: 0.88),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            } else {
                Color.white
            }
        }
    }

    // MARK: p0 今日推送（双列栅格：券 + 情报）

    private func page0(width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: DSToken.sp) {
                    if p0Coupons.isEmpty && p0Feeds.isEmpty {
                        M2EmptyText(text: "今天还没有新情报\n收藏喜欢的，明天继续看")
                    } else {
                        // C5+ 方案①：截图导入券入口（虚线卡 · 不参与焦点行索引）
                        HStack(spacing: 8) {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 15, weight: .semibold))
                            Text("截图导入券 · 美团/抖音券面一秒收")
                                .font(DSToken.body(13, weight: .semibold))
                            Spacer()
                            Text("›")
                                .font(DSToken.body(17, weight: .semibold))
                        }
                        .foregroundStyle(DSToken.m3)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(DSToken.m3.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(DSToken.m3.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                        )
                        .onTapGesture { openScan() }
                        .heroSpot(id: "m3-scan-card")
                        .padding(.bottom, 10)

                        LazyVGrid(columns: twoColumns, spacing: 14) {
                            ForEach(Array(p0Coupons.enumerated()), id: \.element.id) { i, c in
                                M3CouponCard(coupon: c, selected: selByPage[0] == i) {
                                    selectRow(page: 0, row: i, fireIfSelected: {
                                        openCoupon(c)
                                    })
                                }
                                .heroSpot(id: "m3-p0-coupon-\(c.id.uuidString)")   // C5：d4 生长源卡
                                .measureFocus(FocusKey(page: 0, row: i), space: "pageSpace")
                                .enterArrive(arrived: arrived, index: i)
                            }
                            ForEach(Array(p0Feeds.enumerated()), id: \.element.id) { i, f in
                                let idx = p0Coupons.count + i
                                M3InfoCard(item: f, selected: selByPage[0] == idx) {
                                    selectRow(page: 0, row: idx, fireIfSelected: {
                                        openFeedDetail(f)
                                    })
                                }
                                .heroSpot(id: "m3-p0-feed-\(f.id.uuidString)")   // C6：d5 生长源卡
                                .measureFocus(FocusKey(page: 0, row: idx), space: "pageSpace")
                                .enterArrive(arrived: arrived, index: idx)
                            }
                        }
                    }
                    contentBottomAnchor(page: 0)
                }
                .padding(.vertical, 6)   // B3a：卡片轻阴影容纳空间（不裁切）
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .mask(bottomFade(active: hasMore(page: 0)))

            FocusCard(frame: focusFrame(pageIdx: 0) ?? .zero,
                      visible: focusVisible(pageIdx: 0), color: DSToken.m3)
                .scaleEffect(page == 0 && focusPulse ? 1.016 : 1)
        }
        .padding(.horizontal, 12)
        .frame(width: width, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 16)        // B3a：与头部胶囊拉开层次（第一卡不再与头部相似）
        .padding(.bottom, 14)
        .coordinateSpace(name: "pageSpace")
    }

    // MARK: p1 收藏（chips 固定 + 收藏卡双列）

    private func page1(width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // chips 固定区（B3a：底部加细分隔线与卡片区分开）
                M3Chips(tags: chipTags, current: filter) { tag in
                    withAnimation(DSToken.springSlow) {
                        filter = tag
                        selByPage[1] = 0
                    }
                }
                .padding(.bottom, 10)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DSToken.line)
                        .frame(height: 1)
                        .padding(.horizontal, 2)
                }
                .padding(.bottom, 8)
                .enterArrive(arrived: arrived, index: 0)

                // B3a 滚动修复：VStack 限高 → ScrollView 拿到剩余高度真正滚动
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if favList.isEmpty {
                            M2EmptyText(text: "还没有「\(filter)」相关的收藏\n去今日推送逛逛，喜欢的可以收藏")
                                .enterArrive(arrived: arrived, index: 1)
                        } else {
                            LazyVGrid(columns: twoColumns, spacing: 14) {
                                ForEach(Array(favList.enumerated()), id: \.element.id) { i, item in
                                    M3InfoCard(item: item, selected: selByPage[1] == i) {
                                        selectRow(page: 1, row: i, fireIfSelected: {
                                            openFeedDetail(item)
                                        })
                                    }
                                    .heroSpot(id: "m3-p1-feed-\(item.id.uuidString)")   // C6：d5 生长源卡（收藏页）
                                    .measureFocus(FocusKey(page: 1, row: i), space: "pageSpace")
                                    .enterArrive(arrived: arrived, index: i + 1)
                                }
                            }
                        }
                        contentBottomAnchor(page: 1)
                    }
                    .padding(.vertical, 6)   // B3a：阴影容纳
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                .mask(bottomFade(active: hasMore(page: 1)))
            }
            .frame(maxHeight: .infinity, alignment: .top)   // B3a：限高 → 列表可滚

            FocusCard(frame: focusFrame(pageIdx: 1) ?? .zero,
                      visible: focusVisible(pageIdx: 1), color: DSToken.m3)
                .scaleEffect(page == 1 && focusPulse ? 1.016 : 1)
        }
        .padding(.horizontal, 12)
        .frame(width: width, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .coordinateSpace(name: "pageSpace")
    }

    // MARK: p2 偏好设置（行列表）

    private func page2(width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: DSToken.sp) {
                    ForEach(Array(prefs.enumerated()), id: \.element.key) { i, p in
                        let row = M3PrefRow(
                            title: p.title,
                            value: M3Store.prefValue(p),
                            note: p.disabled ? "（V0.4.2 后置）" : nil,
                            selected: selByPage[2] == i
                        ) {
                            selectRow(page: 2, row: i, fireIfSelected: {
                                prefOpenAction(p)
                            })
                        }
                        .measureFocus(FocusKey(page: 2, row: i), space: "pageSpace")
                        .enterArrive(arrived: arrived, index: i)
                        Group {
                            if p.key == "rss" || p.key == "nearby" {
                                row.heroSpot(id: "m3-p2-\(p.key)")
                            } else if p.key == "taste" || p.key == "takeout" || p.key == "price" {
                                row.heroSpot(id: "m3-p2-pref-\(p.key)")   // C7：d7 生长源卡
                            } else {
                                row
                            }
                        }
                    }
                    contentBottomAnchor(page: 2)
                }
                .padding(.vertical, 6)   // B3a：阴影容纳
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .mask(bottomFade(active: hasMore(page: 2)))

            FocusCard(frame: focusFrame(pageIdx: 2) ?? .zero,
                      visible: focusVisible(pageIdx: 2), color: DSToken.m3)
                .scaleEffect(page == 2 && focusPulse ? 1.016 : 1)
        }
        .padding(.horizontal, 12)
        .frame(width: width, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .coordinateSpace(name: "pageSpace")
    }

    private var twoColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    }

    // MARK: 手势（M2 定稿：垂直交 ScrollView · 水平切组）

    /// B5a：拖动会话 @GestureState——被 ScrollView/chips 横滚抢占时系统自动归零
    /// （旧 @State 手动复位依赖 onEnded；被抢占时不回调 → 画布卡在半途）
    @GestureState private var session = PagerSession()

    private func pagerDrag(clipW: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($session) { v, state, _ in
                // 垂直意图 → 不锁定，ScrollView 滚动
                if state.mode == .idle {
                    guard abs(v.translation.width) > 8,
                          abs(v.translation.width) > abs(v.translation.height) else { return }
                    state.mode = .page
                }
                state.offset = v.translation
            }
            .onEnded { v in
                // 依末帧位移判定：水平才落页
                let dx = v.translation.width, dy = v.translation.height
                guard abs(dx) > 8, abs(dx) > abs(dy) else { return }
                let result = PagerLogic.settlePage(
                    dragX: dx, width: clipW,
                    fastNext: v.predictedEndLocation.x < v.location.x - 60,
                    fastPrev: v.predictedEndLocation.x > v.location.x + 60,
                    page: page, pageCount: 3
                )
                if result.bumped { bump() }
                withAnimation(DSToken.pageSwitch) { page = result.page }
            }
    }

    private func bump() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        bumpX = 18
        withAnimation(DSToken.bounceQuick) { bumpX = 0 }
    }

    // MARK: 交互路由

    private func selectRow(page p: Int, row: Int, fireIfSelected: @escaping () -> Void = {}) {
        guard selByPage.indices.contains(p) else { return }
        if selByPage[p] == row {
            fireIfSelected()
        } else {
            withAnimation(DSToken.springSlow) { selByPage[p] = row }
            focusPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { focusPulse = false }
        }
    }

    private func clampSelections() {
        if selByPage[0] > p0Coupons.count + p0Feeds.count - 1 { selByPage[0] = max(p0Coupons.count + p0Feeds.count - 1, -1) }
        if selByPage[1] > favList.count - 1 { selByPage[1] = max(favList.count - 1, -1) }
        if selByPage[2] > prefs.count - 1 { selByPage[2] = max(prefs.count - 1, -1) }
    }

    // MARK: 焦点几何

    private func focusFrame(pageIdx: Int) -> CGRect? {
        guard selByPage.indices.contains(pageIdx) else { return nil }
        let s = selByPage[pageIdx]
        guard s >= 0, let f = focusFrames[FocusKey(page: pageIdx, row: s)] else { return nil }
        return f
    }

    private func focusVisible(pageIdx: Int) -> Bool {
        arrived && focusFrame(pageIdx: pageIdx) != nil
    }

    private func contentBottomAnchor(page p: Int) -> some View {
        Color.clear
            .frame(height: 0)
            .background(
                GeometryReader { g in
                    Color.clear.preference(
                        key: ContentBottomKey.self,
                        value: [p: g.frame(in: .named("pageSpace")).maxY]
                    )
                }
            )
    }

    // MARK: 扩展数据（B3a 真机验证：p0 推送 +6 / 收藏 +4 —— 超出后滚动/渐隐/筛选交互可验）
    // 新 flag 幂等：标题去重（老用户补插、新装用户跳过重复）；券不重复补。

    private func seedExtraIfNeeded() {
        seedExtraFeedsV2()
        seedExtraPrefsV3()
        seedCouponC5IfNeeded()
        seedIntegrationsIfNeeded()
    }

    /// C5+ 方案②③④数据源接线：rss 行开放 + nearby 行 + 订阅源示例（幂等 flag）
    private func seedIntegrationsIfNeeded() {
        let flag = "m3.seeded.integrations"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(true, forKey: flag)
        if let rss = prefs.first(where: { $0.key == "rss" }) {
            rss.disabled = false
            rss.sub = "RSS/Atom 公开源 · 拉取进今日推送"
        }
        if !prefs.contains(where: { $0.key == "nearby" }) {
            modelContext.insert(Preference(
                key: "nearby", title: "附近好店", sub: "高德周边搜索 · 一键收进情报",
                options: ["美食 · 奶茶 · 亲子"], sortOrder: 3
            ))
        }
        let existUrls = Set(rssSources.map(\.url))
        let seeds: [(String, String)] = [
            ("少数派", "https://sspai.com/feed"),
            ("爱范儿", "https://www.ifanr.com/feed"),
        ]
        for (t, u) in seeds where !existUrls.contains(u) {
            modelContext.insert(RssSource(title: t, url: u))
        }
    }

    /// C5：补一张「已过期」券（验证四态终态视觉 + 置灰 CTA；幂等 flag）
    private func seedCouponC5IfNeeded() {
        let flag = "m3.seeded.c5"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(true, forKey: flag)
        guard !coupons.contains(where: { $0.title == "咖啡第二杯半价" }) else { return }
        modelContext.insert(CouponCard(
            title: "咖啡第二杯半价", sub: "街角咖啡 · 到店出示",
            value: "第二杯半价", threshold: "单杯饮品可用 · 限下午茶时段",
            daysLeft: 0, valid: "10-01 至 10-06", scope: "到店核销 · 每单限用一张",
            progress: 100, state: "expired", code: "",
            shops: ["街角咖啡 · 中山店：步行 4 分钟"],
            createdAt: Date(timeIntervalSinceNow: -86400 * 9)
        ))
    }

    /// v2：情报扩展（p0 推送 +6 / 收藏 +6 · 幂等：标题去重；老用户补插、新装用户跳过）
    private func seedExtraFeedsV2() {
        let flag = "m3.seeded.v2"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(true, forKey: flag)
        let existTitles = Set(feeds.map(\.title))
        let extra: [(String, String, String, String, String, [String], Bool, [String])] = [
            // —— 今日推送 inFeed +6 ——
            ("应季", "秋季儿童收纳茶包搭配", "家常菜研究 · 3 小时前", "家常菜研究", "3 小时前", ["应季", "炖汤", "买菜"], true, [
                "入秋后换季收纳，先收夏装再叠秋装：薄外套挂门厅，贴身层抽屉分格，孩子自己也能找。",
                "茶包组合：菊花决明子各半、陈皮两片、冰糖一块，沸水焖五分钟，温热喝最舒服。",
                "收纳盒选透明硬盒，盖顶留标签位，贴手写纸片比打印更容易坚持更新。",
            ]),
            ("亲子", "宝宝夜藏着 8 个遛娃点", "亲子出行指南 · 5 小时前", "亲子出行指南", "5 小时前", ["亲子", "目的地"], true, [
                "小区周边三公里内，能找到的免费遛娃点其实超过八个。","排名按雨天可用程度：地铁口架空层、社区活动室、商场玩具区、书店绘本角。","记得带垫子和湿巾，多数点有长椅但没洗手台。",
            ]),
            ("应季", "柚子茶碗：挑柚三看", "家常菜研究 · 昨天", "家常菜研究", "昨天", ["应季", "买菜"], true, [
                "挑柚子先看形状：上尖下宽、重心稳的最好。","再掂重量：同样大小重的皮薄；最后按底部，有弹性说明水分足。","秋冬买柚不必追求大，皮薄果小的反而甜。",
            ]),
            ("美食", "深夜食堂：巷口的猪脚饭", "常逛清单 · 昨晚", "常逛清单", "昨晚", ["美食", "夜宵"], true, [
                "加班回家巷口那家还亮着灯，猪脚饭加卤蛋十九块。","汤头是那种熬了很久的酱色，配的酸菜解腻，夜宵点单率最高。","十二点后常要排队，避开高峰可以九点半去。",
            ]),
            ("美食", "深夜糖水档营业时间", "常逛清单 · 昨晚", "常逛清单", "昨晚", ["美食", "夜宵"], true, [
                "老城区那家深夜糖水档，晚上十点才开门，卖到凌晨两点。","招牌是热双皮奶和椰汁西米露，打包比堂食多，路上也顺。","周末人多，记得先加老板微信留一杯，不然可能要等二十分钟。",
            ]),
            ("好物", "办公室好物：久坐腰靠", "常逛清单 · 今天", "常逛清单", "今天", ["好物", "买菜"], true, [
                "久坐腰靠选了三个月，最后留下的这款是记忆棉材质，高度可调。","支撑点在腰椎第三到五节，靠上去腰不会被顶起来。","便宜的和贵的差别主要在面料的透气性，夏天款要选网面。",
            ]),
            // —— 收藏 fav +4（inFeed:false）——
            ("目的地", "第一次收藏：环湖绿道一日", "收藏于 10-11", "收藏于 10-11", "收藏于 10-11", ["目的地", "美食"], false, [
                "环湖绿道全长十一公里，租车两小时能骑完。","中段有野餐区，带娃的话适合骑到中段回头。","湖边的牛肉面和豆腐花都在南门出口，顺路解决晚饭。",
            ]),
            ("应季", "桂花季：桂花糕三种做法", "收藏于 10-08", "收藏于 10-08", "收藏于 10-08", ["应季", "炖汤", "买菜"], false, [
                "桂花糕第一种：糯米粉加糖蒸，桂花糖水淋面，口感糯。","第二种是藕粉桂花糕，藕粉多桂花少，清爽弹牙。","第三种最简单：白粥加桂花和冰糖，煮到稠即可，适合新手。",
            ]),
            ("美食", "街角书店的下午茶", "收藏于 10-15", "收藏于 10-15", "收藏于 10-15", ["美食"], false, [
                "旧厂房书店二楼的下午茶，靠窗位能看到街角的老骑楼。","热拿铁配当日蛋糕，老板会先问口味再推荐，不会踩雷。","周末人多，两点前去能占到窗边位置。",
            ]),
            ("目的地", "雨天遛娃：室内清单", "收藏于 10-22", "收藏于 10-22", "收藏于 10-22", ["亲子", "目的地"], false, [
                "雨天遛娃首选地铁沿线：商场、书店、科技馆都在线路上。","社区剧场周末有儿童场，性价比高。","备一套雨具和换洗衣物，湿了随时换。",
            ]),
            ("亲子", "亲子厨房：周五一起吃锅", "收藏于 10-18", "收藏于 10-18", "收藏于 10-18", ["亲子", "美食"], false, [
                "周五晚上吃小火锅，锅底一半白汤一半番茄。","孩子负责洗菜和摆碗，家长负责切和看火。","食材提前备好，饭后一起收拾，把家务变成游戏。",
            ]),
            ("好物", "秋冬围巾：三条够换洗", "收藏于 10-20", "收藏于 10-20", "收藏于 10-20", ["好物"], false, [
                "秋冬三条围巾就够：一条纯色百搭，一条亮色点睛，一条羊绒保暖。","围巾的收纳用挂环，不占柜子也不起褶。","清洗用中性洗涤剂手洗，机洗容易变形。",
            ]),
        ]
        for (tag, title, sub, source, time, tags, inFeed, paragraphs) in extra {
            guard !existTitles.contains(title) else { continue }
            modelContext.insert(FeedItem(
                tag: tag, title: title, sub: sub, source: source, time: time,
                tags: tags, fav: !inFeed, inFeed: inFeed, paragraphs: paragraphs
            ))
        }
    }

    /// v3（B3b）：p2 偏好行扩充（+8 → 12 行超出可滚）+ 修正 v2 旧格式收藏时间（10月08 → 10-08）
    private func seedExtraPrefsV3() {
        let pflag = "m3.seeded.v3"
        guard !UserDefaults.standard.bool(forKey: pflag) else { return }
        UserDefaults.standard.set(true, forKey: pflag)
        // 修正 v2 旧格式收藏时间（统一「收藏于 MM-dd」）
        for f in feeds where f.sub.contains("10月") {
            let fixed = f.sub.replacingOccurrences(of: "10月", with: "10-")
            f.sub = fixed
            if !f.time.isEmpty { f.time = fixed }
        }
        // 新增偏好行（按 key 去重，幂等）
        let existKeys = Set(prefs.map(\.key))
        let extraPrefs: [(String, String, String, [String], Int, Bool)] = [
            ("notify", "推送时间", "影响情报推送时刻", ["每天 8:30"], 4, false),
            ("city",   "常驻城市", "周边情报优先展示", ["广州 · 天河"], 5, false),
            ("refresh", "刷新频率", "情报拉取节奏", ["每 2 小时 · 仅 Wi-Fi"], 6, false),
            ("dark",   "外观主题", "内置浅色 / 跟随系统", ["跟随系统"], 7, false),
            ("font",   "字体大小", "标准 / 大 / 特大", ["标准"], 8, false),
            ("sound",  "推送提示音", "推送时播放", ["清脆铃声"], 9, false),
            ("cache",  "清理缓存", "离线情报暂存", ["已缓存 12.8 MB"], 10, true),
            ("about",  "关于我看看", "版本与更新检查", ["版本 0.4.1 · 检查更新"], 11, true),
        ]
        for (key, title, sub, selected, order, dis) in extraPrefs {
            guard !existKeys.contains(key) else { continue }
            modelContext.insert(Preference(
                key: key, title: title, sub: sub,
                options: selected, selected: selected,
                sortOrder: order, disabled: dis
            ))
        }
    }

    // MARK: 首次 seed（原型数据表：1 券 + 3 今日情报 + 2 收藏 + 3 偏好）

    private func seedIfNeeded() {
        let flag = "m3.seeded"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(true, forKey: flag)
        guard feeds.isEmpty, coupons.isEmpty else { return }
        // 券
        modelContext.insert(CouponCard(
            title: "奶茶买一送一", sub: "楼下那家 · 到店出示",
            value: "买一送一", threshold: "单笔满 20 元可用",
            daysLeft: 3, valid: "10-13 至 10-16", scope: "到店核销 · 不与其他优惠同享",
            progress: 72, code: "8246 3917",
            shops: ["楼下那家 · 万象店：步行 6 分钟", "楼下那家 · 金融街店：地铁 2 号线 · 1.1km"]
        ))
        // 情报（3 条 inFeed + 2 条收藏）
        let feeds: [(String, String, String, String, String, [String], Bool, [String])] = [
            ("亲子", "周末带娃 City Walk 路线", "亲子出行指南 · 2 小时前", "亲子出行指南", "2 小时前", ["亲子", "目的地"], true, [
                "周末不想跑远，就在家附近走一条两小时的路线。地铁三号线下来，沿江往南，江边这一段有连续的骑行道和树荫，推车推行也不费力。",
                "第一站是社区公园的儿童沙池区，午后两点人最少，遮阳伞下有长椅和自动贩卖机。沿江再走十分钟就是旧厂房改造的书店，有亲子阅读角。",
                "返程绕到桥下的小广场，有公共洗手间和换衣间。整个路线单程约 2.4 公里，推车加步行约两小时。",
            ]),
            ("好物", "宝宝启蒙绘本套装 −30%", "常逛清单 · 今日最低", "常逛清单", "今日最低", ["亲子", "买菜"], true, [
                "常逛的童书店这周把启蒙绘本整套做了活动，二十本折后两百一左右，一本十来块。",
                "封面设计和纸张不错，纸张偏厚不易撕页，圆角处理对低龄宝宝友好。内容按月龄分段。",
                "套装里重复了两本同系列的，家里已有的话可以拆开单买缺的两本，价格更低。",
            ]),
            ("应季", "秋季炖汤食材清单，照着买就行", "家常菜研究 · 昨天", "家常菜研究", "昨天", ["炖汤", "应季", "买菜"], true, [
                "秋天煲汤三样打底：排骨或筒骨、老鸭、秋梨或藕。",
                "排骨焯水小火炖四十分钟，鸭肉另炖两小时，混合加梨或藕再炖半小时，汤色转奶白。",
                "盐最后放。周末一次炖够分装冷藏，工作日加热就能喝。",
            ]),
            ("目的地", "南平三日：山、汤、慢", "收藏于 10-03", "收藏于 10-03", "收藏于 10-03", ["目的地", "美食", "应季"], false, [
                "第一天下午到，去河边老街走一圈，傍晚的光打在旧骑楼上很值得。",
                "第二天上午上山，来回三小时，山路平缓。中午下山吃汤锅，本地做法清淡。",
                "第三天睡到自然醒，逛糖水铺和书店。不用赶行程的三日刚好。",
            ]),
            ("美食", "老城区糖水铺地图", "收藏于 09-28", "收藏于 09-28", "收藏于 09-28", ["美食", "夜宵"], false, [
                "按位置排了六家，都在老城区步行范围内，适合一天走两三家的节奏。",
                "第一家现做糖水，芋泥和西米扎实。第二家双皮奶，奶味浓但偏甜。",
                "第三到第五家偏饮品和老字号甜品。第四家晚上才开门做宵夜糖水。",
            ]),
        ]
        for (tag, title, sub, source, time, tags, inFeed, paragraphs) in feeds {
            modelContext.insert(FeedItem(
                tag: tag, title: title, sub: sub, source: source, time: time,
                tags: tags, fav: !inFeed, inFeed: inFeed, paragraphs: paragraphs
            ))
        }
        // 偏好（taste/takeout 多选 + price 三档；rss 后置）
        modelContext.insert(Preference(
            key: "taste", title: "口味偏好", sub: "多选 · 影响情报推荐的排序",
            options: ["偏甜", "少辣", "汤水党", "清淡", "重口", "爱海鲜"],
            selected: ["偏甜", "少辣", "汤水党"], sortOrder: 0
        ))
        modelContext.insert(Preference(
            key: "takeout", title: "常点外卖", sub: "多选 · 影响情报推荐的排序",
            options: ["糖水", "粥粉面", "轻食", "快餐", "家常菜", "烧腊"],
            selected: ["糖水", "粥粉面", "轻食"], sortOrder: 1
        ))
        modelContext.insert(Preference(
            key: "price", title: "价格敏感度", sub: "单选",
            options: M3Store.priceTiers, level: 1, sortOrder: 2
        ))
        modelContext.insert(Preference(
            key: "rss", title: "RSS 源", sub: "已订 4 个 · 管理 ›",
            options: [], selected: ["已订 4 个 · 管理 ›"],
            sortOrder: 3, disabled: true
        ))
    }

    // MARK: Toast

    private func showToast(_ text: String) {
        withAnimation(DSToken.bounce) { toast = ToastMsg(text: text) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(DSToken.spring) {
                if toast?.text == text { toast = nil }
            }
        }
    }
}

// MARK: - 焦点几何上报（页本地坐标系，M3 专用）

private struct M3FocusPreferenceKey: PreferenceKey {
    static var defaultValue: [M3Screen.FocusKey: CGRect] = [:]
    static func reduce(value: inout [M3Screen.FocusKey: CGRect], nextValue: () -> [M3Screen.FocusKey: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// M3 卡片行上报自身 frame（页本地），驱动浮动焦点卡定位
    func measureFocus(_ key: M3Screen.FocusKey, space: String) -> some View {
        background(
            GeometryReader { g in
                Color.clear.preference(
                    key: M3FocusPreferenceKey.self,
                    value: [key: g.frame(in: .named(space))]
                )
            }
        )
    }
}