import SwiftUI
import UIKit

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
    // 提醒规则（每日/每周/每月 · 底部唤起面板；nil = 不提醒）
    @State private var rule: RemindRule? = nil
    @State private var showReminder = false
    /// DEBUG：-m1-step 透传给面板强制初始步（模拟器截图验证 step1）
    @State private var debugRemindStep: Int? = nil
    @FocusState private var focusField: Field?

    /// 输入焦点（键盘「完成」按钮统一收起）
    enum Field: Hashable { case title, desc }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    /// 保存用提醒字符串（规则编码；不提醒为空串）
    private var remindOutput: String { rule?.storage ?? "" }

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
                                    focusField == .title ? DSToken.m1.opacity(0.55) : DSToken.line,
                                    lineWidth: focusField == .title ? 1.5 : 1
                                )
                        )
                        .shadow(color: DSToken.m1.opacity(focusField == .title ? 3 : 0), radius: 3)
                        .focused($focusField, equals: .title)

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
                        .focused($focusField, equals: .desc)

                    fieldLabel("提醒时间", hint: "每日 / 每周 / 每月 · 底部唤起选择")
                        .padding(.top, 13)
                    // 键盘式底部唤起：先收输入键盘 → 规则面板贴底滑入（与键盘同交互逻辑）
                    Button {
                        focusField = nil
                        withAnimation(DSToken.spring) { showReminder = true }
                    } label: {
                        HStack(spacing: 8) {
                            Text(rule?.text ?? "不提醒")
                                .font(DSToken.body(15.5))
                                .foregroundStyle(rule == nil ? DSToken.ink3 : DSToken.ink)
                            Spacer(minLength: 0)
                            Text("›")
                                .font(DSToken.body(15, weight: .semibold))
                                .foregroundStyle(DSToken.ink3)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.92))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    showReminder ? DSToken.m1.opacity(0.55) : DSToken.line,
                                    lineWidth: showReminder ? 1.5 : 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
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

            // 提醒规则面板（键盘式贴底唤起 · 「完成」收起，与输入键盘同交互逻辑）
            if showReminder {
                RemindRulePicker(rule: $rule, onDone: {
                    withAnimation(DSToken.spring) { showReminder = false }
                }, debugStep: debugRemindStep)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.move(edge: .bottom))
            }
        }
        // 输入键盘「完成」按钮（用户需求：点击收起键盘）
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { focusField = nil }
                    .font(DSToken.body(16, weight: .semibold))
            }
        }
        .onAppear {
            if let editing {
                title = editing.title
                desc = editing.itemDesc
                rule = CheckInRemind.parseRule(editing.remind)   // 回填提醒规则（含旧格式兼容）
            } else {
                focusField = .title   // 新建自动聚焦标题（编辑不抢焦点）
            }
            // DEBUG 后门：-m1-remind <none|daily|weekly|workday|weekend|monthly|monthlymulti>
            // 模拟器截图诊断：直达表单 + 面板各形态（与生产同路径 withAnimation）
            if let i = CommandLine.arguments.firstIndex(of: "-m1-remind"),
               CommandLine.arguments.indices.contains(i + 1) {
                switch CommandLine.arguments[i + 1] {
                case "daily": rule = .daily(hour: 20, minute: 0)
                case "weekly": rule = .weekly(weekdays: [3], skipHolidays: false, hour: 20, minute: 0)
                case "workday": rule = RemindRule.workday(hour: 20, minute: 0)
                case "weekend": rule = .weekly(weekdays: RemindRule.weekendWeekdays, skipHolidays: true, hour: 20, minute: 0)
                case "monthly": rule = .monthly(days: [15], hour: 9, minute: 0)
                case "monthlymulti": rule = .monthly(days: [1, 15], hour: 9, minute: 0)
                default: rule = nil   // none
                }
                focusField = nil
                withAnimation(DSToken.spring) { showReminder = true }   // 与生产同路径（带动画）
                if let si = CommandLine.arguments.firstIndex(of: "-m1-step"),
                   CommandLine.arguments.indices.contains(si + 1),
                   let s = Int(CommandLine.arguments[si + 1]) {
                    debugRemindStep = s
                }
            }
        }
        // 键盘与提醒面板互斥：输入框获得焦点（键盘唤起）时收起规则面板，避免两者同屏
        .onChange(of: focusField) { _, now in
            if now != nil, showReminder {
                withAnimation(DSToken.spring) { showReminder = false }
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
            focusField = nil
            onSave(title.trimmingCharacters(in: .whitespaces), desc, remindOutput)
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


// MARK: - 提醒规则底部唤起面板（两步式：先复选规则条件 → 再选时间；键盘式贴底交互）
// 交互结构（用户需求 2026-10-16 定稿）：
//   每日 → 直接时间滚轮（无第一步）
//   每周 → 第一步：快捷预设（工作日=周一~五+内置假日表跳假 / 周末）+ 星期单字多选
//          （至少一天）+ 跳假日说明 → 「下一步」→ 第二步：时间滚轮
//   每月 → 第一步：日期多选（日历式 7 列网格 1~31 复选，取代滚轮）→「下一步」→ 时间滚轮
//   编辑回填：面板打开时规则已存在 → 直接落时间步（头部「‹ 星期 / ‹ 日期」一步回退修改）
// 渲染要点（实测教训 · 2026-10-16 模拟器截图诊断）：
//   ① 时间不用 DatePicker——其跟随系统 12/24 小时制（出现「上午/下午」列），
//      与全 App「20:00」24h 文案不一致；改自绘 Picker 双轮「20 时 / 00 分」；
//   ② 滚轮不设固定 height、不加 clipped——UIPickerView 不遵守约束帧，
//      固有高度（~216pt）会上下溢出穿透相邻控件（实测复现）；自然高度布局即无穿透；
//   ③ hero 覆盖层内容 ignoresSafeArea → 面板自行避让 home 指示条（homeSafeBottom），
//      背景白面仍延伸到屏幕底。

struct RemindRulePicker: View {
    @Binding var rule: RemindRule?
    let onDone: () -> Void
    /// DEBUG：后门强制初始步（nil = 正常逻辑；模拟器 -m1-step 1 截图验证 step1 用）
    var debugStep: Int? = nil

    private enum Kind { case daily, weekly, monthly }

    /// 1 = 复选步（weekly 星期 / monthly 日期）· 2 = 时间步；daily 无 step1
    @State private var step = 2

    /// 步骤转场（方向性：前进右缘滑入 / 回退左缘滑入）
    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var kind: Kind? {
        switch rule {
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case nil: return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏（键盘式：左标题 · 右「完成」——任意步可直接完成收起）
            HStack {
                Text("提醒")
                    .font(DSToken.body(15, weight: .semibold))
                    .foregroundStyle(DSToken.ink)
                Spacer()
                Button("完成") { onDone() }
                    .font(DSToken.body(15, weight: .semibold))
                    .foregroundStyle(DSToken.m1)
            }
            .padding(.horizontal, 18)
            .padding(.top, 13)
            .padding(.bottom, 11)

            // 规则段（常驻）
            HStack(spacing: 8) {
                kindChip("每日", on: kind == .daily) { switchKind(.daily) }
                kindChip("每周", on: kind == .weekly) { switchKind(.weekly) }
                kindChip("每月", on: kind == .monthly) { switchKind(.monthly) }
                kindChip("不提醒", on: kind == nil) { setNone() }
            }
            .padding(.horizontal, 18)

            // 第一步：复选区（每周 = 星期 · 每月 = 日期）
            if step == 1, kind == .weekly {
                weeklyStep
                    .transition(stepTransition)
            } else if step == 1, kind == .monthly {
                monthlyStep
                    .transition(stepTransition)
            } else if rule != nil {
                // 时间步：每日直接进 · 每周/每月「下一步」后进 · 回填打开即在此
                timeStep
                    .transition(stepTransition)
            }
        }
        .padding(.bottom, homeSafeBottom + 10)
        .frame(maxWidth: .infinity)
        .background(
            // 键盘式贴底白面（不用 material：与全局「去实时模糊」性能约定一致）
            Rectangle()
                .fill(Color.white)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(DSToken.line).frame(height: 1)
        }
        .shadow(color: .black.opacity(0.10), radius: 14, y: -5)
        .onAppear {
            // 正常逻辑：rule 已存在（编辑回填）→ 直接时间步；规则段选择在 switchKind 里驱动 step
            if let debugStep {
                step = debugStep
            } else {
                step = 2
            }
        }
    }

    // MARK: 第一步 · 每周（预设 + 星期多选 + 跳假说明）

    private var weeklyStep: some View {
        VStack(spacing: 12) {
            stepLabel("第一步 · 选择星期")

            HStack(spacing: 8) {
                kindChip("工作日", on: isWorkdayPreset, action: applyWorkdayPreset)
                kindChip("周末", on: isWeekendPreset, action: applyWeekendPreset)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)

            HStack(spacing: 7) {
                ForEach(1...7, id: \.self) { w in
                    weekdayChip(w)
                }
            }
            .padding(.horizontal, 18)

            if skipHolidays {
                Text("法定假日自动不提醒 · 依据内置 2026 年国务院安排")
                    .font(DSToken.body(10.5))
                    .foregroundStyle(DSToken.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
            }

            nextRow(hint: "可多选 · 至少保留一天")
        }
        .padding(.top, 10)
    }

    // MARK: 第一步 · 每月（日期复选网格，日历式 7 列）

    private var monthlyStep: some View {
        VStack(spacing: 12) {
            stepLabel("第一步 · 选择日期")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 7), spacing: 7) {
                ForEach(1...31, id: \.self) { d in
                    dayChip(d)
                }
            }
            .padding(.horizontal, 18)

            nextRow(hint: "可多选 · 至少保留一天")
        }
        .padding(.top, 10)
    }

    // MARK: 第二步 · 时间滚轮（24h 自绘双轮）

    private var timeStep: some View {
        VStack(spacing: 0) {
            // 步骤头：非每日可一步回退改复选；右侧当前复选摘要
            HStack(spacing: 8) {
                if kind == .weekly {
                    Button { withAnimation(DSToken.spring) { step = 1 } } label: {
                        Text("‹ 星期")
                            .font(DSToken.body(13.5, weight: .semibold))
                            .foregroundStyle(DSToken.m1)
                    }
                    .buttonStyle(.plain)
                } else if kind == .monthly {
                    Button { withAnimation(DSToken.spring) { step = 1 } } label: {
                        Text("‹ 日期")
                            .font(DSToken.body(13.5, weight: .semibold))
                            .foregroundStyle(DSToken.m1)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(selectionSummary)
                    .font(DSToken.body(12.5, weight: .semibold))
                    .foregroundStyle(DSToken.ink2)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 2)

            TimeWheels(
                ruleHour: hour, ruleMinute: minute,
                onCommit: { h, m in updateTime(hour: h, minute: m) }
            )
        }
    }

    /// 当前复选摘要（时间步头部提示已选星期/日期）
    private var selectionSummary: String {
        switch kind {
        case .weekly:
            return "每周\(RemindRule.weekdaySummary(weekdays))"
        case .monthly:
            return "每月 \(RemindRule.daySummary(days)) 日"
        default:
            return "每天"
        }
    }

    // MARK: 派生状态与操作

    private var weekdays: [Int] {
        if case .weekly(let ws, _, _, _) = rule { return ws }
        return []
    }
    private var skipHolidays: Bool {
        if case .weekly(_, let skip, _, _) = rule { return skip }
        return false
    }
    private var isWorkdayPreset: Bool {
        if case .weekly(let ws, true, _, _) = rule { return ws == RemindRule.workdayWeekdays }
        return false
    }
    private var isWeekendPreset: Bool {
        weekdays == RemindRule.weekendWeekdays
    }
    private var days: [Int] {
        if case .monthly(let ds, _, _) = rule { return ds }
        return []
    }
    private var hour: Int { rule?.hour ?? 20 }
    private var minute: Int { rule?.minute ?? 0 }

    /// hero 覆盖层内容已 ignoresSafeArea → 面板可交互内容自行避让 home 指示条
    private var homeSafeBottom: CGFloat {
        for scene in UIApplication.shared.connectedScenes {
            if let ws = scene as? UIWindowScene, let window = ws.keyWindow {
                return window.safeAreaInsets.bottom
            }
        }
        return 0
    }

    /// 切换规则类型（保留已选时间；每周默认今天所在星期 / 每月默认今天日期；
    /// 每日直接进时间步、每周/每月进复选步）
    private func switchKind(_ k: Kind) {
        withAnimation(DSToken.spring) {
            switch k {
            case .daily:
                rule = .daily(hour: hour, minute: minute)
                step = 2
            case .weekly:
                if kind != .weekly {
                    let today = Calendar.current.component(.weekday, from: Date())
                    rule = .weekly(weekdays: [today], skipHolidays: false, hour: hour, minute: minute)
                }
                step = 1
            case .monthly:
                if kind != .monthly {
                    let today = Calendar.current.component(.day, from: Date())
                    rule = .monthly(days: [today], hour: hour, minute: minute)
                }
                step = 1
            }
        }
    }

    /// 不提醒（回到规则段待选态）
    private func setNone() {
        withAnimation(DSToken.spring) {
            rule = nil
            step = 2
        }
    }

    /// 「工作日」预设：周一~五 + 启用跳假；预设即定 → 直接进时间步
    private func applyWorkdayPreset() {
        withAnimation(DSToken.spring) {
            rule = RemindRule.workday(hour: hour, minute: minute)
            step = 2
        }
    }

    /// 「周末」预设：周六、周日（保留既有跳假选择——周末遇法定假期同样跳过）
    private func applyWeekendPreset() {
        withAnimation(DSToken.spring) {
            rule = .weekly(
                weekdays: RemindRule.weekendWeekdays,
                skipHolidays: skipHolidays,
                hour: hour, minute: minute
            )
            step = 2
        }
    }

    /// 星期多选 toggle（至少保留一天：移除最后一枚时忽略）
    private func toggleWeekday(_ w: Int) {
        guard case .weekly(let ws, let skip, let h, let m) = rule else { return }
        var set = Set(ws)
        if set.contains(w) {
            guard set.count > 1 else { return }
            set.remove(w)
        } else {
            set.insert(w)
        }
        rule = .weekly(
            weekdays: set.sorted(),
            skipHolidays: skip,   // 手动增减星期保留跳假选择
            hour: h, minute: m
        )
    }

    /// 每月日期多选 toggle（至少保留一天：移除最后一个时忽略——与星期复选一致）
    private func toggleDay(_ d: Int) {
        guard case .monthly(let ds, let h, let m) = rule else { return }
        var set = Set(ds)
        if set.contains(d) {
            guard set.count > 1 else { return }
            set.remove(d)
        } else {
            set.insert(d)
        }
        rule = .monthly(days: set.sorted(), hour: h, minute: m)
    }

    private func updateTime(hour h: Int, minute m: Int) {
        switch rule {
        case .daily:
            rule = .daily(hour: h, minute: m)
        case .weekly(let ws, let skip, _, _):
            rule = .weekly(weekdays: ws, skipHolidays: skip, hour: h, minute: m)
        case .monthly(let ds, _, _):
            rule = .monthly(days: ds, hour: h, minute: m)
        case nil:
            break
        }
    }

    // MARK: 小组件

    /// 步骤小标签（第一步区顶部）
    private func stepLabel(_ text: String) -> some View {
        Text(text)
            .font(DSToken.body(11, weight: .semibold))
            .foregroundStyle(DSToken.ink3)
            .tracking(0.4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }

    /// 第一步底部行：左提示 · 右「下一步」（进时间步）
    private func nextRow(hint: String) -> some View {
        HStack {
            Text(hint)
                .font(DSToken.body(10.5))
                .foregroundStyle(DSToken.ink3)
            Spacer()
            Button {
                withAnimation(DSToken.spring) { step = 2 }
            } label: {
                Text("下一步 ›")
                    .font(DSToken.body(14, weight: .semibold))
                    .foregroundStyle(DSToken.m1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 2)
    }

    /// 每月日期胶囊（多选复选：与星期胶囊同款；至少保留一天）
    private func dayChip(_ d: Int) -> some View {
        let on = days.contains(d)
        return Button { toggleDay(d) } label: {
            Text("\(d)")
                .font(DSToken.body(13.5, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? .white : DSToken.ink2)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(Capsule().fill(on ? DSToken.m1 : Color.white))
                .overlay(Capsule().strokeBorder(on ? Color.clear : DSToken.line, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// 星期多选胶囊（Button 实现：命中区稳定，避免 Text.onTapGesture 在叠加层/过渡动画下的失效）
    private func weekdayChip(_ w: Int) -> some View {
        let on = weekdays.contains(w)
        return Button { toggleWeekday(w) } label: {
            Text(RemindRule.weekdayChars[w - 1])
                .font(DSToken.body(13, weight: .semibold))
                .foregroundStyle(on ? .white : DSToken.ink2)
                .frame(width: 38, height: 34)
                .background(Capsule().fill(on ? DSToken.m1 : Color.white))
                .overlay(Capsule().strokeBorder(on ? Color.clear : DSToken.line, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// 规则段/快捷预设胶囊
    private func kindChip(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(DSToken.body(13, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? .white : DSToken.ink2)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().fill(on ? DSToken.m1 : Color.white))
                .overlay(Capsule().strokeBorder(on ? Color.clear : DSToken.line, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}


// MARK: - 时分滚轮（隔离子视图 · 性能修复 2026-10-16）
// 问题：滚轮 selection 直连 rule 派生 Binding → 每帧 set 触发整面板
//（顶部栏/规则段/条件区 ~200 视图）重 diff，滚动手势在大面板重建中
// 有迟滞感。
// 方案：本地 @State 承载滚动值——set 只重算本视图（2 个 Picker 84 行）；
// onChange 双通道同步：本地滚动 → onCommit 写回 rule；rule 变化（切换
// 规则类型保留时间）→ 回填本地。时间步固定位置挂载，identity 稳定
//（@State 不丢，手势不中断）。

struct TimeWheels: View {
    /// 规则当前时/分（外部同步源）
    let ruleHour: Int
    let ruleMinute: Int
    var onCommit: (Int, Int) -> Void

    @State private var hour: Int
    @State private var minute: Int

    init(ruleHour: Int, ruleMinute: Int, onCommit: @escaping (Int, Int) -> Void) {
        self.ruleHour = ruleHour
        self.ruleMinute = ruleMinute
        self.onCommit = onCommit
        _hour = State(initialValue: ruleHour)
        _minute = State(initialValue: ruleMinute)
    }

    var body: some View {
        HStack(spacing: 0) {
            Picker("时", selection: $hour) {
                ForEach(0..<24, id: \.self) { Text(String(format: "%02d 时", $0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            Picker("分", selection: $minute) {
                ForEach(0..<60, id: \.self) { Text(String(format: "%02d 分", $0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        // 外部 → 本地（rule 侧改时间/切换规则类型保留值时回填；值相等不触发，无回环）
        .onChange(of: ruleHour) { _, v in hour = v }
        .onChange(of: ruleMinute) { _, v in minute = v }
        // 本地 → 外部（滚动即写回规则；面板重建但本视图 @State 保真）
        .onChange(of: hour) { _, _ in onCommit(hour, minute) }
        .onChange(of: minute) { _, _ in onCommit(hour, minute) }
    }
}
