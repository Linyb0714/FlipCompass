import SwiftUI
import SwiftData

// MARK: - M4 益智小游戏 · 一级模块屏（B4）
// 三分组画布 pager：p0 今日（继续游戏 hero + 战绩/连胜双列）/ p1 游戏清单（双列 game-tile）/
// p2 勋章墙（4 枚勋章 + 设置行）。全部统计由 GameProgress 实算（胶囊三星局数/连胜/勋章解锁）。
// 交互沿用定稿骨架：画布平移 28pt 沟槽 · 滚动 + 底部渐隐 · 点击选中焦点卡 ·
// 水平切组 · 单击空白打开焦点 · 双击返回待机。#scr-m4 转录。

struct M4Screen: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\GameProgress.createdAt, order: .reverse)]) private var records: [GameProgress]

    // —— 分组 / 选中状态（三页：0 今日 / 1 清单 / 2 勋章）——
    @State private var page = 0
    @State private var selByPage: [Int] = [0, 0, 0]
    @State private var bumpX: CGFloat = 0
    @State private var arrived = false

    // —— 滚动超出检测（同 M2/M3）——
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

    // MARK: 数据派生（实算）

    private var todayN: Int { M4Store.todayCount(records, today: Date()) }
    private var streak: Int { M4Store.streakDays(records, today: Date()) }
    private var threeStar: Int { M4Store.threeStarCount(records) }
    /// 继续游戏 = 最近一局的游戏（无记录 = 迷宫滚球默认）
    private var continueGame: GameMeta {
        M4Static.games.first { $0.key == records.first?.gameKey } ?? M4Static.games[1]
    }

    private var sel: Int { selByPage.indices.contains(page) ? selByPage[page] : -1 }

    // MARK: 布局

    var body: some View {
        ZStack {
            ModuleBackdrop(module: .m4)

            VStack(spacing: 0) {
                ModuleHeader(
                    module: .m4,
                    subtitle: "今日一局 · 精而不多",
                    chip: M4Store.headline(threeStar: threeStar).text,
                    chipValue: M4Store.headline(threeStar: threeStar).value
                )
                pagerClip
                ModuleDots(count: 3, current: page, color: DSToken.m4)
                NavHint(text: "上下滚动看更多 · 左右滑换分组 · 点击选中")
            }
            .padding(.top, 58)
            .padding(.bottom, 14)
            .padding(.horizontal, 21)

            if let t = toast {
                ModuleToast(text: t.text, color: DSToken.m4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 120)
                    .allowsHitTesting(false)
            }
        }
        .animation(DSToken.bounce, value: toast)
        .contentShape(Rectangle())
        .onTapGesture { handleBlankTap() }
        .onAppear {
            seedIfNeeded()
            withAnimation(DSToken.springSlow) { arrived = true }
            // DEBUG 后门：-m4-page 0/1/2 直达分组（模拟器截图验证）
            if let idx = CommandLine.arguments.firstIndex(of: "-m4-page"),
               let p = CommandLine.arguments.indices.contains(idx + 1) ? Int(CommandLine.arguments[idx + 1]) : nil,
               (0...2).contains(p) {
                page = p
            }
        }
        .onPreferenceChange(ContentBottomKey.self) { contentMaxY = $0 }
        .onChange(of: records.count) { _, _ in clampSelections() }
    }

    // MARK: 空白点击（单击打开焦点 · 双击返回待机）

    @State private var lastBlankTap: Date? = nil
    @State private var blankTapTask: DispatchWorkItem? = nil

    private func handleBlankTap() {
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
        case (0, 0):
            showToast("「\(continueGame.name)」游戏运行页待设计")
        case (0, 1):
            showToast("战绩详情将在 C 阶段开放")
        case (0, 2):
            showToast("连胜详情将在 C 阶段开放")
        case (1, _):
            if M4Static.games.indices.contains(sel) {
                showToast("「\(M4Static.games[sel].name)」统计将在 C 阶段开放")
            }
        case (2, _):
            if sel < M4Static.badges.count {
                let b = M4Static.badges[sel]
                let p = M4Store.badgeProgress(b, records: records, streak: streak)
                showToast(p.cur >= p.need ? "「\(b.name)」已解锁 ✦" : "进度 \(min(p.cur, p.need)) / \(p.need)")
            } else {
                showToast("游戏设置将在 C 阶段开放")
            }
        default:
            break
        }
    }

    // MARK: pager 横向画布（定稿骨架复用）

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

    // MARK: p0 今日（继续游戏 hero + 战绩/连胜双列）

    private func page0(width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: DSToken.sp) {
                    M4GameHero(meta: continueGame, selected: selByPage[0] == 0) {
                        selectRow(page: 0, row: 0, fireIfSelected: {
                            showToast("「\(continueGame.name)」游戏运行页待设计")
                        })
                    }
                    .measureFocus(FocusKey(page: 0, row: 0), space: "pageSpace")
                    .enterArrive(arrived: arrived, index: 0)

                    LazyVGrid(columns: twoColumns, spacing: 14) {
                        M4StatCard(
                            tag: "今日战绩",
                            title: numTitle("今天已玩 ", "\(todayN)", " 局"),
                            sub: M4Store.todayStatSub(todayN),
                            selected: selByPage[0] == 1
                        ) {
                            selectRow(page: 0, row: 1, fireIfSelected: {
                                showToast("战绩详情将在 C 阶段开放")
                            })
                        }
                        .measureFocus(FocusKey(page: 0, row: 1), space: "pageSpace")
                        .enterArrive(arrived: arrived, index: 1)

                        M4StatCard(
                            tag: "连胜",
                            title: numTitle("每日一局 · 已连玩 ", "\(streak)", " 天"),
                            sub: M4Store.streakStatSub(streak),
                            selected: selByPage[0] == 2
                        ) {
                            selectRow(page: 0, row: 2, fireIfSelected: {
                                showToast("连胜详情将在 C 阶段开放")
                            })
                        }
                        .measureFocus(FocusKey(page: 0, row: 2), space: "pageSpace")
                        .enterArrive(arrived: arrived, index: 2)
                    }
                    contentBottomAnchor(page: 0)
                }
                .padding(.vertical, 6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .mask(bottomFade(active: hasMore(page: 0)))

            FocusCard(frame: focusFrame(pageIdx: 0) ?? .zero,
                      visible: focusVisible(pageIdx: 0), color: DSToken.m4)
                .scaleEffect(page == 0 && focusPulse ? 1.016 : 1)
        }
        .padding(.horizontal, 12)
        .frame(width: width, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .coordinateSpace(name: "pageSpace")
    }

    // MARK: p1 游戏清单（双列 game-tile）

    private func page1(width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 14) {
                    LazyVGrid(columns: twoColumns, spacing: 14) {
                        ForEach(Array(M4Static.games.enumerated()), id: \.element.key) { i, g in
                            M4GameTile(meta: g, selected: selByPage[1] == i) {
                                selectRow(page: 1, row: i, fireIfSelected: {
                                    showToast("「\(g.name)」统计将在 C 阶段开放")
                                })
                            }
                            .measureFocus(FocusKey(page: 1, row: i), space: "pageSpace")
                            .enterArrive(arrived: arrived, index: i)
                        }
                    }
                    contentBottomAnchor(page: 1)
                }
                .padding(.vertical, 6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .mask(bottomFade(active: hasMore(page: 1)))

            FocusCard(frame: focusFrame(pageIdx: 1) ?? .zero,
                      visible: focusVisible(pageIdx: 1), color: DSToken.m4)
                .scaleEffect(page == 1 && focusPulse ? 1.016 : 1)
        }
        .padding(.horizontal, 12)
        .frame(width: width, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .coordinateSpace(name: "pageSpace")
    }

    // MARK: p2 勋章墙（4 枚 + encourage + 设置行）

    private func page2(width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 14) {
                    // badge-grid：4 列
                    LazyVGrid(columns: fourColumns, spacing: 14) {
                        ForEach(Array(M4Static.badges.enumerated()), id: \.element.id) { i, b in
                            let on = M4Store.badgeUnlocked(b, records: records, streak: streak)
                            Button {
                                selectRow(page: 2, row: i, fireIfSelected: {
                                    let p = M4Store.badgeProgress(b, records: records, streak: streak)
                                    showToast(p.cur >= p.need ? "「\(b.name)」已解锁 ✦" : "进度 \(min(p.cur, p.need)) / \(p.need)")
                                })
                            } label: {
                                M4Badge(badge: b, unlocked: on, selected: selByPage[2] == i)
                            }
                            .buttonStyle(.plain)
                            .measureFocus(FocusKey(page: 2, row: i), space: "pageSpace")
                            .enterArrive(arrived: arrived, index: i)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 6)

                    Text("「益智小游戏 · 数量不多，耐玩就好」")
                        .font(DSToken.body(12.5))
                        .foregroundStyle(DSToken.ink2)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    // 设置入口（pref-row 同语言）
                    HStack(spacing: 11) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("设置")
                                .font(DSToken.body(14.5, weight: .semibold))
                                .foregroundStyle(DSToken.ink)
                            Text("音效 · 触感 · 数据导出")
                                .font(DSToken.body(12.5))
                                .foregroundStyle(DSToken.ink2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text("›")
                            .font(DSToken.body(17))
                            .foregroundStyle(selByPage[2] == M4Static.badges.count ? DSToken.m4 : DSToken.ink3)
                            .offset(x: selByPage[2] == M4Static.badges.count ? 3 : 0)
                    }
                    .padding(.horizontal, 18)
                    .frame(height: DSToken.hRow)
                    .m4Card(selected: selByPage[2] == M4Static.badges.count)
                    .contentShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
                    .onTapGesture {
                        selectRow(page: 2, row: M4Static.badges.count, fireIfSelected: {
                            showToast("游戏设置将在 C 阶段开放")
                        })
                    }
                    .measureFocus(FocusKey(page: 2, row: M4Static.badges.count), space: "pageSpace")
                    .enterArrive(arrived: arrived, index: M4Static.badges.count)

                    contentBottomAnchor(page: 2)
                }
                .padding(.vertical, 6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .mask(bottomFade(active: hasMore(page: 2)))

            FocusCard(frame: focusFrame(pageIdx: 2) ?? .zero,
                      visible: focusVisible(pageIdx: 2), color: DSToken.m4)
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

    private var fourColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)
    }

    /// 统计卡主行：前缀 + 数字（SF Rounded 模块色）+ 后缀
    private func numTitle(_ pre: String, _ n: String, _ suf: String) -> AttributedString {
        var s = AttributedString(pre)
        var num = AttributedString(n)
        num.font = DSToken.num(16, weight: .semibold)
        num.foregroundColor = DSToken.m4
        s.append(num)
        s.append(AttributedString(suf))
        return s
    }

    // MARK: 手势（B5a：@GestureState 会话——被 ScrollView 抢占时系统自动归零，
    // 根治画布卡在半途；垂直交 ScrollView · 水平锁定切组）

    @GestureState private var session = PagerSession()

    private func pagerDrag(clipW: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($session) { v, state, _ in
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
        if selByPage[0] > 2 { selByPage[0] = 2 }
        if selByPage[1] > M4Static.games.count - 1 { selByPage[1] = M4Static.games.count - 1 }
        if selByPage[2] > M4Static.badges.count { selByPage[2] = M4Static.badges.count }
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

    // MARK: 首次 seed（原型 8 局记录 · 相对今天生成：2 今日 + 2 昨天 + 1 前天 + 3 更早）

    private func seedIfNeeded() {
        let flag = "m4.seeded"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(true, forKey: flag)
        guard records.isEmpty else { return }
        let cal = Calendar.current
        let now = Date()
        let today0 = M4Store.startOfDay(now)
        func rec(_ daysAgo: Int, hour: Int, minute: Int) -> Date {
            let d = cal.date(byAdding: .day, value: -daysAgo, to: today0) ?? today0
            var c = cal.dateComponents([.year, .month, .day], from: d)
            c.hour = hour; c.minute = minute
            return cal.date(from: c) ?? now
        }
        // (gameKey, daysAgo, 时, 分, score, stars)
        let seeds: [(String, Int, Int, Int, String, Int)] = [
            ("hrd",   0, 14, 25, "84 步", 3),
            ("maze",  0, 9,  10, "58s",   3),
            ("one",   1, 21, 40, "1 笔",  2),
            ("hrd",   1, 20,  5, "96 步", 2),
            ("g2048", 2, 22, 15, "1024",  1),
            ("maze",  3, 19, 30, "71s",   2),
            ("hrd",   4, 21,  0, "108 步", 2),
            ("one",   5, 20, 45, "2 笔",  1),
        ]
        for (key, ago, h, m, score, stars) in seeds {
            let t = rec(ago, hour: h, minute: m)
            modelContext.insert(GameProgress(
                gameKey: key, day: M4Store.startOfDay(t), playedAt: t,
                score: score, stars: stars
            ))
        }
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

// MARK: - 焦点几何上报（页本地坐标系，M4 专用）

private struct M4FocusPreferenceKey: PreferenceKey {
    static var defaultValue: [M4Screen.FocusKey: CGRect] = [:]
    static func reduce(value: inout [M4Screen.FocusKey: CGRect], nextValue: () -> [M4Screen.FocusKey: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// M4 卡片上报自身 frame（页本地），驱动浮动焦点卡定位
    func measureFocus(_ key: M4Screen.FocusKey, space: String) -> some View {
        background(
            GeometryReader { g in
                Color.clear.preference(
                    key: M4FocusPreferenceKey.self,
                    value: [key: g.frame(in: .named(space))]
                )
            }
        )
    }
}
