import SwiftUI
import SwiftData

/// M4 益智小游戏 根视图（V0.4.4）
/// 分组页：P0 今日推荐 / P1 全部游戏 / P2 成就（勋章）
struct GameRootView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext
    @State private var pageIndex: Int = 0
    @State private var games: [GameProgress] = []
    @State private var records: [GameRecord] = []
    @State private var badges: [GameBadge] = []
    @State private var toast: Toast?

    private let pages = ["今日推荐", "全部游戏", "成就"]

    var body: some View {
        VStack(spacing: 0) {
            tabs
            ZStack {
                switch pageIndex {
                case 0: GameTodayView(
                    games: games, records: records,
                    onDetail: { g in openGameStats(g) },
                    onRecords: { openRecords() }
                )
                case 1: GameListView(
                    games: games,
                    onDetail: { g in openGameStats(g) }
                )
                default: GameBadgesView(
                    badges: badges,
                    onDetail: { b in openBadge(b) },
                    onSettings: { openSettings() }
                )
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
                    .background(idx == pageIndex ? DesignTokens.m4Yellow.opacity(0.16) : Color.clear)
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

    private func openRecords() {
        state.enterDetail(DetailRoute(module: .game, pageKey: "records", itemID: nil))
    }
    private func openGameStats(_ g: GameProgress) {
        state.enterDetail(DetailRoute(module: .game, pageKey: "gameStats", itemID: g.gameKey))
    }
    private func openBadge(_ b: GameBadge) {
        state.enterDetail(DetailRoute(module: .game, pageKey: "badge", itemID: b.key))
    }
    private func openSettings() {
        state.enterDetail(DetailRoute(module: .game, pageKey: "settings", itemID: nil))
    }

    private func refresh() {
        let gp = GameProvider(context: modelContext)
        games = (try? gp.list()) ?? []
        records = (try? gp.records()) ?? []
        badges = (try? gp.badges()) ?? []
    }

    private func seedIfNeeded() {
        let gp = GameProvider(context: modelContext)
        let existing = (try? gp.list()) ?? []
        guard existing.isEmpty else { return }

        let games = [
            GameProgress(gameKey: "klotski", bestScore: 3, totalPlays: 8),
            GameProgress(gameKey: "maze", bestScore: 2, totalPlays: 5),
            GameProgress(gameKey: "2048", bestScore: 3, totalPlays: 12),
            GameProgress(gameKey: "oneline", bestScore: 1, totalPlays: 3),
        ]
        games.forEach { modelContext.insert($0) }

        // 近期战绩 mock
        let cal = Calendar.current
        for i in 0..<6 {
            let r = GameRecord(
                gameKey: ["klotski", "maze", "2048", "oneline"].randomElement() ?? "2048",
                score: Int.random(in: 200...1200),
                stars: Int.random(in: 1...3),
                durationSec: Int.random(in: 90...420),
                playedAt: cal.date(byAdding: .day, value: -i, to: .now) ?? .now
            )
            modelContext.insert(r)
        }

        // 勋章 mock
        let badges = [
            GameBadge(key: "first_win", title: "首胜", detail: "完成任意一局游戏", unlockedAt: .now, progress: 1, target: 1),
            GameBadge(key: "streak7", title: "七日坚持", detail: "连续 7 天每日完成一局", progress: 3, target: 7),
            GameBadge(key: "master2048", title: "2048 大师", detail: "在 2048 单局拿到 1000 分", progress: 720, target: 1000),
            GameBadge(key: "puzzle_lover", title: "解谜爱好者", detail: "集齐全部 4 款游戏的胜利", progress: 2, target: 4),
        ]
        badges.forEach { modelContext.insert($0) }
        try? modelContext.save()
    }
}

// MARK: - P0 今日推荐
private struct GameTodayView: View {
    let games: [GameProgress]
    let records: [GameRecord]
    let onDetail: (GameProgress) -> Void
    let onRecords: () -> Void

    private var recommended: GameProgress? {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        guard !games.isEmpty else { return nil }
        return games[day % games.count]
    }

    private var todayStars: Int {
        let cal = Calendar.current
        return records.filter { cal.isDateInToday($0.playedAt) }.reduce(0) { $0 + $1.stars }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacing) {
                if let rec = recommended {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("今日推荐")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(DesignTokens.inkSecondary)
                            Spacer()
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(DesignTokens.m4Yellow)
                            Text("\(rec.bestScore)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        Text(gameTitle(rec.gameKey))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(DesignTokens.ink)
                        Text(gameDescription(rec.gameKey))
                            .font(.system(size: 13))
                            .foregroundStyle(DesignTokens.inkSecondary)
                        HStack(spacing: 8) {
                            Label("已玩 \(rec.totalPlays) 局", systemImage: "gamecontroller")
                                .font(.system(size: 11))
                                .foregroundStyle(DesignTokens.inkSecondary)
                        }
                    }
                    .padding(DesignTokens.spacing2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(moduleColor: DesignTokens.m4Yellow, selected: true)
                    .onTapGesture { onDetail(rec) }
                }

                HStack {
                    Text("今日战绩")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignTokens.inkSecondary)
                    Spacer()
                    Button(action: onRecords) {
                        Text("查看全部 ›")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DesignTokens.m4Yellow)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)

                HStack(spacing: 10) {
                    StatChip(label: "今日星数", value: "\(todayStars)", module: .game)
                    StatChip(label: "总局数", value: "\(games.reduce(0) { $0 + $1.totalPlays })", module: .game)
                    StatChip(label: "三星局", value: "\(records.filter { $0.stars >= 3 }.count)", module: .game)
                }
            }
            .padding(.horizontal, DesignTokens.spacing)
            .padding(.vertical, DesignTokens.spacing)
        }
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
    private func gameDescription(_ key: String) -> String {
        switch key {
        case "klotski": return "经典滑块解谜，运筹走位"
        case "maze": return "倾斜手机，重力滚球"
        case "2048": return "滑动合成，冲击 2048"
        case "oneline": return "一笔连通全部节点"
        default: return ""
        }
    }
}

private struct StatChip: View {
    let label: String
    let value: String
    let module: ModuleKey

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.ink)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(DesignTokens.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(DesignTokens.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - P1 全部游戏
private struct GameListView: View {
    let games: [GameProgress]
    let onDetail: (GameProgress) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(games, id: \.id) { g in
                    GameTile(game: g)
                        .onTapGesture { onDetail(g) }
                }
            }
            .padding(.horizontal, DesignTokens.spacing)
            .padding(.vertical, DesignTokens.spacing)
        }
    }
}

private struct GameTile: View {
    let game: GameProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(DesignTokens.m4Yellow)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { idx in
                        Image(systemName: idx < game.bestScore ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundStyle(DesignTokens.m4Yellow)
                    }
                }
            }
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignTokens.ink)
            Text("已玩 \(game.totalPlays) 局")
                .font(.system(size: 11))
                .foregroundStyle(DesignTokens.inkSecondary)
        }
        .padding(DesignTokens.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(moduleColor: DesignTokens.m4Yellow)
    }

    private var title: String {
        switch game.gameKey {
        case "klotski": return "华容道"
        case "maze": return "迷宫滚球"
        case "2048": return "2048"
        case "oneline": return "一笔画"
        default: return game.gameKey
        }
    }
    private var icon: String {
        switch game.gameKey {
        case "klotski": return "square.grid.3x3.fill"
        case "maze": return "gyroscope"
        case "2048": return "number.square.fill"
        case "oneline": return "pencil.line"
        default: return "gamecontroller"
        }
    }
}

// MARK: - P2 成就
private struct GameBadgesView: View {
    let badges: [GameBadge]
    let onDetail: (GameBadge) -> Void
    let onSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacing) {
                HStack {
                    Text("勋章 · \(badges.filter { $0.isUnlocked }.count)/\(badges.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignTokens.inkSecondary)
                    Spacer()
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignTokens.m4Yellow)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)

                ForEach(badges, id: \.id) { b in
                    BadgeRow(badge: b)
                        .onTapGesture { onDetail(b) }
                }
            }
            .padding(.horizontal, DesignTokens.spacing)
            .padding(.vertical, DesignTokens.spacing)
        }
    }
}

private struct BadgeRow: View {
    let badge: GameBadge

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? DesignTokens.m4Yellow.opacity(0.2) : DesignTokens.bgSecondary)
                    .frame(width: 40, height: 40)
                Image(systemName: badge.isUnlocked ? "medal.fill" : "medal")
                    .font(.system(size: 17))
                    .foregroundStyle(badge.isUnlocked ? DesignTokens.m4Yellow : DesignTokens.inkSecondary.opacity(0.5))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(badge.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignTokens.ink)
                    if badge.isUnlocked {
                        Text("已解锁")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(DesignTokens.m4Yellow)
                            .clipShape(Capsule())
                    }
                }
                Text(badge.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.inkSecondary)
                    .lineLimit(1)
                if !badge.isUnlocked {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(DesignTokens.bgSecondary).frame(height: 4)
                            Capsule()
                                .fill(DesignTokens.m4Yellow)
                                .frame(width: geo.size.width * min(1, CGFloat(badge.progress) / CGFloat(max(1, badge.target))), height: 4)
                        }
                    }
                    .frame(height: 4)
                    Text("\(badge.progress) / \(badge.target)")
                        .font(.system(size: 9, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(DesignTokens.inkSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignTokens.inkSecondary.opacity(0.5))
        }
        .padding(DesignTokens.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(moduleColor: DesignTokens.m4Yellow)
    }
}
