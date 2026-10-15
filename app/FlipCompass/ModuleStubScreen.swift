import SwiftUI

// MARK: - 模块占位屏（A 阶段临时 · B 阶段逐模块替换为真实一级目录）
// 保留模块品牌语言：tint 渐变底（178° 白 30% → 模块浅染）+ 大单字 + 模块全名。
// 支持平放收拢 / 双击空白返回（R7）。

struct ModuleStubScreen: View {
    let module: ModuleKey
    let onBack: () -> Void

    var body: some View {
        ZStack {
            // 模块屏底（178°：#fff 30% → tint）
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white, location: 0.30),
                    .init(color: module.tint, location: 1),
                ]),
                startPoint: .init(x: 0.5, y: 0), endPoint: .init(x: 0.48, y: 1)
            )
            .ignoresSafeArea()

            VStack(spacing: DSToken.sp) {
                // 大单字（模块 glyph + 发光）
                Text(module.glyph)
                    .font(DSToken.body(96, weight: .bold))
                    .foregroundStyle(module.color)
                    .shadow(color: module.color.opacity(0.5), radius: 24)
                    .padding(.bottom, DSToken.sp2 + 14)
                Text(module.title)
                    .font(DSToken.body(22, weight: .bold))
                    .foregroundStyle(DSToken.ink)
                Text("一级模块 · B 阶段建设中")
                    .font(DSToken.body(13, weight: .medium))
                    .foregroundStyle(DSToken.ink2)
                    .padding(.top, 2)
            }
        }
        .contentShape(Rectangle())
        // R7：L1 双击空白返回上一级（待机）
        .onTapGesture(count: 2) { onBack() }
    }
}
