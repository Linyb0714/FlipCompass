import SwiftUI

// MARK: - M1 视图组件（原型 .task / .ws-cell / .stat / .heat / .new-card / .row-item 转录）

// MARK: p0 打卡清单 · task 双行卡（原型统一高 78.5）

struct M1TaskCard: View {
    let item: CheckInItem
    let doneTime: String?      // 今日打卡 HH:mm
    let selected: Bool
    let onTap: () -> Void
    let onCheck: () -> Void

    @State private var checkPop = false

    var body: some View {
        HStack(spacing: DSToken.sp) {
            // tcheck：28 圆 · 完成填充模块色 + 白 ✓（tcPop 弹跳由数据驱动）
            ZStack {
                Circle().fill(DSToken.m1).opacity(doneTime != nil ? 1 : 0)
                Circle()
                    .strokeBorder(selected ? DSToken.m1 : DSToken.ink3, lineWidth: 2)
                if doneTime != nil {
                    Text("✓")
                        .font(DSToken.body(15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 28, height: 28)
            .scaleEffect(checkPop ? 1.22 : 1)
            .animation(DSToken.bounceQuick, value: checkPop)
            .contentShape(Circle().inset(by: -6))
            .onTapGesture { onCheck() }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(DSToken.body(16.5, weight: .semibold))
                    .foregroundStyle(doneTime != nil ? DSToken.ink2 : DSToken.ink)
                    .lineLimit(1)
                if !item.itemDesc.isEmpty {
                    Text(item.itemDesc)
                        .font(DSToken.body(12))
                        .foregroundStyle(DSToken.ink2)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let doneTime {
                Text(doneTime)
                    .font(DSToken.num(12, weight: .semibold))
                    .foregroundStyle(DSToken.m1)
            }
            // tk-go：›（选中变模块色 + 右移 3）
            Text("›")
                .font(DSToken.body(17))
                .foregroundStyle(selected ? DSToken.m1 : DSToken.ink3)
                .offset(x: selected ? 3 : 0)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 78.5, alignment: .center)
        .liquidGlass(
            tint: selected ? DSToken.m1 : nil,
            borderColor: selected ? DSToken.m1.opacity(0.55) : Color.white.opacity(0.82)
        )
        .overlay(alignment: .leading) {
            // 选中 accent bar：左侧 4px 模块色竖条（上下 22%）
            Capsule()
                .fill(DSToken.m1)
                .frame(width: 4)
                .padding(.vertical, 17)
                .opacity(selected ? 0.9 : 0)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .allowsHitTesting(false)
        }
        .contentShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        .onTapGesture { onTap() }
    }
}

// MARK: p1 统计 · 近 21 天日历条（.ws-cell：44 宽，周字+日期+完成度点）

struct M1WeekStrip: View {
    let cells: [CheckInStats.DayCell]
    let today: Date
    let cal: Calendar

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { idx, cell in
                        M1WeekCell(cell: cell, cal: cal)
                            .id(idx)
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear {
                // 默认滚到今天（末位），近 21 天时间轴右端 = 今天
                if let last = cells.indices.last {
                    DispatchQueue.main.async {
                        withAnimation { proxy.scrollTo(last, anchor: .trailing) }
                    }
                }
            }
        }
    }

    private struct M1WeekCell: View {
        let cell: CheckInStats.DayCell
        let cal: Calendar

        var body: some View {
            let weekdayNames = ["日", "一", "二", "三", "四", "五", "六"]
            VStack(spacing: 4) {
                Text(cell.isToday ? "今" : weekdayNames[cal.component(.weekday, from: cell.date) - 1])
                    .font(DSToken.body(10))
                    .foregroundStyle(DSToken.ink3)
                Text("\(cal.component(.day, from: cell.date))")
                    .font(DSToken.num(15, weight: .semibold))
                    .foregroundStyle(cell.isToday ? DSToken.m1 : DSToken.ink)
                Circle()
                    .fill(dotFill)
                    .frame(width: 7, height: 7)
                    .overlay(
                        Circle().strokeBorder(
                            cell.state == .miss
                                ? Color(red: 245/255, green: 34/255, blue: 45/255).opacity(0.38)
                                : .clear,
                            lineWidth: 1.5
                        )
                    )
                    .shadow(color: cell.state == .hit ? DSToken.m1.opacity(0.45) : .clear, radius: 3)
            }
            .frame(width: 44)
            .padding(.vertical, 8)
            .liquidGlass(cornerRadius: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(cell.isToday ? DSToken.m1.opacity(0.45) : .clear, lineWidth: 1.5)
            )
        }

        private var dotFill: Color {
            switch cell.state {
            case .hit: return DSToken.m1
            case .miss: return .white
            case .plain: return DSToken.line
            }
        }
    }
}

// MARK: p1 统计 · 三格统计卡（今日 N/M · 本周 · 连续天数）

struct M1StatRow: View {
    let todayDone: Int
    let total: Int
    let weekCount: Int
    let streak: Int

    var body: some View {
        HStack(spacing: DSToken.sp) {
            M1StatCard(value: "\(todayDone)", sub: "/\(total)", label: "今日")
            M1StatCard(value: "\(weekCount)", sub: nil, label: "本周")
            M1StatCard(value: "\(streak)", sub: nil, label: "连续天数")
        }
    }

    private struct M1StatCard: View {
        let value: String
        let sub: String?
        let label: String

        var body: some View {
            VStack(spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(value)
                        .font(DSToken.num(24, weight: .semibold))
                        .foregroundStyle(DSToken.ink)
                    if let sub {
                        Text(sub)
                            .font(DSToken.num(14, weight: .semibold))
                            .foregroundStyle(DSToken.ink2)
                            .padding(.leading, 1)
                    }
                }
                Text(label)
                    .font(DSToken.body(11.5))
                    .foregroundStyle(DSToken.ink2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .liquidGlass()
        }
    }
}

// MARK: p1 统计 · 近十周热力（42 格 · 10 列 · 越暖越勤）

struct M1HeatGrid: View {
    let ratios: [Double]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 10)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 7) {
            ForEach(Array(ratios.enumerated()), id: \.offset) { _, ratio in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DSToken.m1)
                    .opacity(ratio > 0.02 ? max(ratio, 0.12) : 0.1)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}

// MARK: p2 条目管理 · 新建卡（63 高虚线卡）

struct M1NewCard: View {
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Text("＋")
                .font(DSToken.body(16, weight: .semibold))
            Text("新建打卡项")
                .font(DSToken.body(15, weight: .semibold))
        }
        .foregroundStyle(selected ? DSToken.ink : DSToken.ink2)
        .frame(maxWidth: .infinity)
        .frame(height: DSToken.hRow)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.white.opacity(0.55), .white.opacity(0.32)]),
                startPoint: UnitPoint(x: 0.5, y: 0), endPoint: UnitPoint(x: 0.44, y: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                .strokeBorder(
                    selected ? DSToken.m1.opacity(0.55) : Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.32),
                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        .onTapGesture { onTap() }
    }
}

// MARK: 新建/编辑表单（C2 · 原型 #scr-d3 · hero 卡片生长页）
// B1 的 sheet 升级为 hero：由新建卡/条目行生长打开，返回原路收回。
// 标题必填（空值保存禁用）+ 描述可选 + 提醒时间 chips + 保存联动（通知重注册）。

struct M1FormPage: View {
    /// 编辑目标（nil = 新建）
    let editing: CheckInItem?
    let onSave: (_ title: String, _ desc: String, _ remind: String) -> Void
    let onCancel: () -> Void

    @State private var title = ""
    @State private var desc = ""
    @State private var remind = ""
    @FocusState private var titleFocused: Bool

    static let remindOptions = ["", "19:00", "20:00", "20:30", "21:00", "21:30"]

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    Text(editing == nil ? "新建打卡项" : "编辑打卡项")
                        .font(DSToken.body(27, weight: .bold))
                        .foregroundStyle(DSToken.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)

                    Text("标题 · 描述 · 提醒时间")
                        .font(DSToken.body(12.5))
                        .foregroundStyle(DSToken.ink2)
                        .padding(.top, 8)

                    fieldLabel("标题", hint: "必填")
                        .padding(.top, 24)
                    TextField("比如：抱抱宝宝", text: $title)
                        .textFieldStyle(.plain)
                        .font(DSToken.body(15.5))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.92))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    titleFocused ? DSToken.m1.opacity(0.55) : DSToken.line,
                                    lineWidth: titleFocused ? 1.5 : 1
                                )
                        )
                        .shadow(color: DSToken.m1.opacity(0.14), radius: titleFocused ? 3 : 0)
                        .focused($titleFocused)

                    fieldLabel("描述", hint: "一句话，可留空")
                        .padding(.top, 13)
                    TextField("比如：每天一次 · 睡前完成", text: $desc)
                        .textFieldStyle(.plain)
                        .font(DSToken.body(15.5))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.92))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(DSToken.line, lineWidth: 1)
                        )

                    fieldLabel("提醒时间", hint: "首页遗漏提醒 · 真机本地通知")
                        .padding(.top, 13)
                    FlowChips(options: Self.remindOptions, selected: $remind) {
                        titleFocused = false   // 点 chips 收键盘
                    }
                        .padding(.top, 6)

                    saveButton
                        .padding(.top, 18)

                    HStack(spacing: 6) {
                        Text("✎")
                        Text("保存后首页与管理页即时生效 · 提醒按所选时间触发")
                    }
                    .font(DSToken.body(11))
                    .foregroundStyle(DSToken.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 9)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            // 返回按钮压在 ScrollView 之上（ZStack 后写 = 上层），避免全屏 ScrollView 拦截点击
            HeroBackButton(title: "温情打卡", color: DSToken.m1) { onCancel() }
        }
        .onAppear {
            if let editing {
                title = editing.title
                desc = editing.itemDesc
                remind = editing.remind
            } else {
                titleFocused = true   // 新建自动聚焦标题（编辑不抢焦点）
            }
        }
    }

    /// 字段标签（原型 .form-label：12 semibold ink2 + small 弱提示 ink3）
    private func fieldLabel(_ text: String, hint: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(DSToken.body(12, weight: .semibold))
                .foregroundStyle(DSToken.ink2)
                .tracking(0.5)
            Text(hint)
                .font(DSToken.body(10.5))
                .foregroundStyle(DSToken.ink3)
                .padding(.leading, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 2)
    }

    /// 主按钮（原型 .primary-btn：渐变 150° · r-card 圆角 · 32% 投影 · 空值禁用降透明）
    private var saveButton: some View {
        Button(action: {
            titleFocused = false
            onSave(title.trimmingCharacters(in: .whitespaces), desc, remind)
        }) {
            Text("保存")
                .font(DSToken.body(16.5, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [DSToken.m1.mixedWithWhite(0.25), DSToken.m1]),
                                startPoint: UnitPoint(x: 0.5, y: 0), endPoint: UnitPoint(x: 0.33, y: 1)
                            )
                        )
                )
                .shadow(color: DSToken.m1.opacity(0.32), radius: 13, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.45)
        .animation(DSToken.spring, value: canSave)
    }
}

// MARK: 时间档位 chips（原型 .time-chips：胶囊单选）

private struct FlowChips: View {
    let options: [String]
    @Binding var selected: String
    var onPick: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { opt in
                let on = opt == selected
                Text(label(opt))
                    .font(DSToken.body(12.5, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? DSToken.m1 : DSToken.ink2)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white))
                    .overlay(
                        Capsule().strokeBorder(
                            on ? DSToken.m1.opacity(0.55) : DSToken.line,
                            lineWidth: 1
                        )
                    )
                    .onTapGesture {
                        selected = opt
                        onPick?()
                    }
            }
        }
    }

    private func label(_ opt: String) -> String { opt.isEmpty ? "不提醒" : opt }
}
