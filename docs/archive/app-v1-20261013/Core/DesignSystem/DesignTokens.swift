import SwiftUI

/// UX 设计 tokens（V0.3.10 / U1 V1 定稿）
/// iOS 系统四色 / 7px 尺度 / 液态玻璃 / 无倒影 / 浅色统一
enum DesignTokens {
    // 7px 尺度体系
    static let baseUnit: CGFloat = 7
    static let rCard: CGFloat = 21           // 卡片圆角（3×7）
    static let spacing: CGFloat = 14         // 主间距（2×7）
    static let spacing2: CGFloat = 28       // 大间距（4×7）
    static let hRow: CGFloat = 63            // 单行卡标准高（9×7，V0.3.10 ②）

    // iOS 系统四色（U1 方案 C）
    static let m1Orange = Color(red: 0xFF/255, green: 0x95/255, blue: 0x00/255)
    static let m2Purple = Color(red: 0xAF/255, green: 0x52/255, blue: 0xDE/255)
    static let m3Green = Color(red: 0x34/255, green: 0xC7/255, blue: 0x59/255)
    static let m4Yellow = Color(red: 0xFF/255, green: 0xCC/255, blue: 0x00/255)

    // 状态色（V0.3.0 / V0.3.5）
    static let success = Color(red: 0x22/255, green: 0xc5/255, blue: 0x5e/255)
    static let error = Color(red: 0xf5/255, green: 0x22/255, blue: 0x2d/255)

    // 灰阶
    static let ink = Color(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255)
    static let inkSecondary = Color(red: 0x8E/255, green: 0x8E/255, blue: 0x93/255)
    static let bgPrimary = Color.white
    static let bgSecondary = Color(red: 0xF2/255, green: 0xF2/255, blue: 0xF7/255)

    // 弹簧曲线（V0.2.x 定稿）
    static let springEase = Animation.spring(response: 0.34, dampingFraction: 0.72)
    static let springBounce = Animation.spring(response: 0.3, dampingFraction: 0.45)

    // 双层软阴影（V0.3.5 ②）
    static let cardShadowNear: (CGFloat, CGFloat) = (0, 1)
    static let cardShadowMid: (CGFloat, CGFloat) = (0, 12)
    static let cardShadowFar: (CGFloat, CGFloat) = (0, 28)
}

extension View {
    /// 液态玻璃卡片（V0.3.5 ② 3D 立体感）
    func glassCard(moduleColor: Color = .accentColor, selected: Bool = false) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.rCard)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(selected ? 0.94 : 0.88),
                                    Color.white.opacity(selected ? 0.7 : 0.6)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    if selected {
                        RoundedRectangle(cornerRadius: DesignTokens.rCard)
                            .stroke(moduleColor.opacity(0.32), lineWidth: 1)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.rCard))
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.07), radius: 12, y: 12)
            .shadow(color: moduleColor.opacity(0.12), radius: 28, y: 28)
    }
}
