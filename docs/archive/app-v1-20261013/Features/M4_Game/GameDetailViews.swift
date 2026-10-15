import SwiftUI
import SwiftData

/// M4 二级页 - 战绩总览（d10）
struct GameRecordsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext
    @State private var records: [GameRecord] = []
    @State private var toast: Toast?

    private var totalPlays: Int { records.count }
    private var totalStars: Int { records.reduce(0) { $0 + $1.stars } }
    private var streak: Int {
        let cal = Calendar.current
        let days = Set(records.map { cal.startOfDay(for: $0.playedAt) })
        var s = 0
        var cursor = cal.startOfDay(for: .now)
        while days.contains(cursor) {
            s += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return s
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacing) {
                    statsRow
                    trendCard
                    recordsList
                }
                .padding(.horizontal, DesignTokens.spacing)
                .padding(.vertical, DesignTokens.spacing)
            }
        }
        .background(DesignTokens.bgPrimary.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast { ToastView(toast: toast).padding(.bottom, 32) }
        }
        .task { load() }
    }

    private var header: some View {
        HStack {
            Button(action: { state.backOneLevel() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
            }
            Spacer()
            Text("战绩总览").font(.system(size: 15, weight: .semibold)).foregroundStyle(DesignTokens.ink)
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, DesignTokens.spacing)
        .padding(.vertical, 10)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            GameStatChip(label: "总局数", value: "\(totalPlays)")
            GameStatChip(label: "总星数", value: "\(totalStars)")
            GameStatChip(label: "连续天数", value: "\(streak)")
        }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("近 7 天趋势")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.inkSecondary)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(last7Days, id: \.self) { day in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DesignTokens.m4Yellow)
                            .frame(height: barHeight(for: day))
                            .frame(maxWidth: .infinity)
                        Text(dayLabel(day))
                            .font(.system(size: 9))
                            .foregroundStyle(DesignTokens.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 90)
        }
        .padding(DesignTokens.spacing)
        .glassCard(moduleColor: DesignTokens.m4Yellow)
    }

    private var last7Days: [Date] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: cal.startOfDay(for: .now))
        }
    }

    private func barHeight(for day: Date) -> CGFloat {
        let cal = Calendar.current
        let count = records.filter { cal.isDate($0.playedAt, inSameDayAs: day) }.count
        let total = Swift.max(1, records.count)
        return max(4, CGFloat(count) / CGFloat(total) * 60)
    }

    private func dayLabel(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "E"
        f.locale = Locale(identifier: "zh_CN")
        return f.string(from: d)
    }

    private var recordsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("近期对局")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.inkSecondary)
            ForEach(records.prefix(10), id: \.id) { r in
                GameRecordRow(record: r)
            }
        }
    }

    private func load() {
        let gp = GameProvider(context: modelContext)
        records = (try? gp.records()) ?? []
    }
}

private struct GameStatChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.ink)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(DesignTokens.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard(moduleColor: DesignTokens.m4Yellow)
    }
}

private struct GameRecordRow: View {
    let record: GameRecord

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(gameTitle(record.gameKey))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
                Text(timeString(record.playedAt))
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.inkSecondary)
            }
            Spacer()
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { idx in
                    Image(systemName: idx < record.stars ? "star.fill" : "star")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignTokens.m4Yellow)
                }
            }
            Text("\(record.score)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.ink)
                .frame(minWidth: 50, alignment: .trailing)
        }
        .padding(DesignTokens.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(moduleColor: DesignTokens.m4Yellow)
    }

    private func gameTitle(_ key: String) -> String {
        switch key {
        case "klotski": return "华容道"
        case "maze": return "迷宫滚球"
        case "2048": return "2048"
        case "oneline": return "一笔画"
        default: return key
        }
    }
    private func timeString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MM-dd HH:mm"
        return f.string(from: d)
    }
}

/// M4 二级页 - 单游戏统计（d11）
struct GameStatsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext

    let itemID: String?       // gameKey

    @State private var progress: GameProgress? = nil
    @State private var records: [GameRecord] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacing) {
                    if let p = progress {
                        heroCard(p)
                        recordsCard
                        placeholderCard
                    }
                }
                .padding(.horizontal, DesignTokens.spacing)
                .padding(.vertical, DesignTokens.spacing)
            }
        }
        .background(DesignTokens.bgPrimary.ignoresSafeArea())
        .task { load() }
    }

    private var header: some View {
        HStack {
            Button(action: { state.backOneLevel() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
            }
            Spacer()
            Text(gameTitle).font(.system(size: 15, weight: .semibold)).foregroundStyle(DesignTokens.ink)
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, DesignTokens.spacing)
        .padding(.vertical, 10)
    }

    private func heroCard(_ p: GameProgress) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(DesignTokens.m4Yellow.opacity(0.18))
                    .frame(width: 60, height: 60)
                Image(systemName: gameIcon)
                    .font(.system(size: 26))
                    .foregroundStyle(DesignTokens.m4Yellow)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(gameTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DesignTokens.ink)
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { idx in
                        Image(systemName: idx < p.bestScore ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignTokens.m4Yellow)
                    }
                    Text("最佳 \(p.bestScore) 星")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.inkSecondary)
                }
                Text("已玩 \(p.totalPlays) 局")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.inkSecondary)
            }
            Spacer()
        }
        .padding(DesignTokens.spacing)
        .glassCard(moduleColor: DesignTokens.m4Yellow, selected: true)
    }

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("近 6 局 · 成绩记录 · 点条展开待游戏本体设计")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.inkSecondary)
            if records.isEmpty {
                Text("还没玩过")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignTokens.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(records, id: \.id) { r in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(r.score) 分")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(DesignTokens.ink)
                            Text(timeString(r.playedAt))
                                .font(.system(size: 10))
                                .foregroundStyle(DesignTokens.inkSecondary)
                        }
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { idx in
                                Image(systemName: idx < r.stars ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DesignTokens.m4Yellow)
                            }
                        }
                        Text(duration(r.durationSec))
                            .font(.system(size: 11))
                            .foregroundStyle(DesignTokens.inkSecondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(DesignTokens.spacing)
                    .glassCard(moduleColor: DesignTokens.m4Yellow)
                }
            }
        }
    }

    private var placeholderCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 30))
                .foregroundStyle(DesignTokens.m4Yellow.opacity(0.4))
            Text("游戏本体设计中")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignTokens.ink)
            Text("玩法规则与字段定义待单独设计（P7 待办）")
                .font(.system(size: 11))
                .foregroundStyle(DesignTokens.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .glassCard(moduleColor: DesignTokens.m4Yellow)
    }

    private var gameTitle: String {
        switch itemID {
        case "klotski": return "华容道"
        case "maze": return "迷宫滚球"
        case "2048": return "2048"
        case "oneline": return "一笔画"
        default: return itemID ?? "游戏"
        }
    }
    private var gameIcon: String {
        switch itemID {
        case "klotski": return "square.grid.3x3.fill"
        case "maze": return "gyroscope"
        case "2048": return "number.square.fill"
        case "oneline": return "pencil.line"
        default: return "gamecontroller.fill"
        }
    }

    private func load() {
        guard let key = itemID else { return }
        let gp = GameProvider(context: modelContext)
        let all = (try? gp.list()) ?? []
        progress = all.first { $0.gameKey == key }
        records = (try? gp.records(of: key, limit: 6)) ?? []
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MM-dd HH:mm"
        return f.string(from: d)
    }
    private func duration(_ sec: Int) -> String {
        let m = sec / 60, s = sec % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// M4 二级页 - 勋章详情（d12）
struct GameBadgeDetailView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext

    let itemID: String?       // badge key

    @State private var badge: GameBadge? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            if let b = badge {
                ScrollView {
                    VStack(spacing: DesignTokens.spacing2) {
                        ZStack {
                            Circle()
                                .fill(b.isUnlocked ? DesignTokens.m4Yellow.opacity(0.2) : DesignTokens.bgSecondary)
                                .frame(width: 110, height: 110)
                            Image(systemName: b.isUnlocked ? "medal.fill" : "medal")
                                .font(.system(size: 48))
                                .foregroundStyle(b.isUnlocked ? DesignTokens.m4Yellow : DesignTokens.inkSecondary.opacity(0.5))
                        }
                        .padding(.top, 30)

                        Text(b.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(DesignTokens.ink)

                        Text(b.detail)
                            .font(.system(size: 14))
                            .foregroundStyle(DesignTokens.inkSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)

                        if !b.isUnlocked {
                            VStack(spacing: 8) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(DesignTokens.bgSecondary).frame(height: 8)
                                        Capsule()
                                            .fill(DesignTokens.m4Yellow)
                                            .frame(width: geo.size.width * min(1, CGFloat(b.progress) / CGFloat(max(1, b.target))), height: 8)
                                    }
                                }
                                .frame(height: 8)
                                Text("\(b.progress) / \(b.target)")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(DesignTokens.inkSecondary)
                            }
                            .padding(.horizontal, 30)
                        } else if let unlockedAt = b.unlockedAt {
                            Text("解锁于 \(dateString(unlockedAt))")
                                .font(.system(size: 12))
                                .foregroundStyle(DesignTokens.inkSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, DesignTokens.spacing)
                    .padding(.vertical, DesignTokens.spacing)
                }
            }
        }
        .background(DesignTokens.bgPrimary.ignoresSafeArea())
        .task { load() }
    }

    private var header: some View {
        HStack {
            Button(action: { state.backOneLevel() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
            }
            Spacer()
            Text("勋章详情").font(.system(size: 15, weight: .semibold)).foregroundStyle(DesignTokens.ink)
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, DesignTokens.spacing)
        .padding(.vertical, 10)
    }

    private func load() {
        guard let key = itemID else { return }
        let gp = GameProvider(context: modelContext)
        let all = (try? gp.badges()) ?? []
        badge = all.first { $0.key == key }
    }

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}

/// M4 二级页 - 设置（d13）
struct GameSettingsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext

    @State private var settings: GameSettings? = nil
    @State private var toast: Toast?
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: DesignTokens.spacing) {
                    if let s = settings {
                        VStack(spacing: 0) {
                            ToggleRow(title: "音效", isOn: Binding(
                                get: { s.soundOn },
                                set: { s.soundOn = $0; save() }
                            ))
                            Divider().padding(.leading, 16)
                            ToggleRow(title: "触感", isOn: Binding(
                                get: { s.hapticOn },
                                set: { s.hapticOn = $0; save() }
                            ))
                            Divider().padding(.leading, 16)
                            ToggleRow(title: "计时显示", isOn: Binding(
                                get: { s.timerOn },
                                set: { s.timerOn = $0; save() }
                            ))
                        }
                        .glassCard(moduleColor: DesignTokens.m4Yellow)

                        VStack(spacing: 0) {
                            ActionRow(title: "导出战绩", icon: "square.and.arrow.up", tint: DesignTokens.m4Yellow) {
                                toast = Toast(module: .game, text: "导出能力将在原生文件接口接入后开放")
                                clearToastAfter(1.5)
                            }
                            Divider().padding(.leading, 16)
                            ActionRow(title: "清空战绩", icon: "trash", tint: DesignTokens.error) {
                                showClearConfirm = true
                            }
                        }
                        .glassCard(moduleColor: DesignTokens.m4Yellow)
                    }
                }
                .padding(.horizontal, DesignTokens.spacing)
                .padding(.vertical, DesignTokens.spacing)
            }
        }
        .background(DesignTokens.bgPrimary.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast { ToastView(toast: toast).padding(.bottom, 32) }
        }
        .task { load() }
        .confirmationDialog("清空全部战绩？", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("清空", role: .destructive) { clearRecords() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销")
        }
    }

    private var header: some View {
        HStack {
            Button(action: { state.backOneLevel() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
            }
            Spacer()
            Text("游戏设置").font(.system(size: 15, weight: .semibold)).foregroundStyle(DesignTokens.ink)
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, DesignTokens.spacing)
        .padding(.vertical, 10)
    }

    private func load() {
        let gp = GameProvider(context: modelContext)
        settings = try? gp.settings()
    }

    private func save() {
        try? modelContext.save()
    }

    private func clearRecords() {
        let gp = GameProvider(context: modelContext)
        try? gp.clearRecords()
        toast = Toast(module: .game, text: "战绩已清空")
        clearToastAfter(1.5)
    }

    private func clearToastAfter(_ sec: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + sec) {
            toast = nil
        }
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .font(.system(size: 15))
            .tint(DesignTokens.m4Yellow)
            .padding(.horizontal, DesignTokens.spacing)
            .padding(.vertical, 12)
    }
}

private struct ActionRow: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(tint)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkSecondary.opacity(0.5))
            }
            .padding(.horizontal, DesignTokens.spacing)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
