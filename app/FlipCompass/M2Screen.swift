import SwiftUI
import SwiftData

// MARK: - M2 今天的想法 · 一级模块屏（B2）
// 两分组画布 pager：p0 今日（记录卡 + 想法条目）/ p1 月视图（月导航 + 该月想法）。
// 骨架复用 M1 定稿交互：画布平移 28pt 沟槽 · 焦点卡 springSlow 滑移 · 水平切组 ·
// 单击空白打开焦点 · 双击返回待机。#scr-m2 转录。
// B2a（真机反馈）：想法会长期积累列表变长 → 两页列表可滚动；超出时底部渐隐遮罩
// 提示可滚（滚到底渐隐自然消失）；ScrollView 接管垂直拖动（M1 的逐行步进在 M2 退役，
// 焦点改纯点击选中）；水平拖动冒泡至 pager 切组不受影响。

struct M2Screen: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Thought.createdAt, order: .reverse)]) private var thoughts: [Thought]

    // —— 分组 / 选中状态（p1 空月份无焦点 = -1）——
    @State private var page = 0
    @State private var selByPage: [Int] = [0, 0]
    @State private var bumpX: CGFloat = 0
    @State private var arrived = false

    // B2a：列表滚动与超出检测（内容尾锚 maxY 相对 pageSpace 实时上报；
    // 滚到底时尾锚顶到视口底 → contentMaxY ≈ viewportH → 渐隐自然消失）
    struct ContentBottomKey: PreferenceKey {
        static var defaultValue: [Int: CGFloat] = [:]
        static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
            value.merge(nextValue()) { _, new in new }
        }
    }
    @State private var contentMaxY: [Int: CGFloat] = [:]
    @State private var viewportH: CGFloat = 0

    // —— p1 月视图当前月份（默认当月）——
    @State private var monthYear: Int = Calendar.current.component(.year, from: Date())
    @State private var month: Int = Calendar.current.component(.month, from: Date())
    // 需求②：时间轴日期折叠（组日期为键；重进模块重置为全展开）
    @State private var collapsedDates: Set<Date> = []

    // —— 二级页（C3/C4 全 hero 化：d2 记录/草稿 · d9 想法详情）——

    // —— C3/C4 hero 生长会话（记录卡/想法行生长源）——
    @State private var hero: HeroSession? = nil
    @State private var heroClosing = false
    @State private var heroTarget: M2HeroTarget? = nil
    @State private var heroSpots: [String: CGRect] = [:]
    /// d9 删除延迟删库（收回动画后再删，防已删模型被内容层渲染）
    @State private var pendingDelete: Thought? = nil

    enum M2HeroTarget {
        case composeNew           // d2 记录一条（源卡 = 记录卡）
        case composeEdit(Thought) // d2 编辑（源卡 = 想法行；保存后回 d9，V0.4.5 闭环）
        case detail(Thought)      // d9 想法详情（源卡 = 想法行）
    }

    // —— C4：右侧缩略预览卡（MINI）状态 ——
    @State private var miniBig = false
    @State private var miniPageIdx = 0

    // —— 记录卡草稿副标数据（R8 ③ 实算）：草稿按创建时间降序 ——
    @Query(sort: [SortDescriptor(\Draft.createdAt, order: .reverse)]) private var draftsForSubtitle: [Draft]

    // —— 焦点卡几何（各页行 → 页本地 frame）——
    struct FocusKey: Hashable { let page: Int; let row: Int }
    @State private var focusFrames: [FocusKey: CGRect] = [:]
    @State private var focusPulse = false

    @State private var toast: ToastMsg? = nil

    struct ToastMsg: Identifiable, Equatable {
        let id = UUID()
        let text: String
    }

    // MARK: 数据派生（今日 / 月 · 实算）

    private var todayList: [Thought] { M2Store.todayThoughts(thoughts, today: Date()) }
    private var monthList: [Thought] { M2Store.monthThoughts(thoughts, year: monthYear, month: month) }

    private var sel: Int { selByPage.indices.contains(page) ? selByPage[page] : -1 }

    // MARK: 布局

    var body: some View {
        ZStack {
            ModuleBackdrop(module: .m2)

            VStack(spacing: 0) {
                ModuleHeader(
                    module: .m2,
                    subtitle: "一两句，就够了",
                    chip: M2Store.headline(todayCount: todayList.count),
                    chipValue: todayList.count
                )
                pagerClip
                ModuleDots(count: 2, current: page, color: DSToken.m2)
                NavHint(text: "上下滚动看更多 · 左右滑换分组 · 点击选中")
            }
            .padding(.top, 58)
            .padding(.bottom, 14)
            .padding(.horizontal, 21)

            if let t = toast {
                ModuleToast(text: t.text, color: DSToken.m2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 120)
                    .allowsHitTesting(false)
            }

            // C4：右侧缩略预览卡 + 贝塞尔曲线（选中可进二级条目时浮现；放大态时曲线收起）
            if let spec = miniSpec, let _ = heroSpots[spec.spotID] {
                miniLayer(spec)
                    .transition(.opacity)
            }

            // C3/C4：hero 卡片生长覆盖层（d2 记录/草稿 · d9 详情）
            if let h = hero, let target = heroTarget {
                HeroOverlay(
                    session: h,
                    tintColor: DSToken.tintM2,
                    onBack: { heroClosing = true },
                    onClosed: {
                        if let t = pendingDelete { modelContext.delete(t); pendingDelete = nil }
                        withAnimation(.easeOut(duration: 0.3)) {   // MINI 浮现过渡容器
                            hero = nil
                            heroClosing = false
                            heroTarget = nil
                        }
                        app.exitDetail()   // 红线修复：二级页关闭，恢复翻转导航
                    },
                    closing: heroClosing
                ) {
                    switch target {
                    case .detail(let t):
                        M2DetailPage(
                            thought: t,
                            onBack: { heroClosing = true },
                            onEdit: { switchHero(.composeEdit(t)) },
                            onDelete: { preview in
                                showToast("已删除「\(preview)」")
                                pendingDelete = t
                                heroClosing = true
                            }
                        )
                        .transition(.opacity)
                    case .composeNew:
                        M2ComposePage(
                            editing: nil,
                            onDone: { msg in
                                showToast(msg)
                                heroClosing = true   // 发布成功 → 原路收回
                            },
                            onCancel: { heroClosing = true }
                        )
                        .transition(.opacity)
                    case .composeEdit(let t):
                        M2ComposePage(
                            editing: t,
                            onDone: { msg in
                                showToast(msg)
                                switchHero(.detail(t))   // V0.4.5：编辑保存后回详情（刷新）
                            },
                            onCancel: { switchHero(.detail(t)) }   // 取消也回详情（编辑闭环）
                        )
                        .transition(.opacity)
                    }
                }
            }
        }
        .environment(\.heroSourceID, hero.map(\.sourceID))   // C3：生长中源卡自隐藏
        .coordinateSpace(name: "heroSpace")                   // hero 源卡/覆盖层共用坐标系
        .animation(DSToken.bounce, value: toast)
        // 单击空白 280ms 打开焦点内容；二击 = 双击返回待机（R7）
        .contentShape(Rectangle())
        .onTapGesture { handleBlankTap() }
        .onAppear {
            seedIfNeeded()
            withAnimation(DSToken.springSlow) { arrived = true }
            // DEBUG 后门：-m2-page 0/1 直达分组；-m2-compose/-m2-detail 直开二级页（模拟器截图验证）
            if let idx = CommandLine.arguments.firstIndex(of: "-m2-page"),
               let p = CommandLine.arguments.indices.contains(idx + 1) ? Int(CommandLine.arguments[idx + 1]) : nil,
               (0...1).contains(p) {
                page = p
            }
            if CommandLine.arguments.contains("-m2-compose") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { openComposeNew() }
            }
            if CommandLine.arguments.contains("-m2-detail"), let first = todayList.first {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { openDetail(first) }
            }
        }
        .onPreferenceChange(ContentBottomKey.self) { contentMaxY = $0 }
        .onPreferenceChange(HeroSpotKey.self) { heroSpots = $0 }   // C3/C4：源卡几何收集
        .onChange(of: thoughts.count) { _, _ in clampSelections() }
        .onChange(of: monthYear) { _, _ in withAnimation(DSToken.springSlow) { selByPage[1] = min(selByPage[1], monthList.count - 1) } }
        .onChange(of: month) { _, _ in withAnimation(DSToken.springSlow) { selByPage[1] = min(selByPage[1], monthList.count - 1) } }
    }

    // MARK: 空白点击（单击打开焦点 · 双击返回待机）

    @State private var lastBlankTap: Date? = nil
    @State private var blankTapTask: DispatchWorkItem? = nil

    private func handleBlankTap() {
        // C3：hero 详情打开时吞掉背景点击（防穿透误触双击返回待机）
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

    /// 单击空白 = 打开当前焦点内容（记录卡 → d2 新建 · 想法行 → d9 详情）
    private func openFocusedRow() {
        guard sel >= 0 else { return }
        focusOpenAction()
    }

    private func focusOpenAction() {
        switch (page, sel) {
        case (0, 0):
            openComposeNew()                          // 记录卡 → d2（回填当前草稿）
        case (0, _):
            if todayList.indices.contains(sel - 1) { openDetail(todayList[sel - 1]) }
        case (1, _):
            if monthList.indices.contains(sel) { openDetail(monthList[sel]) }
        default:
            break
        }
    }

    // MARK: C3/C4 hero 打开（源卡几何取自 heroSpots；缺几何 fallback 全屏淡入）

    /// 统一生长入口：捕获源卡几何 → 建会话 → 锁定目标页
    private func openHero(key: String, sourceID: String, target: M2HeroTarget) {
        blankTapTask?.cancel()   // 清掉待执行的空白单击
        app.enterDetail()        // 红线修复：二级页期间屏蔽翻转导航
        withAnimation(.easeOut(duration: 0.25)) {     // MINI 随开卡淡出
            hero = HeroSession(
                key: key,
                sourceID: sourceID,
                sourceFrame: heroSpots[sourceID] ?? CGRect(x: 60, y: 300, width: 330, height: 100)
            )
            heroTarget = target
        }
    }

    private func openComposeNew() {
        openHero(key: "d2", sourceID: "m2-compose-card", target: .composeNew)
    }

    private func openDetail(_ t: Thought) {
        openHero(key: "d9", sourceID: "m2-p\(page)-item-\(t.id.uuidString)", target: .detail(t))
    }

    /// d9 ⇌ d2 编辑闭环切换（hero 保持生长态，内容交叉淡入淡出）
    private func switchHero(_ t: M2HeroTarget) {
        withAnimation(.easeInOut(duration: 0.25)) { heroTarget = t }
    }

    // MARK: C4 右侧缩略预览卡（MINI · 原型 updateMiniPreview/mini-preview 转录）

    /// 选中条目有二级目标时的缩略卡规格（d3 类表单目标不出卡）
    struct MiniSpec {
        let spotID: String
        let title: String
        let pages: [String]
    }

    private var miniSpec: MiniSpec? {
        guard hero == nil, arrived else { return nil }
        switch (page, sel) {
        case (0, 0):
            return MiniSpec(spotID: "m2-compose-card", title: "记录一条",
                            pages: ["记录一条", "草稿箱"])   // MINI.d2 双子页
        case (0, let i) where i >= 1:
            guard todayList.indices.contains(i - 1) else { return nil }
            let t = todayList[i - 1]
            return MiniSpec(spotID: "m2-p0-item-\(t.id.uuidString)",
                            title: String(t.text.prefix(9)), pages: ["想法详情"])   // MINI.d9
        case (1, let i) where i >= 0:
            guard monthList.indices.contains(i) else { return nil }
            let t = monthList[i]
            return MiniSpec(spotID: "m2-p1-item-\(t.id.uuidString)",
                            title: String(t.text.prefix(9)), pages: ["想法详情"])
        default:
            return nil
        }
    }

    /// 缩略卡层：右侧 22 / top 112；曲线从条目右缘连卡左缘（放大态收起）
    private func miniLayer(_ spec: MiniSpec) -> some View {
        GeometryReader { geo in
            let w: CGFloat = miniBig ? 248 : 112
            let h: CGFloat = 130
            let cardX = geo.size.width - 22 - w
            let cardY: CGFloat = 112
            ZStack {
                if !miniBig, let f = heroSpots[spec.spotID] {
                    MiniCurve(
                        from: CGPoint(x: f.maxX, y: f.midY),
                        to: CGPoint(x: cardX, y: cardY + h * 0.45),
                        color: DSToken.m2
                    )
                    .allowsHitTesting(false)
                    .id(spec.spotID)   // 换选中条目 → 重放画入动画
                }
                MiniPreviewCard(
                    title: spec.title,
                    sub: spec.pages[min(miniPageIdx, spec.pages.count - 1)],
                    pageCount: spec.pages.count,
                    pageIdx: miniPageIdx,
                    color: DSToken.m2,
                    big: miniBig,
                    onPage: { i in
                        miniPageIdx = i
                        if miniBig { withAnimation(DSToken.spring) { miniBig = false } }   // 原型：点页点收起放大态
                    },
                    onToggle: {
                        withAnimation(DSToken.spring) { miniBig.toggle() }   // 原型 width .32 spring
                    }
                )
                .position(x: cardX + w / 2, y: cardY + h / 2)
            }
        }
        .onChange(of: spec.spotID) { _, _ in   // 换选中条目 → 子页复位
            miniPageIdx = 0
            miniBig = false
        }
    }

    // MARK: pager 横向画布（B1 定稿：并排画布平移 + 28pt 沟槽；B2a：垂直交 ScrollView 滚动）

    private let canvasGap: CGFloat = 28

    private var pagerClip: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                HStack(spacing: canvasGap) {
                    page0(width: geo.size.width)
                    page1(width: geo.size.width)
                }
                .frame(width: geo.size.width * 2 + canvasGap,
                       height: geo.size.height, alignment: .leading)
                .offset(x: pagerOffset(clipW: geo.size.width))
                // B5a：锁定中 1:1 跟手（nil）；松手/被抢占的归零以 pageSwitch 平滑回弹
                .animation(session.locked ? nil : DSToken.pageSwitch, value: session)
            }
            .coordinateSpace(name: "clipSpace")
            .clipped()
            .contentShape(Rectangle())
            .gesture(pagerDrag(clipW: geo.size.width))
            .onAppear { viewportH = geo.size.height }   // B2a：视口高（超出判定基准）
        }
    }

    private func pagerOffset(clipW: CGFloat) -> CGFloat {
        var x = -CGFloat(page) * (clipW + canvasGap) + bumpX
        if session.mode == .page {
            let base = session.offset.width
            let atEdge = (page == 0 && base > 0) || (page == 1 && base < 0)
            x += atEdge ? base * 0.38 : base
        }
        return x
    }

    /// B2a：页面是否尚有未滚到底的内容（底部渐隐遮罩条件）
    /// 内容尾锚实时上报 maxY 相对 pageSpace；滚到底时尾锚顶到视口底 → maxY ≤ viewportH
    private func hasMore(page p: Int) -> Bool {
        guard viewportH > 0 else { return false }
        return (contentMaxY[p] ?? 0) > viewportH + 0.5
    }

    /// B2a：底部渐隐遮罩（白 → 0.88 → clear，底部 12% 渐隐提示可滚）
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

    // MARK: 焦点卡几何

    private func focusFrame(pageIdx: Int) -> CGRect? {
        guard selByPage.indices.contains(pageIdx) else { return nil }
        let s = selByPage[pageIdx]
        guard s >= 0, let f = focusFrames[FocusKey(page: pageIdx, row: s)] else { return nil }
        return f
    }

    private func focusVisible(pageIdx: Int) -> Bool {
        arrived && focusFrame(pageIdx: pageIdx) != nil
    }

    // MARK: p0 今日（记录卡 + 想法条目 · B2a 可滚动 + 超出渐隐）

    private func page0(width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: DSToken.sp) {
                    M2ComposeCard(
                        subtitle: M2Store.composeSubtitle(
                            draftCount: draftsForSubtitle.count,
                            latestDate: draftsForSubtitle.first?.date
                        ),
                        selected: selByPage[0] == 0
                    ) {
                        selectRow(page: 0, row: 0, fireIfSelected: { openComposeNew() })
                    }
                    .heroSpot(id: "m2-compose-card")   // C3：d2 的生长源卡
                    .measureFocus(FocusKey(page: 0, row: 0), space: "pageSpace")
                    .enterArrive(arrived: arrived, index: 0)

                    ForEach(Array(todayList.enumerated()), id: \.element.id) { idx, item in
                        M2ThoughtRow(
                            leading: ThoughtFormat.hhmm(item.time),
                            text: item.text,
                            mood: item.mood,
                            selected: selByPage[0] == idx + 1
                        ) {
                            selectRow(page: 0, row: idx + 1, fireIfSelected: {
                                openDetail(item)
                            })
                        }
                        .heroSpot(id: "m2-p0-item-\(item.id.uuidString)")   // C3：d2 编辑生长源
                        .measureFocus(FocusKey(page: 0, row: idx + 1), space: "pageSpace")
                        .enterArrive(arrived: arrived, index: idx + 1)
                    }

                    // B2a：内容尾锚（超出判定；滚到底时 maxY ≈ viewportH → 渐隐消失）
                    contentBottomAnchor(page: 0)
                }
            }
            .scrollBounceBehavior(.basedOnSize)   // 不超出时不弹
            .scrollIndicators(.hidden)
            .mask(bottomFade(active: hasMore(page: 0)))

            // 焦点卡在 mask 之上（选中底部行时保持清晰，不随列表渐隐）
            FocusCard(frame: focusFrame(pageIdx: 0) ?? .zero,
                      visible: focusVisible(pageIdx: 0), color: DSToken.m2)
                .scaleEffect(page == 0 && focusPulse ? 1.016 : 1)
        }
        .padding(.horizontal, 12)
        .frame(width: width, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .coordinateSpace(name: "pageSpace")
    }

    /// 需求②：时间轴日期折叠/展开切换（调用方 withAnimation 包裹）
    private func toggleCollapse(_ date: Date) {
        if collapsedDates.contains(date) {
            collapsedDates.remove(date)
        } else {
            collapsedDates.insert(date)
        }
    }

    // MARK: p1 月视图（B2b：强化月切换 + 按日分组时间轴 + 短宽卡片 · 可滚动 + 超出渐隐）

    private func page1(width: CGFloat) -> some View {
        // 时间轴分组（组间日期降序 · 组内时刻降序）+ flat 行索引（焦点卡与点击用全列表索引）
        let groups = M2Store.monthGroups(thoughts, year: monthYear, month: month)
        var offsets: [Int] = []
        var running = 0
        for g in groups { offsets.append(running); running += g.thoughts.count }

        return ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // B2c：月份导航固定区（不随列表滚动；四周留白承载边缘发光）
                M2MonthNav(year: monthYear, month: month, onPrev: {
                    let s = M2Store.shiftMonth(year: monthYear, month: month, by: -1)
                    withAnimation(DSToken.springSlow) { monthYear = s.year; month = s.month }
                }, onNext: {
                    let s = M2Store.shiftMonth(year: monthYear, month: month, by: 1)
                    withAnimation(DSToken.springSlow) { monthYear = s.year; month = s.month }
                })
                .padding(.horizontal, 4)
                .padding(.top, 2)
                .padding(.bottom, 16)          // 发光留白 + 列表间距
                .enterArrive(arrived: arrived, index: 0)

                // 滚动区：时间轴列表（超出渐隐）
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if groups.isEmpty {
                            M2EmptyText(text: M2Store.monthEmpty)
                                .enterArrive(arrived: arrived, index: 1)
                        } else {
                            ForEach(Array(groups.enumerated()), id: \.element.date) { gi, g in
                                // 需求②：收起 icon + 点击折叠（收起时隐藏该日全部条目）
                                M2TimelineHeader(
                                    title: M2Store.dayTitle(g.date),
                                    collapsed: collapsedDates.contains(g.date)
                                ) {
                                    withAnimation(DSToken.spring) { toggleCollapse(g.date) }
                                }
                                .enterArrive(arrived: arrived, index: gi * 3 + 1)
                                if !collapsedDates.contains(g.date) {
                                    ForEach(Array(g.thoughts.enumerated()), id: \.element.id) { ti, t in
                                        let flat = offsets[gi] + ti
                                        M2TimelineRow(
                                            time: ThoughtFormat.hhmm(t.time),
                                            text: t.text,
                                            mood: t.mood,
                                            selected: selByPage[1] == flat
                                        ) {
                                            selectRow(page: 1, row: flat, fireIfSelected: {
                                                openDetail(t)
                                            })
                                        }
                                        .heroSpot(id: "m2-p1-item-\(t.id.uuidString)")   // C3：d2 编辑生长源（月视图）
                                        .measureFocus(FocusKey(page: 1, row: flat), space: "pageSpace")
                                        .enterArrive(arrived: arrived, index: offsets[gi] + ti + 2)
                                    }
                                }
                            }
                        }

                        contentBottomAnchor(page: 1)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                .mask(bottomFade(active: hasMore(page: 1)))
            }

            FocusCard(frame: focusFrame(pageIdx: 1) ?? .zero,
                      visible: focusVisible(pageIdx: 1), color: DSToken.m2)
                .scaleEffect(page == 1 && focusPulse ? 1.016 : 1)
        }
        .padding(.horizontal, 12)
        .frame(width: width, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .coordinateSpace(name: "pageSpace")
    }

    /// B2a：内容尾锚——上报本页内容底部 maxY（pageSpace 坐标）
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

    // MARK: 手势（B2a：垂直拖动交 ScrollView 滚动，pager 只管水平切组）
    // 垂直意图不锁轴（ScrollView 消费）；水平 8pt 判定后锁定切组；越界 bump 回弹。

    /// B5a：拖动会话 @GestureState——被 ScrollView 抢占时系统自动归零
    /// （旧 @State 手动复位依赖 onEnded；垂直滚动抢占时 onEnded 不回调 → 画布卡在半途）
    @GestureState private var session = PagerSession()

    private func pagerDrag(clipW: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($session) { v, state, _ in
                // 垂直意图（|dy| ≥ |dx| 且显著）→ 不锁定，ScrollView 滚动
                if state.mode == .idle {
                    guard abs(v.translation.width) > 8,
                          abs(v.translation.width) > abs(v.translation.height) else { return }
                    state.mode = .page
                }
                state.offset = v.translation
            }
            .onEnded { v in
                // 依末帧位移判定（不依赖已复位的会话状态）：水平才落页
                let dx = v.translation.width, dy = v.translation.height
                guard abs(dx) > 8, abs(dx) > abs(dy) else { return }
                let result = PagerLogic.settlePage(
                    dragX: dx, width: clipW,
                    fastNext: v.predictedEndLocation.x < v.location.x - 60,
                    fastPrev: v.predictedEndLocation.x > v.location.x + 60,
                    page: page, pageCount: 2
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
        if selByPage[0] > todayList.count { selByPage[0] = todayList.count }
        if selByPage[1] > monthList.count - 1 { selByPage[1] = max(monthList.count - 1, -1) }
    }

    // MARK: 首次 seed（原型 6 条演示想法 + 1 条草稿 · 相对今天生成：3 今日 + 3 本月归档）

    private func seedIfNeeded() {
        // DEBUG 后门：-m2-seed-many 今日灌 12 条（模拟器验证滚动 + 超出渐隐链路）
        if CommandLine.arguments.contains("-m2-seed-many") {
            let flag = "m2.seededMany"
            guard !UserDefaults.standard.bool(forKey: flag) else { return }
            UserDefaults.standard.set(true, forKey: flag)
            guard thoughts.count < 8 else { return }   // 用户已有真实数据则不再灌
            let now = Date()
            let today0 = M2Store.today0(now)
            let moods = M2Store.moods
            for i in 0..<12 {
                let t = Calendar.current.date(byAdding: .minute, value: -(i * 47 + 8), to: now) ?? now
                modelContext.insert(Thought(
                    text: "验证条目 \(i + 1)：这条用来测试列表超出后的滚动与底部渐隐展示样式。",
                    mood: moods[i % moods.count], date: today0, time: t
                ))
            }
            return
        }
        let flag = "m2.seeded"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(true, forKey: flag)
        guard thoughts.isEmpty else { return }
        let cal = Calendar.current
        let now = Date()
        let today0 = M2Store.today0(now)
        func daysAgo(_ n: Int, hour: Int, minute: Int) -> (Date, Date) {
            let d = cal.date(byAdding: .day, value: -n, to: today0) ?? today0
            var comps = cal.dateComponents([.year, .month, .day], from: d)
            comps.hour = hour; comps.minute = minute
            let t = cal.date(from: comps) ?? now
            return (M2Store.today0(t), t)
        }
        let seeds: [(Int, Int, Int, String, String)] = [
            // (几天前, 时, 分, 正文, 心情) —— 今日 3 条
            (0, 21, 32, "闹钟响第三遍的时候，宝宝先笑了，忽然就不困了。", "雀跃"),
            (0, 8, 12, "通勤路上想到：我看看 App 的水滴转场，可以把涟漪留下来。", "心动"),
            (0, 7, 5, "「重要的不是看什么，而是和谁看。」", "平静"),
            // 本月归档 3 条
            (2, 22, 10, "需求五轮讨论全部落档，节奏刚好。", "平静"),
            (6, 19, 40, "宝宝第一次自己扶站，稳稳的 7 秒。", "雀跃"),
            (13, 21, 5, "十月的小目标：把待机屏做成安静的罗盘。", "心动"),
        ]
        for (n, h, m, text, mood) in seeds {
            let (date, time) = daysAgo(n, hour: h, minute: m)
            modelContext.insert(Thought(text: text, mood: mood, date: date, time: time))
        }
        // R8 演示草稿 1 条（记录卡副标「有草稿 1 条 · 上次今天」）
        modelContext.insert(Draft(
            text: "想写一篇关于「把家务变成共同游戏」的随笔，先记几个点：把收玩具说成「救援任务」、把洗碗变成「餐厅打烊」。",
            mood: "心动", date: today0, time: daysAgo(0, hour: 20, minute: 5).1
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

// MARK: - 焦点几何上报（页本地坐标系）

private struct M2FocusPreferenceKey: PreferenceKey {
    static var defaultValue: [M2Screen.FocusKey: CGRect] = [:]
    static func reduce(value: inout [M2Screen.FocusKey: CGRect], nextValue: () -> [M2Screen.FocusKey: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// M2 条目行上报自身 frame（页本地），驱动浮动焦点卡定位
    func measureFocus(_ key: M2Screen.FocusKey, space: String) -> some View {
        background(
            GeometryReader { g in
                Color.clear.preference(
                    key: M2FocusPreferenceKey.self,
                    value: [key: g.frame(in: .named(space))]
                )
            }
        )
    }
}
