import SwiftUI
import SwiftData

// MARK: - M2 视图组件（原型 .compose-card / .th / .month-nav / .draft-card / d2 / d9 转录）

// MARK: p0 · 记录一条（原型 .compose-card：✎ 色块 + 标题 + 草稿副标 R8 ③ + ›）

struct M2ComposeCard: View {
    let subtitle: String          // 草稿实算副标（M2Store.composeSubtitle）
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("✎")
                .font(DSToken.body(17))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(DSToken.m2)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("记录一条")
                    .font(DSToken.body(16, weight: .semibold))
                    .foregroundStyle(DSToken.ink)
                Text(subtitle)
                    .font(DSToken.body(11.5))
                    .foregroundStyle(DSToken.ink2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("›")
                .font(DSToken.body(17))
                .foregroundStyle(selected ? DSToken.m2 : DSToken.ink3)
                .offset(x: selected ? 3 : 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 21)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 白 95% 底叠模块色 5% 微染 + 1.5 虚线模块色 50% 描边
        .background(
            RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                .fill(DSToken.m2.opacity(0.05))
                .background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                .strokeBorder(
                    selected ? DSToken.m2.opacity(0.55) : DSToken.m2.opacity(0.50),
                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        .onTapGesture { onTap() }
    }
}

// MARK: p0/p1 · 想法行（原型 .th：时间列 + 正文 + 心情胶囊 + 尾点）

struct M2ThoughtRow: View {
    /// 时间列文本（p0 = "HH:mm" · p1 = "MM-dd"）
    let leading: String
    let text: String
    let mood: String
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(leading)
                .font(DSToken.num(12, weight: .semibold))
                .foregroundStyle(DSToken.ink2)
                .frame(minWidth: 39, alignment: .leading)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 0) {
                Text(text)
                    .font(DSToken.body(15))
                    .foregroundStyle(DSToken.ink)
                    .lineSpacing(7)                       // line-height 1.45
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(mood)
                    .font(DSToken.body(11, weight: .semibold))
                    .foregroundStyle(DSToken.m2)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(DSToken.m2.opacity(0.10)))
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Circle()
                .fill(DSToken.m2)
                .frame(width: 7, height: 7)
                .opacity(0.5)
                .padding(.top, 7)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(
            tint: selected ? DSToken.m2 : nil,
            borderColor: selected ? DSToken.m2.opacity(0.55) : Color.white.opacity(0.95)
        )
        .contentShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        .onTapGesture { onTap() }
    }
}

// MARK: p1 · 月导航（B2c：固定不随列表滚动；白玻璃 + 模块色边缘柔光，四周留白防切边）

struct M2MonthNav: View {
    let year: Int
    let month: Int
    let onPrev: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 左箭头（圆形白钮 + 模块色箭头）
            Button(action: onPrev) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DSToken.m2)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white.opacity(0.9)))
                    .overlay(Circle().strokeBorder(DSToken.m2.opacity(0.30), lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 4)
            VStack(spacing: 1) {
                Text(M2Store.monthLabel(year: year, month: month))
                    .font(DSToken.body(15, weight: .semibold))
                    .foregroundStyle(DSToken.ink)
            }
            Spacer(minLength: 4)
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DSToken.m2)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white.opacity(0.9)))
                    .overlay(Circle().strokeBorder(DSToken.m2.opacity(0.30), lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        // B2c：白玻璃面 + 白描边 + 模块色边缘柔光（radius 10 光晕，四周留白防裁切）
        .background(
            // 性能优化（完善轮）：去 ultraThinMaterial——底为平滑渐变，模糊=恒等运算；
            // 列表滚动时实时 blur 合成是掉帧主因，白渐变 0.94/0.72 覆盖率高视觉无差。
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.white.opacity(0.94), .white.opacity(0.72)]),
                        startPoint: .init(x: 0.5, y: 0), endPoint: .init(x: 0.44, y: 1)
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.92), lineWidth: 1)
        )
        // 边缘发光：模块色柔光 + 轻贴地影（半径 ≤ 10，外部留白 14 以上 → 不切边）
        .shadow(color: DSToken.m2.opacity(0.18), radius: 10, y: 5)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }
}

// MARK: p1 · 时间轴（B2b：左侧竖线 + 节点 · 日期分组头 · 短宽卡片）
// 行自带整高竖线（行间距 0 → 线连续贯穿）；首行线从卡片顶开始（上方无裸露）；
// 末行线延伸到底部空隙（可接受，验收后再微调尾端收线）。

struct M2TimelineHeader: View {
    /// 日期分组标题（「10月12日」）
    let title: String
    /// 需求②：折叠状态（true = 收起该日全部条目）
    var collapsed: Bool = false
    /// 需求②：点击日期行折叠/展开
    var onToggle: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            // 需求②：日期左侧收起 icon（展开 ⌄ / 收起 ›），随折叠态切换
            Text(collapsed ? "›" : "⌄")
                .font(DSToken.body(13, weight: .bold))
                .foregroundStyle(DSToken.ink2)
                .frame(width: 16)
            Text(title)
                .font(DSToken.body(13, weight: .semibold))
                .foregroundStyle(DSToken.ink)
            Rectangle()
                .fill(DSToken.line)
                .frame(height: 1)
        }
        .padding(.leading, 4)   // 4 + icon 16 + spacing 10 = 30：日期文字起始位与原版对齐
        .padding(.trailing, 8)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .contentShape(Rectangle())   // 分隔线区域也可点
        .onTapGesture { onToggle?() }
    }
}

struct M2TimelineRow: View {
    /// 时刻 HH:mm
    let time: String
    let text: String
    let mood: String
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // 轴列：整高竖线 + 节点圆（白底模块色描边，卡片头部水平位）
            ZStack {
                Rectangle()
                    .fill(DSToken.m2.opacity(0.22))
                    .frame(width: 2)
                Circle()
                    .fill(.white)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(selected ? DSToken.m2 : DSToken.m2.opacity(0.55), lineWidth: 1.6))
                    .shadow(color: DSToken.m2.opacity(0.35), radius: 2)
                    .padding(.top, 9)
            }
            .frame(width: 24)
            .frame(maxHeight: .infinity)

            // 短宽卡片（右侧留白 → 短于页宽；正文 2 行截断不溢）
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(time)
                        .font(DSToken.num(11, weight: .semibold))
                        .foregroundStyle(DSToken.ink2)
                    Spacer(minLength: 0)
                    Text(mood)
                        .font(DSToken.body(10.5, weight: .semibold))
                        .foregroundStyle(DSToken.m2)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(DSToken.m2.opacity(0.10)))
                }
                Text(text)
                    .font(DSToken.body(14))
                    .foregroundStyle(DSToken.ink)
                    .lineSpacing(6)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.white.opacity(0.94), .white.opacity(0.72)]),
                    startPoint: .init(x: 0.5, y: 0), endPoint: .init(x: 0.44, y: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(
                        selected ? DSToken.m2.opacity(0.55) : Color.white.opacity(0.95),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(DSToken.m2)
                    .frame(width: 3)
                    .padding(.vertical, 11)
                    .opacity(selected ? 0.9 : 0)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.04), radius: 8, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .onTapGesture { onTap() }
            .padding(.leading, 13)
            .padding(.trailing, 18)
            .padding(.bottom, 12)      // 行间距（竖线随之贯穿）
        }
    }
}

// MARK: 空态文案（原型 .chips-empty / .draft-empty）

struct M2EmptyText: View {
    let text: String            // 支持 \n 双行
    var body: some View {
        Text(text)
            .font(DSToken.body(11.5))
            .foregroundStyle(DSToken.ink3)
            .multilineTextAlignment(.center)
            .lineSpacing(6)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
    }
}

// MARK: d2 · 草稿卡（原型 .draft-card：− 删除钮 + 两行截断 + 心情/时间 + ›）

struct M2DraftCard: View {
    let draft: Draft
    let onDelete: () -> Void
    let onContinue: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onDelete) {
                Text("−")
                    .font(DSToken.body(15, weight: .semibold))
                    .foregroundStyle(DSToken.bad)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(DSToken.bad.opacity(0.8), lineWidth: 1.5))
                    .contentShape(Circle().inset(by: -7))
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 7) {
                Text(draft.text)
                    .font(DSToken.body(14))
                    .foregroundStyle(DSToken.ink)
                    .lineSpacing(7)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    Text(draft.mood)
                        .font(DSToken.body(10.5, weight: .semibold))
                        .foregroundStyle(DSToken.m2)
                    Text("\(ThoughtFormat.mmdd(draft.date)) \(ThoughtFormat.hhmm(draft.time))")
                        .font(DSToken.num(10.5, weight: .medium))
                        .foregroundStyle(DSToken.ink3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("›")
                .font(DSToken.body(17))
                .foregroundStyle(DSToken.ink3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass()
        .contentShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        .onTapGesture { onContinue() }
    }
}

// MARK: d2 · 心情 chips（原型 .moods：胶囊单选，on = 模块色）

private struct M2MoodChips: View {
    @Binding var mood: String

    var body: some View {
        HStack(spacing: 9) {
            ForEach(M2Store.moods, id: \.self) { m in
                let on = m == mood
                Text(m)
                    .font(DSToken.body(13, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? DSToken.m2 : DSToken.ink2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            Capsule().fill(Color.white.opacity(0.82))
                            if on { Capsule().fill(DSToken.m2.opacity(0.09)) }
                        }
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            on ? DSToken.m2.opacity(0.55) : DSToken.line,
                            lineWidth: 1
                        )
                    )
                    .contentShape(Capsule())
                    .onTapGesture { mood = m }
            }
        }
    }
}

// MARK: d2 · 记录一条 / 草稿箱（V0.4.3 双子页 · R8 草稿三件套核心页）
// ① 自动落盘：textarea 每字变更 → saveDraft 实时写 Draft（同内容不动 / 清空删除 / 否则更新）
// ② 切走不打断：无确认弹窗，静默存盘（sheet 下滑关闭数据已在库）
// ③ 标记看得见：草稿计数行「✎ 已自动存草稿 · N 条」
// V0.4.5：编辑态不落草稿（编辑是就地修改，无「未写完」中间态）

// MARK: - d2 · 记录一条/草稿箱（C3 · 原型 #scr-d2 · hero 卡片生长页）
// B2 sheet 升级 hero：由记录卡/想法行生长打开，原路收回；草稿三件套（自动落盘/续写/发布出栈）不变。

struct M2ComposePage: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Draft.createdAt, order: .reverse)]) private var drafts: [Draft]

    /// 编辑目标（nil = 新建，回填当前草稿）
    let editing: Thought?
    /// 完成/保存回调（toast 文案回传一级；父级随后收回 hero）
    let onDone: (String) -> Void
    /// 返回取消（父级收回 hero；已落盘草稿不丢）
    let onCancel: () -> Void

    @State private var text = ""
    @State private var mood = M2Store.defaultMood
    @State private var pane = 0                     // 0 记录一条 / 1 草稿箱（原型 d2Pane）
    @State private var loadingDraft = false         // 草稿回填静默位（programmatic 赋值不触发落盘比对）
    @State private var currentDraftId: UUID?        // 当前写作态草稿（nil = drafts 首条；点草稿续写时指向它）
    @State private var toast: String? = nil
    @FocusState private var focused: Bool

    private var isEditing: Bool { editing != nil }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // 编辑态提示（原型 d2-mode：「正在编辑 · 保存后覆盖原句」）
                if isEditing {
                    Text("正在编辑 · 保存后覆盖原句")
                        .font(DSToken.body(12, weight: .semibold))
                        .foregroundStyle(DSToken.m2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 10)
                }
                // d2-tabs 双子页
                HStack(spacing: 8) {
                    tabButton(title: "记录一条", idx: 0)
                    tabButton(title: "草稿箱", idx: 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)

                if pane == 0 { writePane } else { draftsPane }
            }
            .padding(.horizontal, 26)
            .padding(.top, 120)   // 返回按钮（46+54）之下留 20 呼吸再起排
            .padding(.bottom, 28)

            // 返回按钮压在最上层（ZStack 后写 = 上层），防被内容拦截
            HeroBackButton(title: "今天的想法", color: DSToken.m2) { onCancel() }
        }
        .overlay(alignment: .bottom) {
            if let t = toast {
                ModuleToast(text: t, color: DSToken.m2)
                    .padding(.bottom, 20)
                    .allowsHitTesting(false)
            }
        }
        .onAppear { bootstrap() }
        .onChange(of: text) { _, _ in saveDraft() }
        .onChange(of: mood) { _, _ in saveDraft() }
    }

    // MARK: 写作页（textarea + 心情 + 收下这句 + 草稿计数）

    private var writePane: some View {
        // 原型 .d2-pane.on：textarea flex:1 撑满剩余（不嵌套外层滚动，避免手势冲突）
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(DSToken.body(18.5))
                .foregroundStyle(DSToken.ink)
                .lineSpacing(11)                          // line-height 1.75
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 20)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(
                    RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.05), radius: 12, y: 8)
                )
                .overlay(alignment: .topLeading) {
                    // 占位文案（TextEditor 原生无 placeholder）
                    if text.isEmpty {
                        Text("今天想对自己说点什么…\n随手写，写一半也没关系")
                            .font(DSToken.body(18.5))
                            .foregroundStyle(DSToken.ink3)
                            .padding(.horizontal, 25)
                            .padding(.vertical, 30)
                            .allowsHitTesting(false)
                    }
                }
                .focused($focused)
                .clipShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))

            M2MoodChips(mood: $mood)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 17)

            // primary-btn：收下这句（模块色 150° 渐变白字胶囊卡）
            Button(action: publish) {
                Text("收下这句")
                    .font(DSToken.body(16.5, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                DSToken.m2.mixedWhite(0.25),
                                DSToken.m2
                            ]),
                            startPoint: UnitPoint(x: 0.5, y: 0), endPoint: UnitPoint(x: 0.35, y: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
                    )
                    .shadow(color: DSToken.m2.opacity(0.32), radius: 12, y: 12)
            }
            .buttonStyle(.plain)
            .padding(.top, 17)

            // R8 ③：草稿计数看得见
            if !isEditing {
                HStack(spacing: 6) {
                    Text("✎")
                        .font(DSToken.body(11))
                    Text("已自动存草稿 ·")
                        .font(DSToken.body(11))
                    Text("\(drafts.count)")
                        .font(DSToken.num(11, weight: .semibold))
                        .foregroundStyle(DSToken.m2)
                    Text("条")
                        .font(DSToken.body(11))
                }
                .foregroundStyle(DSToken.ink3)
                .padding(.top, 9)
            }
        }
    }

    // MARK: 草稿箱页

    private var draftsPane: some View {
        ScrollView {
            VStack(spacing: 12) {
                if drafts.isEmpty {
                    M2EmptyText(text: "没有未写完的\n想到什么都可以随时记下来")
                } else {
                    ForEach(drafts) { d in
                        M2DraftCard(
                            draft: d,
                            onDelete: { remove(d) },
                            onContinue: { continueWriting(d) }
                        )
                    }
                    HStack(spacing: 6) {
                        Text("✎")
                        Text("草稿永久保留 · 直到你发布或删除")
                    }
                    .font(DSToken.body(11))
                    .foregroundStyle(DSToken.ink3)
                    .padding(.top, 9)
                }
            }
            .padding(.top, 2)
            .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func tabButton(title: String, idx: Int) -> some View {
        let on = pane == idx
        return Button {
            withAnimation(DSToken.pageSwitch) { pane = idx }
        } label: {
            Text(title)
                .font(DSToken.body(13, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? DSToken.m2 : DSToken.ink2)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        Capsule().fill(Color.white.opacity(0.82))
                        if on { Capsule().fill(DSToken.m2.opacity(0.09)) }
                    }
                )
                .overlay(
                    Capsule().strokeBorder(
                        on ? DSToken.m2.opacity(0.55) : DSToken.line,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: 进入回填（V0.4.3 ⑤：每次进入回到「记录一条」并回填草稿 = 当前写作态）

    private func bootstrap() {
        pane = 0
        if let editing {
            // 编辑态：回填原文与心情（不落草稿）
            loadingDraft = true
            text = editing.text
            mood = editing.mood
            currentDraftId = nil
        } else if let first = drafts.first {
            // 新建态：草稿即当前写作态，续写
            loadingDraft = true
            text = first.text
            mood = first.mood
            currentDraftId = first.id
            focused = false
        } else {
            focused = true
        }
    }

    // MARK: R8 ① 自动落盘（textarea 每字变更）

    private func saveDraft() {
        guard !loadingDraft else { return }          // 回填/续写回填静默
        guard !isEditing else { return }             // V0.4.5：编辑态不落草稿
        let target = drafts.first(where: { $0.id == currentDraftId }) ?? drafts.first
        switch M2Store.draftDecision(
            currentText: text, latestDraftText: target?.text, latestDraftMood: target?.mood,
            mood: mood, date: M2Store.today0(Date()), time: Date()
        ) {
        case .none:
            break
        case .clear:
            if let target {
                modelContext.delete(target)
                if currentDraftId == target.id { currentDraftId = nil }
            }
        case .upsert(let t, let m, let d, let tm):
            if let target {
                target.text = t; target.mood = m; target.date = d; target.time = tm
            } else {
                let d0 = Draft(text: t, mood: m, date: d, time: tm)
                modelContext.insert(d0)
                currentDraftId = d0.id
            }
        }
    }

    // MARK: 草稿箱动作

    /// 点草稿 → 回记录页继续写（复用同一 textarea，保持写作态连续）
    private func continueWriting(_ d: Draft) {
        loadingDraft = true
        text = d.text
        mood = d.mood
        currentDraftId = d.id
        withAnimation(DSToken.pageSwitch) { pane = 0 }
    }

    private func remove(_ d: Draft) {
        if currentDraftId == d.id { currentDraftId = nil }
        withAnimation(DSToken.spring) { modelContext.delete(d) }
    }

    // MARK: 发布（收下这句 / 编辑保存）

    private func publish() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch M2Store.publishDecision(text: text, isEditing: isEditing) {
        case .empty:
            showToast("先写点什么吧 · 空句子收下了")
        case .create:
            let now = Date()
            modelContext.insert(Thought(text: trimmed, mood: mood,
                                        date: M2Store.today0(now), time: now))
            // 发布后草稿出栈（当前写作草稿删除，text 已清 = 落盘 clear 分支前置执行）
            let target = drafts.first(where: { $0.id == currentDraftId }) ?? drafts.first
            if let target { modelContext.delete(target) }
            currentDraftId = nil
            onDone("已收下这句 ✦ 草稿箱里已经没有它了")
        case .update:
            if let editing {
                editing.text = trimmed
                editing.mood = mood
                editing.time = Date()
            }
            onDone("已保存修改")
        }
    }

    private func showToast(_ t: String) {
        withAnimation(DSToken.bounce) { toast = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(DSToken.spring) { if toast == t { toast = nil } }
        }
    }
}

// MARK: - d9 · 想法详情（C4 · 原型 #scr-d9 · hero 卡片生长页）
// 日期大标题 + 心情胶囊/时刻 + 全文（1.85 行距）+ 底部编辑/删除双按钮。
// 编辑 → 切 d2 编辑态（保存后回详情刷新，V0.4.5 闭环）；删除 → 原路收回 + toast。

struct M2DetailPage: View {
    let thought: Thought
    let onBack: () -> Void
    let onEdit: () -> Void
    /// 删除（预览文案回传；父级 toast + 收回后延迟删库，防已删模型被渲染）
    let onDelete: (String) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(ThoughtFormat.mmdd(thought.date))
                            .font(DSToken.body(27, weight: .bold))
                            .foregroundStyle(DSToken.ink)
                            .padding(.top, 120)
                        HStack(spacing: 9) {
                            Text(thought.mood)
                                .font(DSToken.body(11.5, weight: .semibold))
                                .foregroundStyle(DSToken.m2)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(DSToken.m2.opacity(0.10)))
                            Text(ThoughtFormat.hhmm(thought.time))
                                .font(DSToken.num(11.5, weight: .medium))
                                .foregroundStyle(DSToken.ink2)
                        }
                        .padding(.top, 14)
                        Text(thought.text)
                            .font(DSToken.body(16.5))
                            .foregroundStyle(DSToken.ink)
                            .lineSpacing(13)              // line-height 1.85
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 22)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)

                // d9-acts：底部双按钮（编辑 / 删除）
                HStack(spacing: 11) {
                    actButton(title: "编辑", fg: DSToken.ink, border: DSToken.line, action: onEdit)
                    actButton(title: "删除", fg: DSToken.bad, border: DSToken.bad.opacity(0.38)) {
                        onDelete(String(thought.text.prefix(12)))
                    }
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 28)

            // 返回按钮压在 ScrollView 之上（ZStack 后写 = 上层），防被全屏 ScrollView 拦截
            HeroBackButton(title: "今天的想法", color: DSToken.m2) { onBack() }
        }
    }

    /// d9-acts 按钮（原型 .ghost-btn：白卡描边 · 删除红字红边）
    private func actButton(title: String, fg: Color, border: Color,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DSToken.body(16, weight: .semibold))
                .foregroundStyle(fg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                        .fill(.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                        .strokeBorder(border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: 渐变亮端混白辅助（原型 color-mix(in srgb, var(--mc) 75%, #fff)）

private extension Color {
    func mixedWhite(_ amount: Double = 0.25) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: r + (1 - r) * amount,
                     green: g + (1 - g) * amount,
                     blue: b + (1 - b) * amount)
    }
}
