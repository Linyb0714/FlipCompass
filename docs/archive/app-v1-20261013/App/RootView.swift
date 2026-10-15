import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state
    @EnvironmentObject private var motionKit: MotionKit

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            switch state.level {
            case .idle:
                IdleView()
                    .transition(.opacity)
            case .module:
                if let module = state.currentModule {
                    ModuleScreen(module: module)
                        .transition(.opacity)
                }
            case .detail:
                DetailContainerView()
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.46, dampingFraction: 0.78), value: state.level)
        .animation(.spring(response: 0.46, dampingFraction: 0.78), value: state.currentModule)
    }
}

#Preview {
    RootView()
        .environment(AppState())
        .environmentObject(MotionKit(preview: true))
}
