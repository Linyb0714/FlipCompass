import SwiftUI

/// 二级容器：根据 detailStack 顶层路由渲染对应二级页（L2 多级页面栈）
struct DetailContainerView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            if let route = state.detailStack.last {
                DetailRouterView(route: route)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 60 {
                        // 右滑返回上一级
                        state.backOneLevel()
                    }
                }
        )
    }
}

struct DetailRouterView: View {
    let route: DetailRoute

    var body: some View {
        switch route.module {
        case .checkIn:
            switch route.pageKey {
            case "detail": CheckInDetailView(itemID: route.itemID)
            case "edit": CheckInEditView(itemID: route.itemID)
            default: PlaceholderDetail(title: "未知页 \(route.pageKey)")
            }
        case .thought:
            switch route.pageKey {
            case "compose": ThoughtComposeView(editingThoughtID: nil)
            case "drafts": ThoughtComposeView(editingThoughtID: nil)  // d2 双子页（切到草稿箱 tab 由内部状态管）
            case "detail": ThoughtDetailView(itemID: route.itemID)
            case "edit": ThoughtComposeView(editingThoughtID: route.itemID)
            default: PlaceholderDetail(title: "未知页 \(route.pageKey)")
            }
        case .hub:
            switch route.pageKey {
            case "coupon": CouponDetailView(itemID: route.itemID)
            case "feed": FeedDetailView(itemID: route.itemID)
            case "preference": HubPreferenceEditView()
            default: PlaceholderDetail(title: "未知页 \(route.pageKey)")
            }
        case .game:
            switch route.pageKey {
            case "records": GameRecordsView()
            case "gameStats": GameStatsView(itemID: route.itemID)
            case "badge": GameBadgeDetailView(itemID: route.itemID)
            case "settings": GameSettingsView()
            default: PlaceholderDetail(title: "未知页 \(route.pageKey)")
            }
        }
    }
}

struct PlaceholderDetail: View {
    let title: String
    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.headline)
            Text("将在 0.4 后续版本跟进")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
