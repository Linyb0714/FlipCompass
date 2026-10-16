import SwiftUI
import SwiftData

// MARK: - d1 打卡详情（C1 · 原型 #scr-d1 转录 · hero 生长打开）
// 标题/副题 → 大✓打卡钮（168 圆 · pop 弹跳 + 涟漪）→ 今日状态（已打：时间+连续天数）→
// 本月分布月历（7 列：橙点=打 红环=遗漏 今天描边）→ 图例 → 心情时间线（最近 6 次）。

struct M1DetailPage: View {
    let item: CheckInItem
    let onBack: () -> Void
    let onCheckedIn: (String) -> Void   // toast 文案回传

    @Environment(\.modelContext) private var modelContext

    @State private var pop = false
    @State private var ripple = false

    private var doneRec: CheckInRecord? {
        let today0 = CheckInStats.startOfDay(Date())
        return item.records.first { $0.day == today0 }
    }

    private var streak: Int {
        CheckInStats.streak(days: Set(item.records.map(\.day)), today: Date())
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    Text(item.title)
                        .font(DSToken.body(27, weight: .bold))
                        .foregroundStyle(DSToken.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)

                    Text(subtitle)
                        .font(DSToken.body(12.5))
                        .foregroundStyle(DSToken.ink2)
                        .padding(.top, 8)

                    // ---- 大✓打卡钮（168 圆 · 渐变 · pop 弹跳 + 涟漪）----
                    bigCheck
                        .padding(.top, 40)

                    // ---- 今日状态 ----
                    statusText
                        .font(DSToken.body(14.5))
                        .foregroundStyle(DSToken.ink2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.top, 36)

                    // ---- 本月分布 ----
                    Text("本月分布")
                        .font(DSToken.body(12, weight: .semibold))
                        .foregroundStyle(DSToken.ink2)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 2)
                        .padding(.top, 30)
                        .padding(.bottom, 4)
                    M1MonthCalendar(days: Set(item.records.map(\.day)))
                    M1CalLegend()
                        .padding(.bottom, 6)

                    // ---- 心情时间线 ----
                    Text("心情时间线")
                        .font(DSToken.body(12, weight: .semibold))
                        .foregroundStyle(DSToken.ink2)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 2)
                        .padding(.top, 14)
                        .padding(.bottom, 6)
                    M1MoodTimeline(records: CheckInStats.recentRecords(Array(item.records)))
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)

            // 返回按钮必须压在 ScrollView 之上（ZStack 后写 = 上层）：
            // 写在前面会被全屏 ScrollView 的 hit-test 拦截，点不到
            HeroBackButton(title: "温情打卡", color: DSToken.m1) { onBack() }
        }
    }

    private var subtitle: String {
        var s = item.itemDesc.isEmpty ? "每天一次 · 坚持就好" : item.itemDesc
        if let rule = CheckInRemind.parseRule(item.remind) {
            s += " · \(rule.text) 提醒"
        }
        return s
    }

    // MARK: 大✓（原型 .big-btn：168 圆 · 150° 渐变 · 白 ✓ 66 · pop collidePop + ripple）
    // C1 验收反馈：打卡后变色——主题橙 → 完成绿；再点不重复打卡（toast 提示已有时间）

    private var done: Bool { doneRec != nil }

    private var bigCheck: some View {
        Button(action: checkIn) {
            ZStack {
                // 橙（未完成）/ 绿（已完成）双层交叉淡化（Gradient 不可插值，opacity 过渡）
                ZStack {
                    checkCircle(DSToken.m1)
                        .opacity(done ? 0 : 1)
                    checkCircle(DSToken.ok)
                        .opacity(done ? 1 : 0)
                }
                .animation(DSToken.spring, value: done)
                if ripple {
                    Circle()
                        .strokeBorder(done ? DSToken.ok : DSToken.m1, lineWidth: 3)
                        .scaleEffect(1.3)
                        .opacity(0)
                }
                Text("✓")
                    .font(DSToken.body(64, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 168, height: 168)
            .scaleEffect(pop ? 1.09 : 1)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: pop)
    }

    private func checkCircle(_ c: Color) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [c.opacity(0.78).mixedWithWhite(), c]),
                    startPoint: UnitPoint(x: 0.5, y: 0), endPoint: UnitPoint(x: 0.33, y: 1)
                )
            )
            .shadow(color: c.opacity(0.38), radius: 26, y: 14)
            .shadow(color: .white.opacity(0.45), radius: 8, y: 2)
    }

    private var statusText: Text {
        if let rec = doneRec {
            let t = ThoughtFormat.hhmm(rec.time)
            var msg = AttributedString("今天已打卡 · ")
            var time = AttributedString(t)
            time.font = DSToken.num(17, weight: .semibold)
            time.foregroundColor = DSToken.ok   // 与大✓完成态同绿
            msg.append(time)
            msg.append(AttributedString("\n连续第 \(streak) 天，很稳"))
            return Text(msg)
        }
        return Text("今天还没打卡 · 点上面的 ✓ 完成")
    }

    private func checkIn() {
        let decision = M1Store.checkInDecision(item: item, now: Date())
        guard decision.inserted else {
            // 已打卡重复点：pop 提示
            playPop()
            onCheckedIn("今天已完成 · \(decision.time)")
            return
        }
        // 拓展优化：随机心情升级——经典六心情基调 + 热词潮词彩蛋（38%），
        // 剔除上次心情避免连撞；toast 即时揭晓，时间线同步可查。
        let last = CheckInStats.recentRecords(Array(item.records)).first?.mood
        let mood = M1Store.pickMood(previous: last)
        modelContext.insert(CheckInRecord(
            day: CheckInStats.startOfDay(Date()), time: Date(), mood: mood, item: item
        ))
        playPop()
        onCheckedIn(M1Store.checkInToast(title: item.title, streak: decision.streak, mood: mood))
    }

    private func playPop() {
        withAnimation(DSToken.bounce) { pop = true }
        withAnimation(.easeOut(duration: 0.7).delay(0.08)) { ripple = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(DSToken.spring) { pop = false }
            ripple = false
        }
    }
}

// MARK: - 本月分布月历（原型 .cal-grid：7 列圆点 · 橙=打/深浅 红环=遗漏 今天描边）

struct M1MonthCalendar: View {
    let days: Set<Date>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        let cells = CheckInStats.monthCalendar(days: days, today: Date())
        let cal = Calendar.current
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(cells.enumerated()), id: \.offset) { idx, cell in
                let date = cellDate(idx: idx)
                ZStack {
                    switch cell {
                    case .blank:
                        Color.clear
                    case .future:
                        Text("\(cal.component(.day, from: date))")
                            .font(DSToken.body(9))
                            .foregroundStyle(DSToken.ink3.opacity(0.5))
                    case .hit(let alpha):
                        Circle()
                            .fill(DSToken.m1)
                            .opacity(alpha)
                            .overlay(
                                Text("\(cal.component(.day, from: date))")
                                    .font(DSToken.body(9))
                                    .foregroundStyle(.white.opacity(0.85))
                            )
                    case .miss:
                        Circle()
                            .fill(Color.white)
                            .overlay(
                                Circle().strokeBorder(DSToken.bad.opacity(0.55), lineWidth: 1.5)
                            )
                            .overlay(
                                Text("\(cal.component(.day, from: date))")
                                    .font(DSToken.body(9))
                                    .foregroundStyle(DSToken.ink2)
                            )
                    case .today(let hasHit):
                        Group {
                            if hasHit {
                                Circle().fill(DSToken.m1)
                            } else {
                                Circle().fill(Color.white)
                            }
                        }
                        .overlay(
                            Circle().strokeBorder(DSToken.m1, lineWidth: 2)
                        )
                        .overlay(
                            Text("\(cal.component(.day, from: date))")
                                .font(DSToken.body(9, weight: .semibold))
                                .foregroundStyle(hasHit ? .white : DSToken.m1)
                        )
                    }
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
    }

    /// 由格序号反推日期（0..firstWd-2 = blank；从 firstWd-1 起为 1 号）
    private func cellDate(idx: Int) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        let monthStart = cal.date(from: comps) ?? Date()
        return cal.date(byAdding: .day, value: idx - (cal.component(.weekday, from: monthStart) - 1), to: monthStart) ?? Date()
    }
}

// MARK: - 月历图例（原型 .cal-legend）

struct M1CalLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            legendSwatch(fill: DSToken.m1.opacity(0.85), label: "已打卡")
            legendSwatch(fill: .white, ring: DSToken.bad.opacity(0.55), label: "遗漏")
            legendSwatch(fill: .white, label: "无记录")
        }
        .font(DSToken.body(10.5))
        .foregroundStyle(DSToken.ink2)
    }

    private func legendSwatch(fill: Color, ring: Color? = nil, label: String) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(fill)
                .overlay {
                    if let ring {
                        Circle().strokeBorder(ring, lineWidth: 1.5)
                    }
                }
                .frame(width: 9, height: 9)
            Text(label)
        }
    }
}

// MARK: - 心情时间线（原型 .mood-line：emoji 圆 + 心情/日期 + 时刻；空态文案）

struct M1MoodTimeline: View {
    let records: [CheckInRecord]

    // 拓展优化：emoji 映射上收 M1Store.moodEmoji 单一数据源（经典 + 热词全覆盖）

    var body: some View {
        if records.isEmpty {
            Text("还没有打卡记录")
                .font(DSToken.body(10.5))
                .foregroundStyle(DSToken.ink3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
        } else {
            VStack(spacing: 8) {
                ForEach(records, id: \.id) { rec in
                    HStack(spacing: 10) {
                        Text(M1Store.moodEmoji[rec.mood] ?? "😊")
                            .font(DSToken.body(15))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(DSToken.m1.opacity(0.14)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.mood.isEmpty ? "打卡" : rec.mood)
                                .font(DSToken.body(13, weight: .semibold))
                                .foregroundStyle(DSToken.ink)
                            Text("\(ThoughtFormat.mmdd(rec.day)) 打卡")
                                .font(DSToken.body(10.5))
                                .foregroundStyle(DSToken.ink2)
                        }
                        Spacer()
                        Text(ThoughtFormat.hhmm(rec.time))
                            .font(DSToken.num(11))
                            .foregroundStyle(DSToken.ink2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.white.opacity(0.9), .white.opacity(0.7)]),
                                    startPoint: .init(x: 0.5, y: 0), endPoint: .init(x: 0.44, y: 1)
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                }
            }
        }
    }
}

// MARK: - 大✓/渐变混白支持见 DesignSystem.swift · Color.mixedWithWhite