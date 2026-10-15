import SwiftUI

// MARK: - 设计 Token（03-UX设计.md U1 定稿 · 原型 V0.4.5 :root 精确转录）
// 四模块色 = iOS 系统四色；尺度 = 7px 基本单元体系；浅色统一；无倒影。

enum DSToken {
    // 四模块主题色（方案 C 苹果经典）
    static let m1 = Color(red: 0xFF / 255, green: 0x95 / 255, blue: 0x00 / 255) // M1 温情打卡 橙 #FF9500
    static let m2 = Color(red: 0xAF / 255, green: 0x52 / 255, blue: 0xDE / 255) // M2 今天的想法 紫 #AF52DE
    static let m3 = Color(red: 0x34 / 255, green: 0xC7 / 255, blue: 0x59 / 255) // M3 生活情报站 绿 #34C759
    static let m4 = Color(red: 0xFF / 255, green: 0xCC / 255, blue: 0x00 / 255) // M4 益智小游戏 黄 #FFCC00

    // 阶梯墨色 / 底色
    static let ink = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)   // #1C1C1E
    static let ink2 = Color(red: 0x8E / 255, green: 0x8E / 255, blue: 0x93 / 255)  // #8E8E93
    static let ink3 = Color(red: 0xC7 / 255, green: 0xC7 / 255, blue: 0xCC / 255)  // #C7C7CC
    static let bg = Color(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF7 / 255)    // 二级底 #F2F2F7
    static let line = Color(red: 0x3C/255, green: 0x3C/255, blue: 0x43/255).opacity(0.09)

    // 状态色
    static let ok = Color(red: 0x22/255, green: 0xC5/255, blue: 0x5E/255)   // 成功绿
    static let bad = Color(red: 0xF5/255, green: 0x22/255, blue: 0x2D/255)  // 异常红

    // 模块浅染底（原型 .tint-* 屏幕渐变终点）
    static let tintM1 = Color(red: 0xFF/255, green: 0xF6/255, blue: 0xEC/255) // #FFF6EC
    static let tintM2 = Color(red: 0xF8/255, green: 0xF4/255, blue: 0xFE/255) // #F8F4FE
    static let tintM3 = Color(red: 0xF0/255, green: 0xFA/255, blue: 0xF2/255) // #F0FAF2
    static let tintM4 = Color(red: 0xFF/255, green: 0xFA/255, blue: 0xE8/255) // #FFFAE8

    // 7px 尺度体系
    static let rCard: CGFloat = 21     // 圆角 21（3×7）
    static let sp: CGFloat = 14        // 间距 14（2×7）
    static let sp2: CGFloat = 28       // 大间距 28（4×7）
    static let hRow: CGFloat = 63      // 单行卡标准高（9×7，基准 = 新建打卡项）

    // 动画曲线（原型 --spring / --bounce 精确转录）
    static let spring = Animation.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.34)
    static let springSlow = Animation.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.55)
    static let bounce = Animation.timingCurve(0.30, 1.45, 0.45, 1, duration: 0.55)
    static let bounceQuick = Animation.timingCurve(0.30, 1.45, 0.45, 1, duration: 0.34)
    static let bounceTap = Animation.timingCurve(0.30, 1.45, 0.45, 1, duration: 0.2)
    static let enterBounce = Animation.timingCurve(0.30, 1.45, 0.45, 1, duration: 0.46)  // 方位入场
    static let exit = Animation.timingCurve(0.50, 0.00, 0.80, 0.50, duration: 0.40)      // 退出滑出
    // B5b（真机反馈「停滞较久、不跟手」）：落页曲线起步加速——原 ease-in-out (0.42,0,0.58,1)
    // 前半段静止感强 + 0.3s 偏长；改响应型曲线（起步快速前进）+ 总时长 0.26s，
    // 松手即走，无等待感；session 归零回弹同用此曲线
    static let pageSwitch = Animation.timingCurve(0.14, 0.72, 0.24, 1, duration: 0.26)
    // C1：hero 卡片生长/收回（源卡→全屏 240ms，原型 hero-clone transition）
    static let heroGrow = Animation.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.24)

    /// 圆角数字样式（时钟 / 天数 / 比分 = SF Pro Rounded）
    static func num(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    /// 正文（系统苹方）
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - 模块定义

enum ModuleKey: String, CaseIterable, Identifiable {
    case m1, m2, m3, m4
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .m1: return DSToken.m1
        case .m2: return DSToken.m2
        case .m3: return DSToken.m3
        case .m4: return DSToken.m4
        }
    }
    var tint: Color {
        switch self {
        case .m1: return DSToken.tintM1
        case .m2: return DSToken.tintM2
        case .m3: return DSToken.tintM3
        case .m4: return DSToken.tintM4
        }
    }
    /// 色卡单字（心 / 思 / 知 / 玩）
    var glyph: String {
        switch self {
        case .m1: return "心"
        case .m2: return "思"
        case .m3: return "知"
        case .m4: return "玩"
        }
    }
    /// 色卡小标签
    var chipLabel: String {
        switch self {
        case .m1: return "打卡"
        case .m2: return "想法"
        case .m3: return "情报"
        case .m4: return "游戏"
        }
    }
    /// 模块全名
    var title: String {
        switch self {
        case .m1: return "温情打卡"
        case .m2: return "今天的想法"
        case .m3: return "生活情报站"
        case .m4: return "益智小游戏"
        }
    }
}

// MARK: - 液态玻璃卡片修饰器（原型 .item 家族：渐变面 + blur + 三层阴影 + 内高光）

struct LiquidGlass: ViewModifier {
    /// 模块色微染（选中态 6% / 常规 0）
    var tint: Color? = nil
    var cornerRadius: CGFloat = DSToken.rCard
    /// 边框色（选中态传模块色 55%，B1 起）
    var borderColor: Color = Color.white.opacity(0.82)
    var borderWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .background(
                // 半透白渐变面（168° .94 → .70）
                // 性能优化（完善轮）：去掉 ultraThinMaterial 实时模糊——卡片底下是
                // 平滑模块渐变背景，模糊平滑渐变 = 恒等运算，视觉零差异；但列表
                // 滚动/翻页/hero 生长时每卡实时 blur 合成是掉帧主因（M1/M2 列表卡）。
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [.white.opacity(0.94), .white.opacity(0.70)]),
                        startPoint: .init(x: 0.5, y: 0.0), endPoint: .init(x: 0.44, y: 1.0)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    if let tint {
                        LinearGradient(
                            gradient: Gradient(colors: [tint.opacity(0.06), tint.opacity(0.04)]),
                            startPoint: .top, endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                }
            )
            .overlay(
                // 细描边（选中 = 模块色 55%）
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .overlay(
                // 顶部内高光（厚度感）
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.white.opacity(0.9), .white.opacity(0)]),
                            startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.22)
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
            )
            // 双层阴影立体：贴地 1 / 空间 12（性能优化：漫射 28 层为 4% 黑近乎不可见，
            // 列表每卡省一层离屏合成；观感变化由用户真机目验定稿）
            .shadow(color: .black.opacity(0.05), radius: 0.5, y: 1)
            .shadow(color: .black.opacity(0.05), radius: 6, y: 12)
    }
}

extension View {
    func liquidGlass(
        tint: Color? = nil,
        cornerRadius: CGFloat = DSToken.rCard,
        borderColor: Color = Color.white.opacity(0.82),
        borderWidth: CGFloat = 1
    ) -> some View {
        modifier(LiquidGlass(tint: tint, cornerRadius: cornerRadius,
                             borderColor: borderColor, borderWidth: borderWidth))
    }
}

// MARK: - 渐变亮端混白（原型 color-mix(in srgb, c 78%, #fff) 语义 · C2 起共享）

extension Color {
    /// 与白色线性混合：amount = 白色占比（0 = 原色；0.22 ≈ 原型 78%/22%）
    func mixedWithWhite(_ amount: Double = 0.22) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: r + (1 - r) * amount,
                     green: g + (1 - g) * amount,
                     blue: b + (1 - b) * amount)
    }
}
