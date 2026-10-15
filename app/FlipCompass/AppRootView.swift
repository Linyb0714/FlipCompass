import SwiftUI

// MARK: - 根视图：层容器 + 方位入场转场（V0.2.1）
// L0 待机 ↔ L1 模块；转场 = 渐显 + 方位滑入（46% 滑距 · bounce 曲线自带到位回弹）：
// M1 自上 / M2 自下 / M3 自左 / M4 自右；模块直切（翻转 / 二次导航）同用。
// R8 四向翻转：MotionKit 四态引擎 confirmed 事件 → AppState 映射模块。

struct AppRootView: View {
    @Environment(AppState.self) private var app
    @StateObject private var motion = MotionKit()

    // B1i：模块字飞行（色卡 ↔ 模块头图标，进入/返回元素传承）
    @State private var cardCenters: [ModuleKey: CGPoint] = [:]
    @State private var iconCenters: [ModuleKey: CGPoint] = [:]
    @State private var flight: GlyphFlight? = nil

    struct GlyphFlight: Identifiable {
        let id = UUID()
        let module: ModuleKey
        /// true = 进入（色卡形态→图标形态）；false = 返回（图标形态→色卡形态）
        let entering: Bool
        let fromProvider: () -> CGPoint
        let toProvider: () -> CGPoint
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                IdleScreen(
                    onEnterModule: { app.enterModule($0) },
                    tickerPaused: app.level != .idle,      // V0.2.2 ①：非待机自动暂停轮播
                    sheenPaused: app.level != .idle,       // 非待机暂停色卡流光（页面被覆盖）
                    sheenRestartModule: app.lastExitedModule,   // V0.3.3：返回待机流光重置
                    sheenRestartStamp: app.idleRestartStamp
                )
                .zIndex(0)

                if app.level == .module, let key = app.module {
                    // B1~B4：四模块一级目录全部落地（M1 打卡 / M2 想法 / M3 情报 / M4 游戏）
                    Group {
                        if key == .m1 {
                            M1Screen()
                        } else if key == .m2 {
                            M2Screen()
                        } else if key == .m3 {
                            M3Screen()
                        } else {
                            M4Screen()
                        }
                    }
                    .zIndex(1)
                    .transition(
                        .modifier(
                            active: DirectionalTransition(module: key, size: geo.size, progress: 0),
                            identity: DirectionalTransition(module: key, size: geo.size, progress: 1)
                        )
                    )
                }

                // 字飞行层（最顶；与方位滑入同时进行）
                if let f = flight {
                    FlightGlyphView(module: f.module, entering: f.entering,
                                    fromProvider: f.fromProvider,
                                    toProvider: f.toProvider) {
                        flight = nil
                    }
                    .zIndex(2)
                }
            }
            .onPreferenceChange(CardSpotKey.self) { cardCenters = $0 }
            .onPreferenceChange(IconSpotKey.self) { iconCenters = $0 }
            // rootSpace：飞行层坐标系（与上报同空间，消除安全区偏差）
            .coordinateSpace(name: "rootSpace")
            // B1j：字飞行目标模块（飞行中隐藏目标处原始元素，到位后再显示）
            .environment(\.flightTargetModule, flight?.module)
        }
        .animation(DSToken.enterBounce, value: app.screenID)
        .task { motion.start() }
        .onDisappear { motion.stop() }
        // DEBUG 后门：模拟器验证用（-show-m1 [-m1-page 0/1/2] / -show-m2 [-m2-page 0/1]）直达指定模块分组
        // 延迟 1s：等 IdleScreen 色卡坐标上报完成（字飞行验证需要真实点击路径的时序）
        .onAppear {
            if CommandLine.arguments.contains("-show-m1") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    app.enterModule(.m1)
                }
            }
            if CommandLine.arguments.contains("-show-m2") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    app.enterModule(.m2)
                }
            }
            if CommandLine.arguments.contains("-show-m3") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    app.enterModule(.m3)
                }
            }
            if CommandLine.arguments.contains("-show-m4") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    app.enterModule(.m4)
                }
            }
        }
        // B1i：模块字飞行（通知驱动，进入/返回全覆盖：色卡点击/翻转/双击返回/平放）
        .onReceive(NotificationCenter.default.publisher(for: .moduleFlight)) { note in
            guard let raw = note.userInfo?["module"] as? String,
                  let key = ModuleKey(rawValue: raw),
                  let enter = note.userInfo?["enter"] as? Bool else { return }
            // 坐标实时解析（rootSpace；fallback：模块头图标 (56,81) / 待机色卡 (215,219)）
            flight = GlyphFlight(
                module: key,
                entering: enter,
                fromProvider: {
                    enter
                        ? (self.cardCenters[key] ?? CGPoint(x: 215, y: 219))
                        : (self.iconCenters[key] ?? CGPoint(x: 56, y: 81))
                },
                toProvider: {
                    enter
                        ? (self.iconCenters[key] ?? CGPoint(x: 56, y: 81))
                        : (self.cardCenters[key] ?? CGPoint(x: 215, y: 219))
                }
            )
        }
        // R8：方向事件确认（本期只启用「上」→ M1；平放收拢；其余忽略）
        .onReceive(NotificationCenter.default.publisher(for: .motionStateChange)) { note in
            guard let next = note.userInfo?["next"] as? String, next == "confirmed" else { return }
            app.handleFlipEvent(direction: motion.confirmedDirection, orientation: motion.confirmedOrientation)
        }
    }
}

// MARK: - 字飞行视图（B1j：形态 morph——色卡形态 ⇌ 模块头图标形态）
// 进入：起点 = 色卡形态（玻璃小卡 + 模块色小字 + 标签），飞行中渐变为图标形态（橙渐变块 + 白字）
// 返回：反向（图标形态 → morph 回色卡形态落位）

private struct FlightGlyphView: View {
    let module: ModuleKey
    let entering: Bool
    /// 起点/终点实时解析（rootSpace，preference 异步上报自动校正）
    let fromProvider: () -> CGPoint
    let toProvider: () -> CGPoint
    let onDone: () -> Void

    @State private var progress: CGFloat = 0

    /// 图标形态强度（0 = 纯色卡形态 · 1 = 纯图标形态）
    private var iconAmount: CGFloat {
        entering ? progress : 1 - progress
    }

    var body: some View {
        let from = fromProvider()
        let to = toProvider()
        let pos = CGPoint(
            x: from.x + (to.x - from.x) * progress,
            y: from.y + (to.y - from.y) * progress
        )
        let icon = iconAmount
        // 尺寸/圆角插值：色卡形态（52×42 · 圆角 13）→ 图标形态（46×46 · 圆角 14）
        let w = 46 + 6 * (1 - icon)
        let h = 46 - 4 * (1 - icon)
        let r = 13 + 1 * icon

        ZStack {
            // 底色层：玻璃（色卡）⇌ 橙渐变（图标）交叉
            ZStack {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.white.opacity(0.74), .white.opacity(0.36)]),
                            startPoint: UnitPoint(x: 0.5, y: 0), endPoint: .init(x: 0.42, y: 1)
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.82), lineWidth: 1)
                    )
                    .opacity(1 - icon)
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [module.color.opacity(0.87), module.color]),
                            startPoint: UnitPoint(x: 0.18, y: 0), endPoint: .init(x: 1, y: 0.85)
                        )
                    )
                    .opacity(icon)
            }
            // 阴影：玻璃柔影 ⇌ 橙色发光
            .shadow(color: module.color.opacity(0.45 * icon), radius: 14)
            .shadow(color: .black.opacity(0.18 * icon), radius: 6, y: 4)
            .shadow(color: .black.opacity(0.12 * (1 - icon)), radius: 8, y: 5)

            // 字：彩色 ⇌ 白色交叉 + 字号 17→22 插值
            ZStack {
                Text(module.glyph)
                    .font(DSToken.body(17 + 5 * icon, weight: .semibold))
                    .foregroundStyle(module.color)
                    .opacity(1 - icon)
                Text(module.glyph)
                    .font(DSToken.body(17 + 5 * icon, weight: .semibold))
                    .foregroundStyle(.white)
                    .opacity(icon)
            }
            .shadow(color: module.color.opacity(0.55 * (1 - icon)), radius: 5.5)

            // 色卡标签（图标形态渐隐）
            Text(module.chipLabel)
                .font(DSToken.body(8, weight: .medium))
                .foregroundStyle(Color(red: 0x7c / 255, green: 0x7c / 255, blue: 0x82 / 255))
                .tracking(1)
                .opacity(1 - icon)
                .offset(y: 11)
        }
        .frame(width: w, height: h)
        .position(pos)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(DSToken.springSlow) { progress = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) { onDone() }
        }
    }
}

// MARK: - 方位转场（progress：0 = 方位外（入场前）· 1 = 就位）
// 进入 = 自各自方位滑入 46% + 渐显；bounce 曲线的贝塞尔超调天然产生「到位轻回弹」；
// 移除反向驱动 = 朝自己方向滑出。

private struct DirectionalTransition: ViewModifier {
    let module: ModuleKey
    let size: CGSize
    let progress: Double

    private var offset: CGSize {
        let hidden: CGPoint
        switch module {
        case .m1: hidden = CGPoint(x: 0, y: -0.46 * size.height)   // M1 自上
        case .m2: hidden = CGPoint(x: 0, y: 0.46 * size.height)    // M2 自下
        case .m3: hidden = CGPoint(x: -0.46 * size.width, y: 0)    // M3 自左
        case .m4: hidden = CGPoint(x: 0.46 * size.width, y: 0)     // M4 自右
        }
        return CGSize(width: hidden.x * (1 - progress), height: hidden.y * (1 - progress))
    }

    func body(content: Content) -> some View {
        content
            .offset(offset)
            .opacity(progress)
    }
}
