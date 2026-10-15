import SwiftUI
import SwiftData

/// 一级模块目录屏（L1）
/// 四模块共用骨架：方位入场 + 头部统计胶囊 + 焦点卡 + 分组页 + 边缘水印
struct ModuleScreen: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext
    let module: ModuleKey
    @State private var selection: Int = 0
    @State private var page: Int = 0
    @State private var headerValue: String = ""

    private var fromEdgeTransition: AnyTransition {
        switch module {
        case .checkIn: return .move(edge: .top).combined(with: .opacity)
        case .thought: return .move(edge: .bottom).combined(with: .opacity)
        case .hub: return .move(edge: .leading).combined(with: .opacity)
        case .game: return .move(edge: .trailing).combined(with: .opacity)
        }
    }

    var body: some View {
        ZStack {
            DesignTokens.bgPrimary.ignoresSafeArea()
            LinearGradient(
                colors: [Color.white, module.themeColor.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                content
            }
            .padding(.horizontal, 12)
        }
        .transition(fromEdgeTransition)
        .gesture(horizontalSwipe)
        .gesture(verticalSwipe)
        .task { refreshHeader() }
        .onChange(of: state.level) { refreshHeader() }
    }

    // MARK: - 头部
    private var header: some View {
        HStack(spacing: 8) {
            Circle().fill(module.themeColor).frame(width: 8, height: 8)
                .shadow(color: module.themeColor.opacity(0.6), radius: 4)
            Text(module.displayName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DesignTokens.ink)
            Spacer()
            HeaderChip(module: module, label: headerLabel, value: headerValue)
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var headerLabel: String {
        switch module {
        case .checkIn: return "今日"
        case .thought: return "今天"
        case .hub: return "今日"
        case .game: return "三星"
        }
    }

    // V0.4.2~V0.4.4：头部胶囊实算（替代硬编码）
    private func refreshHeader() {
        let cal = Calendar.current
        switch module {
        case .checkIn:
            let cp = CheckInProvider(context: modelContext)
            let items = (try? cp.todayItems()) ?? []
            let done = cp.todayDoneCount(items)
            headerValue = "\(done)/\(items.count)"
        case .thought:
            let tp = ThoughtProvider(context: modelContext)
            let today = (try? tp.today()) ?? []
            let dp = DraftProvider(context: modelContext)
            let drafts = (try? dp.drafts(module: "thought", page: "compose")) ?? []
            if !drafts.isEmpty {
                headerValue = "\(today.count) 条 · 草稿中"
            } else {
                headerValue = "\(today.count) 条"
            }
        case .hub:
            let hp = HubProvider(context: modelContext)
            let feeds = (try? hp.collections()) ?? []
            let today = feeds.filter { cal.isDateInToday($0.createdAt) }
            headerValue = "\(today.count) 条"
        case .game:
            let gp = GameProvider(context: modelContext)
            let records = (try? gp.records()) ?? []
            let threeStar = records.filter { $0.stars >= 3 }.count
            headerValue = "\(threeStar) 局"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch module {
        case .checkIn:
            CheckInRootView()
        case .thought:
            ThoughtRootView()
        case .hub:
            HubRootView()
        case .game:
            GameRootView()
        }
    }

    private var horizontalSwipe: some Gesture {
        DragGesture()
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy), abs(dx) > 50 {
                    // 左右滑切分组
                    state.switchPage(dx > 0 ? -1 : 1, pageCount: 3)
                }
            }
    }

    private var verticalSwipe: some Gesture {
        DragGesture()
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dy) > abs(dx), abs(dy) > 50 {
                    // 上下滑选条目
                    let current = state.moduleSelection[module] ?? 0
                    state.selectItem(max(0, current + (dy < 0 ? 1 : -1)))
                }
            }
    }
}

struct HeaderChip: View {
    let module: ModuleKey
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(DesignTokens.inkSecondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.thinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(module.themeColor.opacity(0.2), lineWidth: 0.5))
    }
}

#Preview {
    ModuleScreen(module: .checkIn)
        .environment(AppState())
        .environmentObject(MotionKit(preview: true))
}
