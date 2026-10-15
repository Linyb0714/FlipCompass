import SwiftUI
import SwiftData

/// M2 今天的想法 根视图（V0.4.3）
/// 分组页：P0 今日（记录一条大卡片 + 想法流） / P1 月视图（按月归档）
struct ThoughtRootView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext
    @State private var pageIndex: Int = 0
    @State private var items: [Thought] = []
    @State private var draftCount: Int = 0
    @State private var latestDraftAt: Date? = nil
    @State private var toast: Toast?
    @State private var monthAnchor: Date = .now

    private let pages = ["今日", "回顾"]

    var body: some View {
        VStack(spacing: 0) {
            tabs
            ZStack {
                switch pageIndex {
                case 0: ThoughtTodayView(
                    items: items,
                    draftCount: draftCount,
                    latestDraftAt: latestDraftAt,
                    onCompose: { openCompose() },
                    onOpenDrafts: { openDraftList() },
                    onDetail: { t in openDetail(t) }
                )
                default: ThoughtMonthView(anchor: monthAnchor, items: items)
                }
            }
            .padding(.top, 4)
        }
        .overlay(alignment: .bottom) {
            if let toast { ToastView(toast: toast).padding(.bottom, 32) }
        }
        .task { refresh() }
        .onChange(of: state.level) { refresh() }
    }

    private var tabs: some View {
        HStack(spacing: 7) {
            ForEach(Array(pages.enumerated()), id: \.0) { idx, title in
                Text(title)
                    .font(.system(size: 13, weight: idx == pageIndex ? .semibold : .regular))
                    .foregroundStyle(idx == pageIndex ? DesignTokens.ink : DesignTokens.inkSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(idx == pageIndex ? DesignTokens.m2Purple.opacity(0.16) : Color.clear)
                    .clipShape(Capsule())
                    .onTapGesture {
                        withAnimation(DesignTokens.springEase) { pageIndex = idx }
                        if idx == 1 { monthAnchor = .now }
                    }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 7)
    }

    // MARK: - 二级页导航
    private func openCompose() {
        state.enterDetail(DetailRoute(module: .thought, pageKey: "compose", itemID: nil))
    }
    private func openDraftList() {
        state.enterDetail(DetailRoute(module: .thought, pageKey: "drafts", itemID: nil))
    }
    private func openDetail(_ t: Thought) {
        state.enterDetail(DetailRoute(module: .thought, pageKey: "detail", itemID: t.id.uuidString))
    }

    private func refresh() {
        let tp = ThoughtProvider(context: modelContext)
        let dp = DraftProvider(context: modelContext)
        let cal = Calendar.current
        let isMonthView = pageIndex == 1
        if isMonthView {
            let y = cal.component(.year, from: monthAnchor)
            let m = cal.component(.month, from: monthAnchor)
            items = (try? tp.inMonth(year: y, month: m)) ?? []
        } else {
            items = (try? tp.today()) ?? []
        }
        let drafts = (try? dp.drafts(module: "thought", page: "compose")) ?? []
        draftCount = drafts.count
        latestDraftAt = drafts.first?.updatedAt
    }
}

// MARK: - P0 今日视图
private struct ThoughtTodayView: View {
    let items: [Thought]
    let draftCount: Int
    let latestDraftAt: Date?
    let onCompose: () -> Void
    let onOpenDrafts: () -> Void
    let onDetail: (Thought) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacing) {
                composeCard
                ForEach(items, id: \.id) { t in
                    ThoughtRow(thought: t)
                        .onTapGesture { onDetail(t) }
                }
                if items.isEmpty { emptyState }
            }
            .padding(.horizontal, DesignTokens.spacing)
            .padding(.vertical, DesignTokens.spacing)
        }
    }

    private var composeCard: some View {
        Button(action: onCompose) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("记录一条")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DesignTokens.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignTokens.inkSecondary)
                }
                Text(composeSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignTokens.inkSecondary)
                if draftCount > 0 {
                    Button(action: onOpenDrafts) {
                        HStack(spacing: 5) {
                            Circle().fill(DesignTokens.m2Purple).frame(width: 6, height: 6)
                            Text("草稿箱 · \(draftCount) 条")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(DesignTokens.m2Purple)
                        }
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(DesignTokens.m2Purple.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignTokens.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .glassCard(moduleColor: DesignTokens.m2Purple)
    }

    private var composeSubtitle: String {
        if draftCount > 0, let at = latestDraftAt {
            let f = DateFormatter(); f.dateFormat = "MM-dd"
            return "有草稿 \(draftCount) 条 · 上次 \(f.string(from: at))"
        }
        return "写一句就好 · 写一半也没关系"
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "lightbulb")
                .font(.system(size: 30))
                .foregroundStyle(DesignTokens.m2Purple.opacity(0.4))
            Text("今天还没留下想法")
                .font(.system(size: 14))
                .foregroundStyle(DesignTokens.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

private struct ThoughtRow: View {
    let thought: Thought

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(thought.content)
                    .font(.system(size: 15))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let mood = thought.mood, !mood.isEmpty {
                        Text(mood)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DesignTokens.m2Purple)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(DesignTokens.m2Purple.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text(timeString)
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.inkSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignTokens.inkSecondary.opacity(0.5))
        }
        .padding(DesignTokens.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: DesignTokens.hRow)
        .glassCard(moduleColor: DesignTokens.m2Purple)
    }

    private var timeString: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: thought.createdAt)
    }
}

// MARK: - P1 月视图
private struct ThoughtMonthView: View {
    let anchor: Date
    let items: [Thought]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacing) {
                HStack {
                    Text(monthTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignTokens.ink)
                    Spacer()
                    Text("\(items.count) 条")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignTokens.inkSecondary)
                }
                .padding(.horizontal, 4)

                if items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 28))
                            .foregroundStyle(DesignTokens.m2Purple.opacity(0.4))
                        Text("这个月还没留下想法")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignTokens.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(items, id: \.id) { t in
                        HStack(alignment: .top, spacing: 12) {
                            Text(dayString(t.createdAt))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(DesignTokens.m2Purple)
                                .frame(width: 34, alignment: .leading)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(t.content)
                                    .font(.system(size: 14))
                                    .foregroundStyle(DesignTokens.ink)
                                    .lineLimit(2)
                                if let mood = t.mood, !mood.isEmpty {
                                    Text(mood)
                                        .font(.system(size: 11))
                                        .foregroundStyle(DesignTokens.inkSecondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(DesignTokens.spacing)
                        .glassCard(moduleColor: DesignTokens.m2Purple)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacing)
            .padding(.vertical, DesignTokens.spacing)
        }
    }

    private var monthTitle: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月"
        return f.string(from: anchor)
    }

    private func dayString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "dd"
        return f.string(from: d)
    }
}
