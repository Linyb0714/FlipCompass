import SwiftUI
import UIKit

// MARK: - Hero 卡片生长转场（C1 共享基建 · 原型 heroOpen/restoreHero 转录）
// 机制：点击源卡 → 捕获其屏幕几何 → 白玻克隆卡从源位动画到全屏（240ms spring）
// → 到位后显示真正的二级页内容（克隆淡出）→ 返回时反向：内容淡出 + 克隆从全屏
// 缩回源位 + 源卡恢复显示（原路收回）。
//
// 与 sheet 的差别：空间连续性——二级页「从那张卡长出来」，返回「缩回那张卡」。
// 实现要点：全屏覆盖层挂在模块屏内部（不被 pager clipped 裁）；卡片几何用模块屏
// 本地坐标（覆盖层同空间，无安全区偏差）；源卡隐藏用环境 heroSourceID。

// MARK: - Hero 会话（标记当前生长目标：源卡标识 + 几何 + 所属页面标识）

struct HeroSession: Identifiable, Equatable {
    let id = UUID()
    /// 二级页种类（AppRootView 据此渲染目标页）
    let key: String
    /// 生长中需隐藏的源卡标识（列表内匹配；无需隐藏传 ""）
    let sourceID: String
    /// 源卡几何（模块屏本地坐标，覆盖层同空间）
    let sourceFrame: CGRect
}

// MARK: - 环境键：hero 生长中 → 列表内源卡自隐藏 + 二级页容器入场相位

private struct HeroSourceKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var heroSourceID: String? {
        get { self[HeroSourceKey.self] }
        set { self[HeroSourceKey.self] = newValue }
    }
}

// MARK: - 源卡几何上报（模块屏本地坐标 · 与覆盖层同空间）

struct HeroSpotKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// 上报自身 frame（模块屏命名空间「heroSpace」）供 hero 生长起点用；
    /// 生长期间源卡自动隐藏（heroSourceID 匹配 → opacity 0，收回后恢复）
    func heroSpot(id: String) -> some View {
        background(
            GeometryReader { g in
                Color.clear.preference(
                    key: HeroSpotKey.self,
                    value: [id: g.frame(in: .named("heroSpace"))]
                )
            }
        )
        .modifier(HeroSourceHide(id: id))
    }
}

/// 生长期间隐藏源卡（环境 heroSourceID == id → opacity 0）
private struct HeroSourceHide: ViewModifier {
    @Environment(\.heroSourceID) private var hiding
    let id: String
    func body(content: Content) -> some View {
        content
            .opacity(hiding == id ? 0 : 1)
            .allowsHitTesting(hiding == id ? false : true)
    }
}

// MARK: - Hero 覆盖层（模块屏内全屏挂载 · 两阶段动画编排）
//
// 阶段 A（打开，240ms）：克隆白卡从 sourceFrame 生长到全屏圆角 24；
// 阶段 B：内容页淡入（背景白 34%→tint 渐变，正文 fadeUp），克隆隐去；
// 返回（反向）：内容淡出 0.2s → 克隆从全屏 shrink 回 sourceFrame → 完毕回调
// （模块屏重置会话，源卡恢复显示）。

struct HeroOverlay<Content: View>: View {
    /// 当前会话（nil 由父级负责不渲染本层）
    let session: HeroSession
    /// 二级页 tint 底色（模块浅染）
    var tintColor: Color = DSToken.tintM1
    /// 返回触发（内容页返回按钮调用）→ 父级置 closing=true
    let onBack: () -> Void
    /// 完全收回完毕（模块屏重置会话，源卡恢复显示）
    let onClosed: () -> Void
    /// 关闭流程标志（父级持有：true = 内容淡出→克隆收回；驱动 onChange）
    var closing: Bool = false
    /// 目标页内容（尾随闭包，故声明在末尾；@ViewBuilder 支持 switch 多分支）
    @ViewBuilder let content: () -> Content

    /// 生长相位：false = 源卡位（克隆原样）· true = 全屏
    @State private var grown = false
    /// 内容显示（生长到位后）
    @State private var contentShown = false

    var body: some View {
        GeometryReader { geo in
            let full = CGRect(origin: .zero, size: geo.size)
            ZStack {
                // 克隆卡（白玻底 · 圆角插值 21→24）
                RoundedRectangle(cornerRadius: grown ? 24 : DSToken.rCard, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.white.opacity(0.98), .white.opacity(0.92)]),
                            startPoint: .init(x: 0.5, y: 0), endPoint: .init(x: 0.44, y: 1)
                        )
                    )
                    .shadow(color: .black.opacity(grown ? 0.12 : 0.05), radius: grown ? 2 : 1, y: 2)
                    .frame(
                        width: grown ? full.width : session.sourceFrame.width,
                        height: grown ? full.height : session.sourceFrame.height
                    )
                    .position(
                        x: grown ? full.midX : session.sourceFrame.midX,
                        y: grown ? full.midY : session.sourceFrame.midY
                    )

                // 内容页（生长到位淡入；closing 淡出）
                if contentShown {
                    content()
                        .background(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .white, location: 0),
                                    .init(color: .white, location: 0.34),
                                    .init(color: tintColor, location: 1),
                                ]),
                                startPoint: .init(x: 0.5, y: 0), endPoint: .init(x: 0.48, y: 1)
                            )
                            .ignoresSafeArea()
                        )
                        .opacity(closing ? 0 : 1)
                }

                // 需求①：左边缘右滑返回（iOS 系统同款 UIScreenEdgePanGestureRecognizer——
                // 只识别从边缘向内起手，与内容滚动/水平控件零冲突；M1/M2/M3 所有
                // hero 详情页经 HeroOverlay 统一获得，一处实现全局生效）
                EdgeSwipeBack(onBack: onBack)
                    .frame(width: 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .ignoresSafeArea()
            .allowsHitTesting(!(closing && !contentShown))
        }
        .onAppear {
            // 阶段 A：克隆生长
            withAnimation(DSToken.heroGrow) { grown = true }
            // 阶段 B：240ms 后内容淡入（卡屏修复③：打开 240ms 内就触发返回时，
            // 本定时器仍会把 contentShown 拉回 true 与收回流程竞态——closing 中跳过）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                guard !closing else { return }
                withAnimation(.easeOut(duration: 0.2)) { contentShown = true }
            }
        }
        .onChange(of: closing) { _, closingNow in
            guard closingNow else { return }
            // 返回：内容淡出 0.2s → 克隆收回 0.26s → 完毕
            withAnimation(.easeIn(duration: 0.2)) { contentShown = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(DSToken.heroGrow) { grown = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                    onClosed()
                }
            }
        }
    }
}

// MARK: - 内容页通用返回按钮（原型 .back-btn：‹ 模块名 · 左上角）
// C1 验收反馈：角标太小 → ‹ 21→29 / 标题 15→17，热区扩到 54pt 高（≥44pt 最小热区）

struct HeroBackButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text("‹")
                    .font(DSToken.body(29, weight: .medium))
                    .offset(y: -2)   // ‹ 字形基线偏高，视觉居中微调
                Text(title)
                    .font(DSToken.body(17, weight: .semibold))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 46)
        .padding(.leading, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - 需求① · 左边缘右滑返回（系统边缘手势包装）
// UIScreenEdgePanGestureRecognizer 只在「从左边缘 ~20pt 向内」起手时识别，
// 列表垂直滚动、d7 价格 slider 等内容手势完全不受影响；向内拖过 44pt
// 即触发 onBack 原路收回（拖到位即走，贴近系统 pop 手感）。

struct EdgeSwipeBack: UIViewRepresentable {
    let onBack: () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        let rec = UIScreenEdgePanGestureRecognizer(target: context.coordinator,
                                                   action: #selector(Coordinator.handle(_:)))
        rec.edges = .left
        v.addGestureRecognizer(rec)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onBack = onBack
    }

    func makeCoordinator() -> Coordinator { Coordinator(onBack: onBack) }

    final class Coordinator: NSObject {
        var onBack: () -> Void
        init(onBack: @escaping () -> Void) { self.onBack = onBack }

        @objc func handle(_ rec: UIScreenEdgePanGestureRecognizer) {
            let t = rec.translation(in: rec.view)
            switch rec.state {
            case .changed:
                // 卡屏修复①：边缘起手后转为垂直意图 → 主动让位 ScrollView
                //（禁用本次识别，下一 runloop 恢复，避免列表滚动被劫持的「卡住」感）
                if abs(t.y) > abs(t.x) {
                    rec.isEnabled = false
                    DispatchQueue.main.async { rec.isEnabled = true }
                }
            case .ended:
                // 卡屏修复②：手势完整结束才判定返回（中断 .cancelled 不触发）——
                // 旧实现 .changed 过阈值即走，拖动被打断时返回动画起了一半，
                // 造成「返回卡屏」；改为松手判定后中断场景页面保持原样。
                if t.x > 44, abs(t.y) < 80 {
                    onBack()   // heroClosing 幂等：重复回调无副作用
                }
            default:
                break
            }
        }
    }
}