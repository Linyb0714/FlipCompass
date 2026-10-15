import SwiftUI
import SwiftData

@main
struct FlipCompassApp: App {
    @State private var appState = AppState()

    /// B1：M1（CheckInItem + CheckInRecord）；B2：M2（Thought + Draft）；
    /// B3：M3（FeedItem + CouponCard + Preference）；B4：M4（GameProgress）
    /// C5+：M3（RssSource 情报订阅源）；容器改共享单例（AppIntents 写库互通，方案②）
    let container: ModelContainer = AppModelContainer.shared

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(appState)
                .modelContainer(container)
        }
    }
}
