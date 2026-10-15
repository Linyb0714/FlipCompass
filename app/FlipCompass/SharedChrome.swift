import SwiftUI

// MARK: - 共享基建 · 模块屏骨架组件（B1 建立，B2~B4 复用）
// 原型 .mod-head / .head-chip / .dots / .nav-hint / .toast / .focus-card 精确转录。

// MARK: - 模块字飞行转场（B1i：色卡 ↔ 模块头图标 坐标上报 + 飞行层）

/// 字飞行目标模块（飞行中隐藏目标处原始元素，到位后再显示——元素携带感）
private struct FlightTargetKey: EnvironmentKey { static let defaultValue: ModuleKey? = nil }

extension EnvironmentValues {
    /// 当前正在飞行到/离开的模块（目标元素隐藏中）；nil = 无飞行
    var flightTargetModule: ModuleKey? {
        get { self[FlightTargetKey.self] }
        set { self[FlightTargetKey.self] = newValue }
    }
}

/// 待机色卡中心坐标上报（.global）
struct CardSpotKey: PreferenceKey {
    static var defaultValue: [ModuleKey: CGPoint] = [:]
    static func reduce(value: inout [ModuleKey: CGPoint], nextValue: () -> [ModuleKey: CGPoint]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// 模块头图标中心坐标上报（.global）
struct IconSpotKey: PreferenceKey {
    static var defaultValue: [ModuleKey: CGPoint] = [:]
    static func reduce(value: inout [ModuleKey: CGPoint], nextValue: () -> [ModuleKey: CGPoint]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// 上报自身中心到指定模块坐标字典（rootSpace = AppRootView 坐标系，
    /// 与飞行层 position() 同空间——.global 会多算安全区高度导致起点偏低 59pt）
    func moduleSpot<K: PreferenceKey>(_ key: ModuleKey, preference: K.Type) -> some View where K.Value == [ModuleKey: CGPoint] {
        background(
            GeometryReader { g in
                let f = g.frame(in: .named("rootSpace"))
                Color.clear.preference(key: preference, value: [key: CGPoint(x: f.midX, y: f.midY)])
            }
        )
    }
}

// MARK: 模块头（色字图标 + 标题/副题 + 统计胶囊）

struct ModuleHeader: View {
    let module: ModuleKey
    let subtitle: String
    /// 胶囊文案（已含数值，如「连续 7 天」）；nil = 不显示
    let chip: String?
    /// 胶囊内数值（SF Pro Rounded 高亮大数值）
    var chipValue: Int? = nil

    @Environment(\.flightTargetModule) private var flightTarget

    var body: some View {
        HStack(spacing: DSToken.sp) {
            // mod-ic：46×46 · 圆角 14 · 145° 同系亮渐变 · 单字 22 白（B1i：上报图标中心供字飞行）
            // B1j：飞行期间隐藏本模块图标（元素飞行到位后再显示，携带感）
            Text(module.glyph)
                .font(DSToken.body(22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [module.color.opacity(0.87), module.color]),
                        startPoint: UnitPoint(x: 0.18, y: 0), endPoint: .init(x: 1, y: 0.85)
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.13), radius: 8, y: 7)
                .opacity(flightTarget == module ? 0 : 1)
                .moduleSpot(module, preference: IconSpotKey.self)

            VStack(alignment: .leading, spacing: 2) {
                Text(module.title)
                    .font(DSToken.body(23, weight: .bold))
                    .foregroundStyle(DSToken.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(DSToken.body(12.5))
                    .foregroundStyle(DSToken.ink2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)   // mod-title flex:1 收缩省略

            if let chip {
                HeadChip(text: chip, value: chipValue, color: module.color)
            }
        }
        .padding(.bottom, 16)
        .padding(.horizontal, 12)
    }
}

// MARK: 头部统计胶囊（V0.3.5 ③：发光色点 + 标签 + 大数值，白玻璃微胶囊）

struct HeadChip: View {
    let text: String
    let value: Int?
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.65), radius: 3)
            // 「连续 <b>7</b> 天」：数值拆为 SF Pro Rounded 15 亮字
            if let value {
                Text(HeadChipText.prefix(text: text))
                    .font(DSToken.body(11, weight: .semibold))
                Text("\(value)")
                    .font(DSToken.num(15, weight: .bold))
                    .foregroundStyle(DSToken.ink)
                Text(HeadChipText.suffix(text: text))
                    .font(DSToken.body(11, weight: .semibold))
            } else {
                Text(text)
                    .font(DSToken.body(11, weight: .semibold))
            }
        }
        .foregroundStyle(DSToken.ink2)
        .lineLimit(1)
        .truncationMode(.head)
        .padding(.leading, 10)
        .padding(.trailing, 13)
        .padding(.vertical, 6)
        .background(
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                LinearGradient(
                    gradient: Gradient(colors: [.white.opacity(0.88), .white.opacity(0.62)]),
                    startPoint: UnitPoint(x: 0.5, y: 0), endPoint: UnitPoint(x: 0.42, y: 1)
                )
            }
            .clipShape(Capsule())
        )
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.92), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 5, y: 3)
    }
}

/// 「前缀 数值 后缀」文案拆解（如「连续 7 天」→ 连续 / 天；「3 条想法」→ "" / 条想法）
enum HeadChipText {
    /// B3b 修复：正则 `\d`→`\d+` 匹配完整数字串——「今日 10 条」原 suffix 从第二个数字「0」
    /// 开始（r.upperBound 落在 "10" 中间），胶囊渲染成「今日 100 条」两组数字。
    /// 两位数计数（M3 今日 10 条）首次暴露；M1/M2 个位数未受影响。
    static func prefix(text: String) -> String {
        // 取首个完整数字串前的部分
        guard let r = text.range(of: #"\d+"#, options: .regularExpression) else { return "" }
        return String(text[..<r.lowerBound])
    }
    static func suffix(text: String) -> String {
        guard let r = text.range(of: #"\d+"#, options: .regularExpression) else { return text }
        return String(text[r.upperBound...])
    }
}

// MARK: 分组圆点指示（原型 .dots：7px 圆点，on = 模块色拉宽 21）

struct ModuleDots: View {
    let count: Int
    let current: Int
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<max(count, 1), id: \.self) { i in
                Capsule()
                    .fill(i == current ? color : DSToken.ink3)
                    .frame(width: i == current ? 21 : 7, height: 7)
                    .opacity(i == current ? 1 : 0.4)
            }
        }
        .animation(DSToken.spring, value: current)
        .padding(.vertical, 9)
    }
}

// MARK: 底部操作提示行（原型 .nav-hint：11px ink3 居中）

struct NavHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(DSToken.body(11))
            .foregroundStyle(DSToken.ink3)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity)
    }
}

// MARK: 模块 tint 渐变底（原型 .screen.module：白 30% → tint；tint-fx 中央模块色晕 14%）

struct ModuleBackdrop: View {
    let module: ModuleKey

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white, location: 0.30),
                    .init(color: module.tint, location: 1),
                ]),
                startPoint: .init(x: 0.5, y: 0), endPoint: .init(x: 0.48, y: 1)
            )
            // tint-fx：radial 模块色 6% 中心 → 62% 透明，整层 opacity .14
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: module.color, location: 0.06),
                    .init(color: module.color.opacity(0), location: 0.62),
                ]),
                center: UnitPoint(x: 0.5, y: 0.47),
                startRadius: 0,
                endRadius: 480
            )
            .opacity(0.14)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

// MARK: 浮动焦点卡（原型 .focus-card：白渐变玻璃 + 2px 白描边 + 模块色晕投影）

struct FocusCard: View {
    let frame: CGRect        // 目标 frame（pager 容器坐标系）
    let visible: Bool
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 23, style: .continuous)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [.white.opacity(0.34), .white.opacity(0.07)]),
                    startPoint: UnitPoint(x: 0.5, y: 0), endPoint: UnitPoint(x: 0.42, y: 1)
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.97), lineWidth: 2)
            )
            .shadow(color: color.opacity(0.30), radius: 7, y: 6)
            .shadow(color: .black.opacity(0.06), radius: 2, y: 2)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(false)
    }
}

// MARK: Toast 夜露胶囊（V0.3.6：深色磨砂 + 模块色发光点 + 弹簧上浮）

struct ModuleToast: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.65), radius: 3)
            Text(text)
                .font(DSToken.body(12.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(3)
                .multilineTextAlignment(.center)
        }
        .padding(.leading, 17)
        .padding(.trailing, 19)
        .padding(.vertical, 11)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color(red: 28/255, green: 28/255, blue: 30/255).opacity(0.78))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
        .shadow(color: .black.opacity(0.30), radius: 19, y: 14)
        .shadow(color: color.opacity(0.16), radius: 10)
        .padding(.horizontal, 30)
    }
}
