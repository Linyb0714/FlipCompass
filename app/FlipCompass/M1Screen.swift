import SwiftUI
import SwiftData

// MARK: - M1 温情打卡 · 一级模块屏（B1）
// 三分组 pager：p0 打卡清单 / p1 统计 / p2 条目管理（原型 #scr-m1 结构转录）。
// 手势：左右滑切分组（跟手 + 越界阻尼 + bump）· 上下滑选条目（焦点卡跟手 + 半格吸附）；
// 双击空白返回待机（R7）；✓ 打卡；p2 iOS 删除规则。

/// C1/C2 hero 二级页目标
enum M1HeroTarget {
    case detail(CheckInItem)   // d1 打卡详情
    case formNew              // d3 新建（源卡 = 新建卡）
    case formEdit(CheckInItem) // d3 编辑（源卡 = 条目行）
}

struct M1Screen: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\CheckInItem.sortOrder)]) private var items: [CheckInItem]

    // —— 分组 / 选中状态（原型 st.m1.sel[page]，p1 统计页无焦点 = -1）——
    @State private var page = 0
    @State private var selByPage: [Int] = [0, -1, 0]
    @State private var bumpX: CGFloat = 0
    @State private var bumpY: CGFloat = 0   // B1f：焦点撞顶/底时的垂直回弹（修复左右跳动）
    @State private var arrived = false
    @State private var swipeRow: UUID? = nil     // B1b：swipe 露删除的目标行
    @State private var swipeX: CGFloat = 0       // 行内容左滑偏移（-56 ~ 0）
    // B1i：长按拖动排序
    @State private var sortRowId: UUID? = nil    // 排序中的行
    @State private var sortY: CGFloat = 0       // 拖动偏移（相对当前位）

    // —— C1/C2 hero 生长：二级页会话（d1 详情 / d3 表单）——
    @State private var hero: HeroSession? = nil
    @State private var heroClosing = false
    /// 当前生长目标页（hero 打开时锁定；重建挂载内容据此分支）
    @State private var heroTarget: M1HeroTarget? = nil

    // —— 焦点卡几何（各页行 → 页本地 frame）——
    struct FocusKey: Hashable { let page: Int; let row: Int }
    @State private var focusFrames: [FocusKey: CGRect] = [:]
    @State private var focusPulse = false

    @State private var toast: ToastMsg? = nil

    struct ToastMsg: Identifiable, Equatable {
        let id = UUID()
        let text: String
    }

    // MARK: 数据派生（统计实算）

    private var itemDays: [Set<Date>] { items.map { Set($0.records.map(\.day)) } }

    private var dayCounts: [Date: Int] {
        var d: [Date: Int] = [:]
        for it in items { for r in it.records { d[r.day, default: 0] += 1 } }
        return d
    }

    private var maxStreak: Int {
        CheckInStats.maxStreak(itemDays: itemDays, today: Date())
    }

    private var todayPair: (done: Int, total: Int) {
        CheckInStats.todayCount(itemDays: itemDays, today: Date())
    }

    private var sel: Int { selByPage.indices.contains(page) ? selByPage[page] : -1 }

    /// 当前页可聚焦行数（p0 = 条目数 · p1 = 0 无焦点 · p2 = 新建卡 + 条目行）
    private var focusCount: Int {
        switch page {
        case 0: return items.count
        case 1: return 0
        default: return items.count + 1
        }
    }

    // MARK: 布局

    var body: some View {
        ZStack {
            // C1：hero 覆盖层与源卡上报共用坐标系（无安全区偏差，同 rootSpace 教训）
            ModuleBackdrop(module: .m1)

            VStack(spacing: 0) {
                ModuleHeader(
                    module: .m1,
                    subtitle: "今天也好好抱了抱",
                    chip: "连续 \(maxStreak) 天",
                    chipValue: maxStreak
                )
                pagerClip
                ModuleDots(count: 3, current: page, color: DSToken.m1)
                NavHint(text: "点 ✓ 打卡 · 上下滑选择 · 左右滑换分组")
            }
            .padding(.top, 58)
            .padding(.bottom, 14)
            .padding(.horizontal, 21)

            if let t = toast {
                ModuleToast(text: t.text, color: DSToken.m1)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 120)
                    .allowsHitTesting(false)
            }

            // C1/C2：hero 卡片生长覆盖层（d1 详情 / d3 表单）
            if let h = hero, let target = heroTarget {
                HeroOverlay(
                    session: h,
                    tintColor: DSToken.tintM1,
                    onBack: { heroClosing = true },
                    onClosed: {
                        hero = nil
                        heroClosing = false
                        heroTarget = nil
                        app.exitDetail()   // 红线修复：二级页关闭，恢复翻转导航
                    },
                    closing: heroClosing
                ) {
                    switch target {
                    case .detail(let item):
                        M1DetailPage(item: item, onBack: { heroClosing = true }) { msg in
                            showToast(msg)
                        }
                    case .formNew:
                        M1FormPage(
                            editing: nil,
                            onSave: { title, desc, remind in
                                saveNew(title: title, desc: desc, remind: remind)
                                heroClosing = true   // 保存成功 → 原路收回
                            },
                            onCancel: { heroClosing = true }
                        )
                    case .formEdit(let item):
                        M1FormPage(
                            editing: item,
                            onSave: { title, desc, remind in
                                saveEdit(item, title: title, desc: desc, remind: remind)
                                heroClosing = true
                            },
                            onCancel: { heroClosing = true }
                        )
                    }
                }
            }
        }
        .environment(\.heroSourceID, hero.map(\.sourceID))   // C1：生长中源卡自隐藏
        .coordinateSpace(name: "heroSpace")                   // hero 源卡/覆盖层共用坐标系
        .animation(DSToken.bounce, value: toast)
        .onPreferenceChange(HeroSpotKey.self) { heroSpots = $0 }   // C1：源卡几何收集
        // B1e：空白点击——单击延迟 280ms 打开焦点内容；280ms 内二击 = 双击返回待机（R7）
        .contentShape(Rectangle())
        .onTapGesture { handleBlankTap() }
        .onAppear {
            seedIfNeeded()
            CheckInNotify.sync(items: items)
            withAnimation(DSToken.springSlow) { arrived = true }
            // DEBUG 后门：-m1-page 0/1/2 直达分组（模拟器截图验证）
            if let idx = CommandLine.arguments.firstIndex(of: "-m1-page"),
               let p = CommandLine.arguments.indices.contains(idx + 1) ? Int(CommandLine.arguments[idx + 1]) : nil,
               (0...2).contains(p) {
                page = p
            }
            // DEBUG 后门：-m1-form 直达新建表单（heroSpots 布局稳定后生长）
            if CommandLine.arguments.contains("-m1-form") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { openFormNew() }
            }
        }
        .onChange(of: items.count) { _, _ in
            clampSelections()
            CheckInNotify.sync(items: items)
        }
    }

    // MARK: 空白点击（B1e：单击打开焦点内容 · 280ms 内二击 = 双击返回）

    @State private var lastBlankTap: Date? = nil
    @State private var blankTapTask: DispatchWorkItem? = nil

    private func handleBlankTap() {
        // C1：hero 详情打开时吞掉背景点击——克隆卡圆角外的四角区域会穿透到此，
        // 若不拦截，快速双击会误触 backToIdle、单击会误触 openFocusedRow
        guard hero == nil else {
            lastBlankTap = nil
            blankTapTask?.cancel()
            return
        }
        let now = Date()
        if let last = lastBlankTap, now.timeIntervalSince(last) < 0.28 {
            // 双击：取消待执行的单击任务 → 返回待机
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

    /// 单击空白 = 打开当前焦点内容（选中已定 → 直接触发该行打开动作）
    private func openFocusedRow() {
        guard sel >= 0 else { return }
        if swipeRow != nil {
            withAnimation(DSToken.spring) { swipeX = 0; swipeRow = nil }
            return
        }
        selectRow(page: page, row: sel, fireIfSelected: focusOpenAction)
    }

    /// 焦点行的「打开」动作（与点已选中卡一致）
    private var focusOpenAction: () -> Void {
        switch (page, sel) {
        case (2, 0):
            return { openFormNew() }                  // 新建卡焦点 → hero 生长新建表单
        case (2, _) where sel >= 1:
            return { openDetail(items[sel - 1]) }         // C1：条目行 → hero 生长详情
        case (0, _):
            return { openDetail(items[sel]) }
        default:
            return {}
        }
    }

    // MARK: pager 横向画布（B1i：页间 28pt 沟槽——切组时邻页是独立画布块，不贴边）

    /// 画布间距（沟槽宽度，露出 tint 底色）
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
                .offset(x: pagerOffset(clipW: geo.size.width), y: bumpY)
                // B5a：锁定中 1:1 跟手（nil）；松手/被打断的会话归零以 pageSwitch 平滑回弹
                //（旧实现归零与 page 切换分属两个事务 → 先飞半格再跳一下的卡顿）
                .animation(session.locked ? nil : DSToken.pageSwitch, value: session)
            }
            // clipped 必须挂在 ZStack（bounds = clip 区）——挂 HStack 会裁其 3W 自身 bounds（无效）
            .coordinateSpace(name: "clipSpace")
            .clipped()
            .contentShape(Rectangle())
            .gesture(pagerDrag(clipW: geo.size.width))
        }
    }

    /// 画布偏移：-page*(W+gap) + bump + 跟手（非越界 1:1 / 越界阻尼 0.38）
    private func pagerOffset(clipW: CGFloat) -> CGFloat {
        var x = -CGFloat(page) * (clipW + canvasGap) + bumpX
        if session.mode == .page {
            let base = session.offset.width
            let atEdge = (page == 0 && base > 0) || (page == 2 && base < 0)
            x += atEdge ? base * 0.38 : base
        }
        return x
    }

    // MARK: 焦点卡几何（页内定位，随画布平移）

    private func focusFrame(pageIdx: Int) -> CGRect? {
        guard selByPage.indices.contains(pageIdx) else { return nil }
        let s = selByPage[pageIdx]
        guard s >= 0, let f = focusFrames[FocusKey(page: pageIdx, row: s)] else { return nil }
        return f
    }

    private func focusVisible(pageIdx: Int) -> Bool {
        arrived && sortRowId == nil && focusFrame(pageIdx: pageIdx) != nil
    }

    // MARK: p0 打卡清单

    private func page0(width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: DSToken.sp) {
            if items.isEmpty {
                M1EmptyCard()
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    M1TaskCard(
                        item: item,
                        doneTime: M1Store.doneTime(of: item, today: Date()),
                        selected: selByPage[0] == idx
                    ) {
                        selectRow(page: 0, row: idx, fireIfSelected: { openDetail(item) })
                    } onCheck: {
                        checkIn(item)
                    }
                    .measureFocus(FocusKey(page: 0, row: idx), space: "pageSpace")
                    .heroSpot(id: "m1-p0-item-\(item.id.uuidString)")   // C1 源卡几何（p0 前缀：防跨页合并串位）
                    .enterArrive(arrived: arrived, index: idx)
                }
            }
            }
            // 焦点卡随页内定位（随画布平移一起滑动）
            FocusCard(frame: focusFrame(pageIdx: 0) ?? .zero,
                      visible: focusVisible(pageIdx: 0), color: DSToken.m1)
                .scaleEffect(page == 0 && focusPulse ? 1.016 : 1)
        }
        .padding(.horizontal, 12)
        .frame(width: width, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .coordinateSpace(name: "pageSpace")
    }

    // MARK: p1 统计（近 21 天日历条 + 三格统计 + 热力图 + 鼓励语）

    private func page1(width: CGFloat) -> some View {
        let cells = CheckInStats.strip(dayCounts: dayCounts, total: items.count, today: Date())
        let ratios = CheckInStats.heat(dayCounts: dayCounts, total: items.count, today: Date())
        let week = CheckInStats.weekCount(dayCounts: dayCounts, today: Date())

        return VStack(spacing: DSToken.sp) {
            M1WeekStrip(cells: cells, today: Date(), cal: .current)
            M1StatRow(todayDone: todayPair.done, total: todayPair.total,
                      weekCount: week, streak: maxStreak)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("近十周热力")
                        .font(DSToken.body(13.5, weight: .semibold))
                        .foregroundStyle(DSToken.ink)
                    Spacer()
                    Text("越暖越勤")
                        .font(DSToken.body(12))
                        .foregroundStyle(DSToken.ink2)
                }
                M1HeatGrid(ratios: ratios)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 17)
            .liquidGlass()
            Text(M1Store.encourage(streak: maxStreak))
                .font(DSToken.body(12.5))
                .foregroundStyle(DSToken.ink2)
                .multilineTextAlignment(.center)
                .padding(.vertical, 3)
        }
        .padding(.horizontal, 12)
        .frame(width: width, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    // MARK: p2 条目管理（新建卡 + 管理行 + 提示行）

    private func page2(width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: DSToken.sp) {
            M1NewCard(selected: selByPage[2] == 0) {
                selectRow(page: 2, row: 0, fireIfSelected: { openFormNew() })
            }
            .heroSpot(id: "m1-new-card")   // C2：新建表单的生长源卡
            .measureFocus(FocusKey(page: 2, row: 0), space: "pageSpace")
            .enterArrive(arrived: arrived, index: 0)

            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                M1RowItem(
                    item: item,
                    selected: selByPage[2] == idx + 1,
                    swipeX: swipeRow == item.id ? swipeX : 0,
                    sorting: sortRowId == item.id,
                    onDelete: { delete(item) },
                    onTap: {
                        selectRow(page: 2, row: idx + 1, fireIfSelected: {
                            openDetail(item)
                        })
                    },
                    onEdit: {
                        // C2：行内编辑一步直达 hero 表单（先收回左滑露出，源卡归位再生长）
                        if swipeRow == item.id {
                            withAnimation(DSToken.spring) { swipeX = 0; swipeRow = nil }
                        }
                        openFormEdit(item)
                    },
                    onDragBegin: { axis in
                        if axis == .horizontal { swipeRow = item.id }
                        rowDragBegin(axis)
                    },
                    onDragChange: rowDragChange,
                    onDragEnd: rowDragEnd,
                    onSortBegin: { sortBegin(item) },
                    onSortDrag: { sortDrag(item, dy: $0) },
                    onSortEnd: { sortEnd(item) }
                )
                .offset(y: sortRowId == item.id ? sortY : 0)
                .zIndex(sortRowId == item.id ? 1 : 0)
                .measureFocus(FocusKey(page: 2, row: idx + 1), space: "pageSpace")
                .heroSpot(id: "m1-p2-item-\(item.id.uuidString)")   // C1 源卡几何（p2 前缀）
                .enterArrive(arrived: arrived, index: idx + 1)
            }

            Text(M1Store.manageHint)
                .font(DSToken.body(12))
                .foregroundStyle(DSToken.ink3)
            }
            FocusCard(frame: focusFrame(pageIdx: 2) ?? .zero,
                      visible: focusVisible(pageIdx: 2), color: DSToken.m1)
                .scaleEffect(page == 2 && focusPulse ? 1.016 : 1)
        }
        .padding(.horizontal, 12)
        .frame(width: width, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .coordinateSpace(name: "pageSpace")
    }

    // MARK: 手势（B5a：@GestureState 会话——行内独立手势自处理 swipe/步进转发；pager 手势只管空白区域）

    /// 垂直步进会话基准（pager 与行手势共用；begin 时记录）
    @State private var stepStartSel = 0
    @State private var stepBumpSent = false

    /// B5a：拖动会话改 @GestureState——被行手势/子视图抢占时系统自动归零，
    /// 根治「画布卡在半途」（旧 @State 手动复位依赖 onEnded，被打断时不回调）
    @GestureState private var session = PagerSession()

    private func pagerDrag(clipW: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($session) { v, state, _ in
                if state.mode == .idle {
                    guard abs(v.translation.width) > 8 || abs(v.translation.height) > 8 else { return }
                    if abs(v.translation.width) > abs(v.translation.height) {
                        state.mode = .page
                    } else {
                        state.mode = .vertical
                        beginStepSession()
                    }
                }
                state.offset = v.translation
                if state.mode == .vertical {
                    liveStep(dragY: v.translation.height)
                }
            }
            .onEnded { v in
                // 依末帧位移判定主轴（不依赖已复位的会话状态）
                let dx = v.translation.width, dy = v.translation.height
                let pred = v.predictedEndLocation
                let loc = v.location
                if abs(dx) > 8 && abs(dx) > abs(dy) {
                    // 水平：落页（步长固定——只落在槽位：换页或原位回弹）
                    let result = PagerLogic.settlePage(
                        dragX: dx, width: clipW,
                        fastNext: pred.x < loc.x - 60, fastPrev: pred.x > loc.x + 60,
                        page: page, pageCount: 3
                    )
                    if result.bumped { bump() }
                    withAnimation(DSToken.pageSwitch) { page = result.page }
                } else if abs(dy) > 8 && abs(dy) > abs(dx) {
                    // 垂直：松手快扫补步进
                    endStep(dragY: dy,
                            fastDown: pred.y > loc.y + 60, fastUp: pred.y < loc.y - 60)
                }
                // 其余（微小拖动/点击）不动作；会话由系统自动归零，
                // 归零过程由 canvas 上的 .animation(value: session) 平滑回弹
            }
    }

    // MARK: 垂直步进（pager 空白与行手势共用）

    private func beginStepSession() {
        stepStartSel = max(sel, 0)
        stepBumpSent = false
    }

    /// 拖动中逐行步进：每滑过一行高焦点跳一行（下滑 → 下移，跟手方向）
    private func liveStep(dragY: CGFloat) {
        let rowH = focusFrames[FocusKey(page: page, row: sel)]?.height ?? DSToken.hRow
        let target = PagerLogic.stepSel(
            dragY: dragY, rowHeight: rowH,
            startSel: stepStartSel, count: focusCount
        )
        if selByPage.indices.contains(page), selByPage[page] != target {
            withAnimation(DSToken.springSlow) { selByPage[page] = target }   // B1f：焦点卡明显滑移
        }
        if !stepBumpSent {
            let atLast = target == focusCount - 1 && dragY > DSToken.hRow
            let atFirst = target == 0 && dragY < -DSToken.hRow
            if focusCount == 0 && abs(dragY) > 30 {
                bumpV(direction: dragY > 0 ? 1 : -1); stepBumpSent = true
            } else if atLast {
                bumpV(direction: 1); stepBumpSent = true      // 撞底再下滑 → 页面下弹
            } else if atFirst {
                bumpV(direction: -1); stepBumpSent = true     // 撞顶再上滑 → 页面上弹
            }
        }
    }

    /// 松手快扫补步进（拖动量小但快 → 至少一档；正向 = 下滑）
    private func endStep(dragY: CGFloat, fastDown: Bool, fastUp: Bool) {
        if let next = PagerLogic.flickStep(
            dragY: dragY, fastDown: fastDown, fastUp: fastUp,
            sel: max(sel, 0), startSel: stepStartSel, count: focusCount
        ), selByPage.indices.contains(page) {
            withAnimation(DSToken.springSlow) { selByPage[page] = next }
        }
    }

    // MARK: 行手势转发（B1e：每行独立监听，水平 swipe / 垂直步进——不涉及 tab）

    private func rowDragBegin(_ axis: PagerLogic.Axis) {
        if axis == .vertical { beginStepSession() }
    }

    private func rowDragChange(_ axis: PagerLogic.Axis, _ translation: CGSize) {
        switch axis {
        case .horizontal:
            swipeX = min(0, max(-64, translation.width))
        case .vertical:
            liveStep(dragY: translation.height)
        }
    }

    private func rowDragEnd(_ axis: PagerLogic.Axis, _ translation: CGSize,
                             _ pred: CGPoint, _ loc: CGPoint) {
        switch axis {
        case .horizontal:
            withAnimation(DSToken.spring) {
                swipeX = PagerLogic.settleSwipe(swipeX: swipeX)
                if swipeX == 0 { swipeRow = nil }
            }
        case .vertical:
            endStep(dragY: translation.height,
                    fastDown: pred.y > loc.y + 60, fastUp: pred.y < loc.y - 60)
        }
    }

    private func bump() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        bumpX = 18
        withAnimation(DSToken.bounceQuick) { bumpX = 0 }
    }

    // MARK: 长按拖动排序（B1i：跨行位步进交换 sortOrder，拖动跟手 + 松手落位）

    private func sortBegin(_ item: CheckInItem) {
        guard sortRowId == nil else { return }
        sortRowId = item.id
        sortY = 0
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func sortDrag(_ item: CheckInItem, dy: CGFloat) {
        guard sortRowId == item.id else { return }
        let stride = DSToken.hRow + DSToken.sp     // 行高 + 间隙 = 一个行位
        guard let cur = items.firstIndex(where: { $0.id == item.id }) else { return }
        var y = dy
        var pos = cur
        // 每跨半个行位交换一次（拖动中实时让位）
        while y > stride / 2 && pos < items.count - 1 {
            swapOrder(pos, pos + 1); pos += 1; y -= stride
            UISelectionFeedbackGenerator().selectionChanged()
        }
        while y < -stride / 2 && pos > 0 {
            swapOrder(pos, pos - 1); pos -= 1; y += stride
            UISelectionFeedbackGenerator().selectionChanged()
        }
        sortY = y
    }

    private func sortEnd(_ item: CheckInItem) {
        guard sortRowId == item.id else { return }
        withAnimation(DSToken.spring) {
            sortY = 0
            sortRowId = nil
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func swapOrder(_ a: Int, _ b: Int) {
        guard items.indices.contains(a), items.indices.contains(b) else { return }
        withAnimation(DSToken.spring) {
            let oa = items[a].sortOrder
            items[a].sortOrder = items[b].sortOrder
            items[b].sortOrder = oa
        }
    }

    /// 焦点撞顶/底回弹：页面沿 y 轴小幅跟手再弹回（B1f：修复撞界页面左右跳动的串轴 bug）
    private func bumpV(direction: Int) {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        bumpY = CGFloat(direction) * 10
        withAnimation(DSToken.bounceQuick) { bumpY = 0 }
    }

    // MARK: C1/C2 hero 打开（源卡几何取自 heroSpots 上报；缺几何 fallback 全屏淡入）

    /// 条目/新建卡源卡几何（spotID → 模块屏本地 frame）
    @State private var heroSpots: [String: CGRect] = [:]

    /// 统一生长入口：捕获源卡几何 → 建会话 → 锁定目标页
    private func openHero(key: String, sourceID: String, target: M1HeroTarget) {
        blankTapTask?.cancel()   // 清掉待执行的空白单击（防打开后旧 task 重复 fire）
        app.enterDetail()        // 红线修复：二级页期间屏蔽翻转导航
        hero = HeroSession(
            key: key,
            sourceID: sourceID,
            sourceFrame: heroSpots[sourceID] ?? CGRect(x: 60, y: 300, width: 330, height: 100)
        )
        heroTarget = target
    }

    private func openDetail(_ item: CheckInItem) {
        // 源卡 = 当前分组页内行（page 前缀隔离：p0 今日 / p2 管理两行同 id 不串位）
        openHero(key: "d1", sourceID: "m1-p\(page)-item-\(item.id.uuidString)", target: .detail(item))
    }

    private func openFormNew() {
        openHero(key: "d3", sourceID: "m1-new-card", target: .formNew)
    }

    private func openFormEdit(_ item: CheckInItem) {
        // 编辑入口只在 p2 行内（左滑「编辑 ›」）
        openHero(key: "d3", sourceID: "m1-p2-item-\(item.id.uuidString)", target: .formEdit(item))
    }

    // MARK: 交互路由

    /// 点行：有 swipe 露出 → 先收起不误触；未选中 → 选中（焦点卡脉冲）；
    /// 已选中 → 执行 fireIfSelected（p2 新建卡开表单 / 行卡详情提示）
    private func selectRow(page p: Int, row: Int, fireIfSelected: @escaping () -> Void = {}) {
        if swipeRow != nil {
            withAnimation(DSToken.spring) { swipeX = 0; swipeRow = nil }
            return
        }
        guard selByPage.indices.contains(p) else { return }
        if selByPage[p] == row {
            fireIfSelected()
        } else {
            withAnimation(DSToken.springSlow) { selByPage[p] = row }   // B1f：焦点卡明显滑移
            focusPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { focusPulse = false }
        }
    }

    // MARK: 业务（打卡 / 新建 / 编辑 / 删除）

    private func checkIn(_ item: CheckInItem) {
        let decision = M1Store.checkInDecision(item: item, now: Date())
        guard decision.inserted else {
            showToast("今天已完成 · \(decision.time)")
            return
        }
        // 拓展优化：与详情页打卡同源——随机心情（经典 + 热词彩蛋），主屏打卡也有心情
        let last = CheckInStats.recentRecords(Array(item.records)).first?.mood
        let mood = M1Store.pickMood(previous: last)
        let rec = CheckInRecord(
            day: CheckInStats.startOfDay(Date()),
            time: Date(),
            mood: mood,
            item: item
        )
        modelContext.insert(rec)
        showToast(M1Store.checkInToast(title: item.title, streak: decision.streak, mood: mood))
    }

    private func saveNew(title: String, desc: String, remind: String) {
        let next = (items.map(\.sortOrder).max() ?? -1) + 1
        let item = CheckInItem(title: title, itemDesc: desc, remind: remind, sortOrder: next)
        modelContext.insert(item)
        CheckInNotify.registerItem(item)
        showToast("已新建「\(title)」")   // C2：hero 收回后 toast 回馈（sheet 时代无反馈）
    }

    private func saveEdit(_ item: CheckInItem, title: String, desc: String, remind: String) {
        item.title = title
        item.itemDesc = desc
        item.remind = remind
        CheckInNotify.registerItem(item)
        showToast("已保存「\(title)」")   // C2：hero 收回后 toast 回馈
    }

    private func delete(_ item: CheckInItem) {
        let title = item.title
        CheckInNotify.cancel(itemId: item.id)
        withAnimation(DSToken.spring) { modelContext.delete(item) }
        withAnimation(DSToken.spring) { swipeX = 0; swipeRow = nil }
        showToast("已删除「\(title)」")
    }

    private func clampSelections() {
        if items.isEmpty {
            selByPage[0] = -1
            if selByPage[2] > 0 { selByPage[2] = 0 }
        } else {
            if selByPage[0] >= items.count { selByPage[0] = items.count - 1 }
            if selByPage[2] > items.count { selByPage[2] = items.count }
        }
    }

    // MARK: 首次 seed（原型 4 条演示条目，无打卡记录 · 一次性标记防复活）

    private func seedIfNeeded() {
        let flag = "m1.seeded"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(true, forKey: flag)
        guard items.isEmpty else { return }
        let seeds: [(String, String, String)] = [
            ("抱抱宝宝", "每天一次 · 睡前完成", "21:00"),
            ("拥抱爱人", "进门先抱一下", "19:00"),
            ("给爸妈打个电话", "一分钟也算数", "20:30"),
            ("夸奖家人一次", "具体的、认真的夸", "21:30"),
        ]
        for (i, s) in seeds.enumerated() {
            modelContext.insert(CheckInItem(title: s.0, itemDesc: s.1, remind: s.2, sortOrder: i))
        }
    }

    // MARK: Toast（夜露胶囊 · 2.6s 自动消散）

    private func showToast(_ text: String) {
        withAnimation(DSToken.bounce) { toast = ToastMsg(text: text) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(DSToken.spring) {
                if toast?.text == text { toast = nil }
            }
        }
    }
}

// MARK: - 空清单占位卡（p0 无条目时）

private struct M1EmptyCard: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("还没有打卡项")
                .font(DSToken.body(15, weight: .semibold))
                .foregroundStyle(DSToken.ink2)
            Text("到「条目管理」分组新建一个温情打卡吧")
                .font(DSToken.body(12))
                .foregroundStyle(DSToken.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .liquidGlass()
    }
}

// MARK: - 焦点几何上报（页本地坐标系）+ 入场 stagger

private struct M1FocusPreferenceKey: PreferenceKey {
    static var defaultValue: [M1Screen.FocusKey: CGRect] = [:]
    static func reduce(value: inout [M1Screen.FocusKey: CGRect], nextValue: () -> [M1Screen.FocusKey: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// 条目行上报自身 frame（页本地），驱动浮动焦点卡定位
    func measureFocus(_ key: M1Screen.FocusKey, space: String) -> some View {
        background(
            GeometryReader { g in
                Color.clear.preference(
                    key: M1FocusPreferenceKey.self,
                    value: [key: g.frame(in: .named(space))]
                )
            }
        )
    }

    /// 模块入场 stagger（原型 .screen.arrive：fadeUp · 120ms + i×35ms）
    func enterArrive(arrived: Bool, index: Int) -> some View {
        opacity(arrived ? 1 : 0)
            .offset(y: arrived ? 0 : 14)
            .animation(
                arrived ? DSToken.spring.delay(0.12 + Double(index) * 0.035) : nil,
                value: arrived
            )
    }
}
