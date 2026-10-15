import SwiftUI
import UIKit

// MARK: - 罗盘（待机屏中段 · V0.2.4 按位定位模式互斥 + v0.9 幽灵回声）
//
// 三层旋转承载（B1p 重构，全部 TimelineView 时间累加驱动，拖动/状态变更不停摆）：
//   ticks-spin（刻度环 150s 慢转；转环按住时轻自转不停，与手转角度叠加）
//   ring-spin（轨迹环 + 环带游标，转环跟手；环是正圆转不动看不出来——由游标呈现滚动量）
//   轨迹双弧（环内两道截取弧：长细 156 顺时针 42s + 短粗 130 逆时针 26s，反向差速；
//     转环按住 → 收拢圆心 + 渐隐 + 相位冻结；松手 → 回各自轨道、从冻结相位无缝续转）
//
// 模式互斥（down 时锁定，V0.2.4）：
//   · 按住环带（半径 65~118）→ 转环解压：两层跟手滚动、环激活态（加深加粗+外光晕+停呼吸）、
//     游标浮现、每跨 15° 涟漪脉冲 + 轻震（hard 触觉）、松手停位保持（不回弹）
//   · 其他区域 → 指针球交互：跟手 + 方向模块色预示发光 + 幽灵回声拖尾（v0.9：
//     球经过处渐隐残影 0.5s）、快速大幅滑动（>100）= 向该方位导航进入模块
//
// 几何：刻度环 240×240；轨迹环 180；色卡距圆心 145（内缘 ~123，不遮 tick 带 111 内）；
//       容器 356×356（中心 = (178, 178)）。

struct IdleCompass: View {
    let onEnterModule: (ModuleKey) -> Void
    /// 非待机（进入模块）时暂停流光（节能；页面被覆盖）
    var paused: Bool = false
    /// 返回待机的流光重置（V0.3.3：从模块返回时，返回模块那只色卡 0s 立即扫光，其余顺时针错峰）
    var sheenRestartModule: ModuleKey? = nil
    var sheenRestartStamp: UUID? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum DragMode { case none, ball, ring }

    // 旋转层状态
    @State private var ringDragAngle: Double = 0  // 转环跟手累计角（即时值，松手保持）
    @State private var lastRingAngle: Double = 0
    @State private var ringLive = false
    @State private var lastTickSlot = 0
    @State private var tickPulseID = 0
    // 指针球状态
    @State private var dotOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var previewColor: Color = .clear
    // 幽灵回声（拖尾残影）
    @State private var echoes: [GhostEcho] = []

    @State private var dragMode: DragMode = .none

    private let ringOuter: CGFloat = 240
    private let trackRing: CGFloat = 180
    private let chipDistance: CGFloat = 145
    private let dotMaxRadius: CGFloat = 96
    /// ⚠️ 容器必须完整包含四卡（距 145 + 卡体半宽/半高 ≈33 → 半边 ≥178）：
    /// position() 溢出父 frame 的子视图命中测试会被父 bounds 裁剪——
    /// 旧容器 240×300 时左右卡仅 ~8% 点击区在界内（左右进不了的 bug），上下卡仅小溢出放能点
    private let containerSide: CGFloat = 356
    private var center: CGPoint { CGPoint(x: containerSide / 2, y: containerSide / 2) }

    private let haptic = UIImpactFeedbackGenerator(style: .rigid)

    var body: some View {
        ZStack {
            // ---- 刻度环（24 格 × 15°· 150s 轻自转 + 转环跟手叠加）----
            // B1p：自转改 TimelineView 驱动（真机反馈：旧 repeatForever 转环按住即停摆）；
            // 转环期间轻自转不停，跟手角照常叠加
            TickDialSpin(strong: ringLive, dragAngle: ringDragAngle,
                         paused: paused, reduceMotion: reduceMotion)
                .frame(width: ringOuter, height: ringOuter)

            // ---- 轨迹环（B1r：静止几何描边，无呼吸动画——轻动画只保留刻度环慢转 + 圆内双弧；
            //      转环激活：加深加粗 + 外光晕，样式切换仅瞬时过渡 0.2s）----
            Circle()
                .strokeBorder(
                    Color(red: 0.345, green: 0.345, blue: 0.404).opacity(ringLive ? 0.5 : 0.28),
                    lineWidth: ringLive ? 3 : 2.5
                )
                .frame(width: trackRing, height: trackRing)
                .shadow(
                    color: ringLive ? Color(red: 0.24, green: 0.24, blue: 0.27).opacity(0.16) : .clear,
                    radius: 10
                )
                .animation(.easeInOut(duration: 0.2), value: ringLive)

            // ---- 轨迹双弧（B1q：紧贴 180 轨迹环内侧 · 反向差速 · 四色卡同系半透明）----
            // 长细弧 = 橙（心卡）：贴环内侧 4pt（176 轨道）· 2pt 细 · 28% 环周 · 顺时针 42s
            // 短粗弧 = 绿（知卡）：再内 10pt（170 轨道）· 4pt 粗 · 16% 环周 · 逆时针 26s。
            // 转环时贴环愈合消失（scale 到 180）+ 渐隐；松手回轨续转
            OrbitArc(diameter: trackRing - 4, lineWidth: 2,
                     trimStart: 0.05, trimEnd: 0.33,
                     opacity: 0.40, tint: DSToken.m1, collapseTo: trackRing,
                     direction: 1, period: 42, phase: 0,
                     collapsed: ringLive, paused: paused, reduceMotion: reduceMotion)
            OrbitArc(diameter: trackRing - 10, lineWidth: 4,
                     trimStart: 0.52, trimEnd: 0.68,
                     opacity: 0.35, tint: DSToken.m3, collapseTo: trackRing,
                     direction: -1, period: 26, phase: 145,
                     collapsed: ringLive, paused: paused, reduceMotion: reduceMotion)
            ZStack {
                Circle()
                    .fill(Color(red: 0.235, green: 0.235, blue: 0.263))
                    .frame(width: 7, height: 7)
                    .offset(y: -trackRing / 2)
                if tickPulseID > 0 {
                    TickRipple()
                        .offset(y: -trackRing / 2)
                        .id(tickPulseID)   // 重建播放一次脉冲
                }
            }
            .rotationEffect(.degrees(ringDragAngle))
            .opacity(ringLive ? 0.7 : 0)
            .scaleEffect(ringLive ? 1 : 0.4)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: ringLive)

            // ---- 幽灵回声拖尾（ball 模式，渐隐残影）----
            ForEach(echoes) { echo in
                EchoDot(echo: echo)
            }

            // ---- 四向液态玻璃色卡（前 M1 / 后 M2 / 左 M3 / 右 M4；流光 6.5s 轮流 + 返回重置）----
            CompassChip(module: .m1, position: .up, distance: chipDistance, center: center,
                        paused: paused, restartModule: sheenRestartModule, restartStamp: sheenRestartStamp) { onEnterModule(.m1) }
            CompassChip(module: .m2, position: .down, distance: chipDistance, center: center,
                        paused: paused, restartModule: sheenRestartModule, restartStamp: sheenRestartStamp) { onEnterModule(.m2) }
            CompassChip(module: .m3, position: .left, distance: chipDistance, center: center,
                        paused: paused, restartModule: sheenRestartModule, restartStamp: sheenRestartStamp) { onEnterModule(.m3) }
            CompassChip(module: .m4, position: .right, distance: chipDistance, center: center,
                        paused: paused, restartModule: sheenRestartModule, restartStamp: sheenRestartStamp) { onEnterModule(.m4) }

            // ---- 圆心幽灵指针球（转环时静止呼吸，不受转环影响）----
            GhostDot(
                offset: dotOffset,
                glowColor: isDragging ? previewColor : .clear,
                resting: !isDragging && !reduceMotion
            )
        }
        .frame(width: containerSide, height: containerSide)
        .contentShape(Rectangle())
        .gesture(dragGesture)
    }

    // MARK: - 手势（模式互斥：down 位置判定，一次拖动锁定一种模式）

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragMode == .none {
                    dragMode = classify(value.startLocation)
                    if dragMode == .ring {
                        ringLive = true
                        lastRingAngle = angleAt(value.location)
                        lastTickSlot = Int(floor(ringDragAngle / 15))
                        haptic.prepare()
                    }
                }
                switch dragMode {
                case .ring:
                    let a = angleAt(value.location)
                    var delta = a - lastRingAngle
                    if delta > 180 { delta -= 360 }
                    if delta < -180 { delta += 360 }
                    ringDragAngle += delta
                    lastRingAngle = a
                    // 每 15° 一档：涟漪 + 轻震
                    let slot = Int(floor(ringDragAngle / 15))
                    if slot != lastTickSlot {
                        lastTickSlot = slot
                        tickPulseID += 1
                        if !reduceMotion { haptic.impactOccurred() }
                    }
                case .ball:
                    isDragging = true
                    let clamped = clampToRadius(value.translation, maxRadius: dotMaxRadius)
                    dotOffset = clamped
                    previewColor = nearestModuleColor(for: clamped)
                    spawnEcho(at: clamped)
                case .none:
                    break
                }
            }
            .onEnded { value in
                switch dragMode {
                case .ring:
                    ringLive = false   // 游标/激活样式淡出；ringDragAngle 保持（停位保持）
                case .ball:
                    let t = value.translation
                    if hypot(t.width, t.height) > 100, let key = nearestModule(for: t) {
                        // 快速大幅滑动 = 向该方位导航
                        dotOffset = .zero
                        isDragging = false
                        previewColor = .clear
                        onEnterModule(key)
                    } else {
                        // 松手弹回圆心（bounce .34s）
                        withAnimation(DSToken.bounceQuick) {
                            dotOffset = .zero
                        }
                        isDragging = false
                        previewColor = .clear
                    }
                case .none:
                    break
                }
                dragMode = .none
            }
    }

    // MARK: - 模式判定与几何

    /// 按下位置 → 交互模式：环带（半径 65~118）= 转环；其他 = 指针球
    private func classify(_ start: CGPoint) -> DragMode {
        let r = hypot(start.x - center.x, start.y - center.y)
        return (r >= 65 && r <= 118) ? .ring : .ball
    }

    private func angleAt(_ p: CGPoint) -> Double {
        atan2(p.y - center.y, p.x - center.x) * 180 / Double.pi
    }

    private func clampToRadius(_ size: CGSize, maxRadius: CGFloat) -> CGSize {
        let d = hypot(size.width, size.height)
        guard d > maxRadius, d > 0 else { return size }
        let ratio = maxRadius / d
        return CGSize(width: size.width * ratio, height: size.height * ratio)
    }

    /// 屏幕方向 → 方位模块（上 M1 / 下 M2 / 左 M3 / 右 M4）
    private func nearestModule(for translation: CGSize) -> ModuleKey? {
        guard hypot(translation.width, translation.height) > 24 else { return nil }
        let dx = translation.width, dy = translation.height
        if abs(dy) >= abs(dx) {
            return dy < 0 ? .m1 : .m2
        } else {
            return dx < 0 ? .m3 : .m4
        }
    }

    private func nearestModuleColor(for translation: CGSize) -> Color {
        guard let key = nearestModule(for: translation) else {
            return Color(red: 0.345, green: 0.345, blue: 0.404).opacity(0.25)
        }
        return key.color
    }

    /// 幽灵回声：距上一枚 >10pt 才落一枚，0.62s 后清数据（视觉 0.5s 渐隐已完）
    private func spawnEcho(at pos: CGSize) {
        if let last = echoes.last,
           hypot(pos.width - last.x, pos.height - last.y) < 10 { return }
        guard echoes.count < 24 else { return }
        let echo = GhostEcho(x: pos.width, y: pos.height, color: previewColor == .clear
                             ? Color(red: 0.345, green: 0.345, blue: 0.404).opacity(0.4)
                             : previewColor)
        echoes.append(echo)
        let id = echo.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            echoes.removeAll { $0.id == id }
        }
    }
}

// MARK: - 刻度盘（每 15° 一格径向短线；转环激活时加深）

private struct TickDial: View {
    var strong: Bool = false
    var body: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { i in
                Rectangle()
                    .fill(Color(red: 0.345, green: 0.345, blue: 0.404).opacity(strong ? 0.36 : 0.2))
                    .frame(width: 2, height: 9)
                    .offset(y: -(240 / 2 - 9))
                    .rotationEffect(.degrees(Double(i) * 15))
            }
        }
        // ⚠️ 勿加 clipShape：ZStack bounds = 中心小矩形（offset 不扩 bounds），
        // 圆形 clip 会把 offset 后的 tick 全部裁掉（像素定位实验实证）
    }
}

// MARK: - 环带涟漪脉冲（每跨 15° 一次）
// Breathing（轨迹环呼吸）B1r 移除：用户定稿环为静止几何描边，不做缩放/透明动画

private struct TickRipple: View {
    @State private var play = false
    var body: some View {
        Circle()
            .stroke(Color(red: 0.345, green: 0.345, blue: 0.404).opacity(0.55), lineWidth: 2)
            .frame(width: 15, height: 15)
            .scaleEffect(play ? 2.1 : 0.7)
            .opacity(play ? 0 : 0.65)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) { play = true }
            }
    }
}

// MARK: - 幽灵回声残影（v0.9：opacity .55 → 0 · scale 1 → 0.22 · 0.5s ease-out）

private struct GhostEcho: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let color: Color
}

private struct EchoDot: View {
    let echo: GhostEcho
    @State private var fade = false
    var body: some View {
        Circle()
            .fill(echo.color.opacity(fade ? 0 : 0.55))
            .frame(width: 15, height: 15)
            .scaleEffect(fade ? 0.22 : 1)
            .offset(x: echo.x, y: echo.y)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { fade = true }
            }
    }
}

// MARK: - 自转时钟（B1p 引擎：时间累加模型 · 可任意次冻结/无缝续转）
// repeatForever 的教训（旧亮弧停摆根因）：一次性提交的有限曲线，状态变更/中断即停。
// 时间累加：angle = frozen + 方向 × (now − base) × 速率 —— 冻结（收拢/被覆盖）把当前角
// 记入 frozen 并重置 base；恢复只重置 base：渲染角度从冻结值 + ε 无缝续转，不跳变。

struct SpinClock: Equatable {
    /// s/圈
    let period: Double
    /// +1 顺时针 / −1 逆时针
    let direction: Double
    /// 冻结累计角（含初始相位）
    private(set) var frozenAngle: Double
    /// 时间基准
    private(set) var base: Date

    init(period: Double, direction: Double = 1, phase: Double = 0, base: Date = Date()) {
        self.period = period
        self.direction = direction
        self.frozenAngle = phase
        self.base = base
    }

    /// 当前角（度）
    func angle(now: Date) -> Double {
        frozenAngle + direction * now.timeIntervalSince(base) * 360.0 / period
    }

    /// 冻结在当前角（收拢/被覆盖暂停时调用；返回新时钟）
    func frozen(at now: Date) -> SpinClock {
        var c = self
        c.frozenAngle = angle(now: now)
        c.base = now
        return c
    }

    /// 从冻结角无缝续转（松手/回到待机时调用）
    func resumed(at now: Date) -> SpinClock {
        var c = self
        c.base = now
        return c
    }
}

// MARK: - 刻度环轻自转（TimelineView 驱动：转环按住不停 · 模块覆盖时冻结节能）

private struct TickDialSpin: View {
    var strong: Bool          // 转环激活：刻度加深
    var dragAngle: Double     // 转环跟手叠加角（即时，不进时钟）
    var paused: Bool          // 模块覆盖节能暂停（转环期间恒 false → 轻自转不停）
    var reduceMotion: Bool

    @State private var clock = SpinClock(period: 150)   // 150s/圈（原速）

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: paused || reduceMotion)) { tl in
            TickDial(strong: strong)
                .rotationEffect(.degrees(clock.angle(now: tl.date) + dragAngle))
        }
        .allowsHitTesting(false)
        .onChange(of: paused) { old, now in
            if now {
                clock = clock.frozen(at: Date())
            } else if old {
                clock = clock.resumed(at: Date())
            }
        }
    }
}

// MARK: - 轨迹双弧（B1q：环内侧贴近轨迹环 · 反向差速自转 · 贴环消失/复位）
// 圆内两道：一长一细 + 一短一粗，轨道半径紧贴 180 轨迹环（内侧 4/10pt）；时间累加驱动永不停摆。
// 颜色 = 四色卡同系半透明（橙/紫/绿/黄选二，与色卡呼应）。
// 转环按住（collapsed=true）：不收圆心——scale 放大到轨迹环半径（贴环愈合消失）并渐隐
// （easeInOut 0.34s），相位冻结；松手：从环处缩回各自轨道淡入，从冻结相位无缝续转。

private struct OrbitArc: View {
    var diameter: CGFloat
    var lineWidth: CGFloat
    /// 弧段占环周比例（trim 0..1）
    var trimStart: Double
    var trimEnd: Double
    var opacity: Double
    /// 弧色（四色卡同系，外部传 .opacity 已按 baseOpacity 调制）
    var tint: Color
    /// 贴环消失的目标直径（= 180 轨迹环）
    var collapseToDiameter: CGFloat
    var collapsed: Bool
    var paused: Bool
    var reduceMotion: Bool

    @State private var clock: SpinClock

    init(diameter: CGFloat, lineWidth: CGFloat, trimStart: Double, trimEnd: Double,
         opacity: Double, tint: Color, collapseTo: CGFloat,
         direction: Double, period: Double, phase: Double,
         collapsed: Bool, paused: Bool, reduceMotion: Bool) {
        self.diameter = diameter
        self.lineWidth = lineWidth
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.opacity = opacity
        self.tint = tint
        self.collapseToDiameter = collapseTo
        self.collapsed = collapsed
        self.paused = paused
        self.reduceMotion = reduceMotion
        _clock = State(initialValue: SpinClock(period: period, direction: direction, phase: phase))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil,
                                paused: paused || reduceMotion || collapsed)) { tl in
            Circle()
                .trim(from: trimStart, to: trimEnd)
                .stroke(
                    tint.opacity(opacity),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .blur(radius: 0.6)
                .rotationEffect(.degrees(clock.angle(now: tl.date)))
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
        // B1q 贴环消失：scale → 轨迹环直径/轨道直径（放大贴向环）+ 渐隐；不收圆心
        .scaleEffect(collapsed ? collapseToDiameter / diameter : 1)
        .opacity(collapsed ? 0 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.34), value: collapsed)
        .onChange(of: collapsed) { _, now in
            if now {
                clock = clock.frozen(at: Date())   // 贴环瞬间：相位冻结
            } else {
                clock = clock.resumed(at: Date())  // 松手：从冻结相位无缝续转
            }
        }
        .onChange(of: paused) { old, now in
            if now {
                clock = clock.frozen(at: Date())
            } else if old {
                clock = clock.resumed(at: Date())
            }
        }
    }
}

// MARK: - 圆心幽灵指针球
// 静止 = 待机呼吸玻璃球（光晕 4s）；拖动 = 跟手 + 模块色发光。

private struct GhostDot: View {
    var offset: CGSize
    var glowColor: Color
    var resting: Bool

    @State private var haloScale: CGFloat = 1

    var body: some View {
        ZStack {
            if resting {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [.white.opacity(0.55), .white.opacity(0)]),
                            center: .center, startRadius: 2, endRadius: 14
                        )
                    )
                    .frame(width: 34, height: 34)
                    .scaleEffect(haloScale)
                    .opacity(haloScale > 1.2 ? 0.95 : 0.55)
            }
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.94),
                            Color.white.opacity(0.55)
                        ]),
                        startPoint: .init(x: 0.5, y: 0.0), endPoint: .init(x: 0.33, y: 1.0)
                    )
                )
                // ⚠️ 必须显式圆形 shape：泛型 .background(.ultraThinMaterial) 填充的是
                // 视图方形 bounds（不是 shape 轮廓），发光 shadow 会随方形 alpha 产生方角光晕
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.92), lineWidth: 1))
                .frame(width: 20, height: 20)
                .shadow(color: Color(red: 0.122, green: 0.102, blue: 0.078).opacity(0.16), radius: 4.5, x: 0, y: 3)
        }
        .offset(offset)
        .shadow(color: glowColor == .clear ? .clear : glowColor.opacity(0.75), radius: 11, x: 0, y: 0)
        .onAppear {
            guard resting else { return }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                haloScale = 1.4
            }
        }
    }
}

// MARK: - 流光时序（原型 .gc-in::after 精确转录 · 可单测）
// CSS：animation: sheen 6.5s ease-in-out var(--sd) infinite; 0%~55% 扫光、55%~100% 静止；
// --sd 错峰 = 1.6s × nth（DOM 序 up(m1)/rt(m4)/dn(m2)/lf(m3) = 环上顺时针序）。
// V0.3.3 重置：返回待机时返回模块卡 0s、其余顺时针错峰（同 ringOrder 相对差）。

enum SheenTiming {
    static let period: Double = 14                     // 全周期 s
    static let sweepDuration: Double = 2.2             // 单卡光斑掠过时长 s（闪过）
    static var sweepRatio: Double { sweepDuration / period }   // ~0.157 周期
    /// 错峰 = 周期 / 4（V3 持续巡游：四卡均匀衔接循环，无整轮安静期）
    static let staggerRelay: Double = period / 4       // 3.5s（相邻卡起闪时间差）
    /// 环上顺时针序（上→右→下→左 = 原型 gchip DOM 序）
    static let ringOrder: [ModuleKey] = [.m1, .m4, .m2, .m3]

    /// 相位延迟：初始（restart=nil）= 环序 × 1.6s；
    /// 返回待机重启（restart=离开的模块）= 返回卡 0s、其余按顺时针相对差
    static func delay(for module: ModuleKey, restart: ModuleKey?) -> Double {
        guard let mi = ringOrder.firstIndex(of: module) else { return 0 }
        guard let ri = restart.flatMap({ ringOrder.firstIndex(of: $0) }) else {
            return Double(mi) * staggerRelay   // 初始（restart=nil）：顺时针环序错峰
        }
        return Double((mi - ri + ringOrder.count) % ringOrder.count) * staggerRelay
    }

    /// 周期进度 0..1：未到 t0（错峰等待中）取 0；之后取模
    static func progress(elapsed: Double) -> Double {
        guard elapsed > 0 else { return 0 }
        return elapsed.truncatingRemainder(dividingBy: period) / period
    }

    /// 扫光 0..1：sweepRatio 内按 ease-in-out（CSS cubic-bezier(0.42,0,0.58,1)），之后停 1
    static func sweep(progress p: Double) -> Double {
        guard p > 0 else { return 0 }
        let r = p / sweepRatio
        guard r < 1 else { return 1 }
        return UnitCurve.easeInOut.value(at: r)
    }

    /// 光带中心 x（卡坐标系）：从左屏外扫到右屏外（CSS bg-position 200%→-80% 的等效位移）
    static func bandCenterX(sweep s: Double, cardWidth: Double) -> Double {
        let margin = cardWidth * 0.55                 // 屏外余量
        let start = -margin, end = cardWidth + margin
        return start + (end - start) * s
    }
}

// MARK: - 色卡毛玻璃底（原型 .gc-in 精确转录）
// linear-gradient(150°, 白.74→.36) + backdrop blur(16) saturate(1.7) +
// 白描边 .82 + 顶部内高光(白.95) + 底部内亮(白.42) + 单层外阴影 0 7 18 墨褐 .10

private struct ChipGlass: ViewModifier {
    var corner: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // backdrop 模糊层 + 饱和度提升（背后四色 blob 被折射成彩色玻璃）
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .saturation(1.7)
                    // 150° 白渐变面（上亮下透）：x .78→.22 近似
                    LinearGradient(
                        colors: [.white.opacity(0.74), .white.opacity(0.36)],
                        startPoint: UnitPoint(x: 0.78, y: 0), endPoint: UnitPoint(x: 0.22, y: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.82), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                // inset 0 1 1 白 .95（顶部 1px 亮线）
                LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0)],
                               startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.1))
                    .frame(height: 3)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                // inset 0 -6 14 白 .42（底部厚度感柔光）
                LinearGradient(colors: [.clear, .white.opacity(0.42)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .allowsHitTesting(false)
            }
            .shadow(color: Color(red: 0.122, green: 0.102, blue: 0.078).opacity(0.10),
                    radius: 9, x: 0, y: 7)
    }
}

// MARK: - 流光光斑（TimelineView 确定性驱动：相位纯函数，无动画竞争/重启丢相位问题）

private struct SheenBand: View {
    /// 本卡光斑 begintime（= 出现时刻 / 重置时刻 + 错峰 delay）
    let t0: Date
    let paused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            // B1o（真机反馈「是光球不是光斑，要左上斜着闪到右侧」）：
            // 斜向光带（经典 sheen）替代径向光球——窄长竖条（宽 0.42w · 高 2.4h 越界覆盖）
            // → 左倾 20°（"\" 走向：左上 → 右下）→ 横向扫过：自左屏外入画，斜条掠过卡面
            // 闪到右屏外出画。色系沿用户定稿「灰白/亮白」：亮白核 0.92 + 中性银灰羽化缘
            // → clear（R≈G≈B 零色温，白面反差靠银灰半影）。
            let bandW = w * 0.42
            let bandH = h * 2.4
            TimelineView(.animation(minimumInterval: nil, paused: paused)) { tl in
                let sweep = SheenTiming.sweep(progress: SheenTiming.progress(
                    elapsed: tl.date.timeIntervalSince(t0)))
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: Color(red: 0.86, green: 0.88, blue: 0.92).opacity(0.32), location: 0.30),
                        .init(color: Color.white.opacity(0.92), location: 0.50),
                        .init(color: Color(red: 0.86, green: 0.88, blue: 0.92).opacity(0.32), location: 0.70),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: bandW, height: bandH)
                .rotationEffect(.degrees(-20))
                .blur(radius: 2.5)
                .offset(x: SheenTiming.bandCenterX(sweep: sweep, cardWidth: w) - bandW / 2,
                        y: -(bandH - h) / 2)
                .opacity(sweep > 0.001 && sweep < 0.999 ? 1 : 0)   // 屏外/待闪时彻底关闭
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .allowsHitTesting(false)
    }
}

// MARK: - 四向液态玻璃色卡（44 · 距圆心 145）
// 单字 17px 模块色发光 + 小标签 8px；ChipGlass 毛玻璃 + 流光轮流 + 返回重置 + 浮动 + 按压。

private struct CompassChip: View {
    let module: ModuleKey
    let position: CompaasPosition
    let distance: CGFloat
    let center: CGPoint
    /// 非待机暂停流光（页面被模块屏覆盖）
    var paused: Bool = false
    /// 返回待机的流光重置（V0.3.3）：返回卡 0s 立即扫、其余顺时针错峰
    var restartModule: ModuleKey? = nil
    var restartStamp: UUID? = nil
    let action: () -> Void

    enum CompaasPosition { case up, down, left, right }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // B1j：字飞行目标模块——飞行中隐藏目标色卡（元素到位后再显示，携带感）
    @Environment(\.flightTargetModule) private var flightTarget
    @State private var floating = false
    @State private var pressed = false
    @State private var sheenT0 = Date.distantFuture   // distantFuture → 扫光 0（屏外不可见）

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(module.glyph)
                    .font(DSToken.body(17, weight: .bold))
                    .foregroundStyle(module.color)
                    .shadow(color: module.color.opacity(0.55), radius: 5.5)
                Text(module.chipLabel)
                    .font(DSToken.body(8, weight: .medium))
                    .foregroundStyle(Color(red: 0x7c / 255, green: 0x7c / 255, blue: 0x82 / 255))
                    .tracking(1)
            }
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .modifier(ChipGlass())
            .overlay {
                if !reduceMotion {
                    SheenBand(t0: sheenT0, paused: paused)   // B1n：灰白/亮白（亮白核+银灰晕）
                }
            }
            .scaleEffect(pressed ? 0.92 : 1)
            .offset(y: floating ? 3 : -2.5)
            .animation(DSToken.bounceTap, value: pressed)
            .opacity(flightTarget == module ? 0 : 1)   // B1j：字飞行中隐藏目标色卡
            .moduleSpot(module, preference: CardSpotKey.self)   // B1i：上报色卡中心（字飞行起点）
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.75).repeatForever(autoreverses: true)) {
                    floating = true
                }
                // 初始相位：环顺时针错峰（M1 0s / M4 1.6 / M2 3.2 / M3 4.8）
                sheenT0 = Date().addingTimeInterval(
                    SheenTiming.delay(for: module, restart: nil))
            }
            .onChange(of: restartStamp) { _, _ in
                guard !reduceMotion else { return }
                // 返回待机重置：返回模块卡 0s 立即扫（原型 V0.3.3 sheenRestart）
                sheenT0 = Date().addingTimeInterval(
                    SheenTiming.delay(for: module, restart: restartModule))
            }
        }
        .buttonStyle(.plain)
        .position(chipAnchor)
    }

    private var chipAnchor: CGPoint {
        switch position {
        case .up:    return CGPoint(x: center.x, y: center.y - distance)
        case .down:  return CGPoint(x: center.x, y: center.y + distance)
        case .left:  return CGPoint(x: center.x - distance, y: center.y)
        case .right: return CGPoint(x: center.x + distance, y: center.y)
        }
    }
}
