import SwiftUI

// MARK: - 右侧缩略预览卡 + 贝塞尔曲线（C4 · 原型 V0.4.0 mini-preview / mini-curve 转录）
//
// 选中可进二级的条目 → 模块屏右侧浮出迷你二级页骨架卡（液态玻璃小卡），
// 贝塞尔虚线曲线从条目右缘连到缩略卡左缘；点卡放大（覆盖预览），再点收起；
// 点页点切换多子页（MINI 数据驱动）。d3 类编辑表单目标不出卡
// （点「编辑 ›」是明确动作，避免右侧浮卡遮挡列表点击）。
//
// 通用组件：M2 先接入（C4），M1/M3/M4 后续模块同构复用。

// MARK: 贝塞尔虚线曲线（原型 .mini-curve path：模块色 2pt 虚线 7/5 圆帽 · mpDraw 画入）

struct MiniCurve: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color

    @State private var progress: CGFloat = 0

    var body: some View {
        Path { p in
            let dx = max(36, to.x - from.x)
            let dy = to.y - from.y
            p.move(to: from)
            p.addCurve(
                to: to,
                control1: CGPoint(x: from.x + dx * 0.5, y: from.y + dy * 0.18),
                control2: CGPoint(x: to.x - dx * 0.5, y: to.y - dy * 0.18)
            )
        }
        .trim(from: 0, to: progress)
        .stroke(
            color.opacity(0.75),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 5])
        )
        .onAppear {
            progress = 0
            withAnimation(.easeOut(duration: 0.5)) { progress = 1 }   // 原型 mpDraw 0.5s 画入
        }
    }
}

// MARK: 缩略预览卡（原型 .mini-card：玻璃卡 + 骨架行 + 页点 + 放大角标）

struct MiniPreviewCard: View {
    let title: String
    let sub: String
    let pageCount: Int
    let pageIdx: Int
    let color: Color
    let big: Bool
    /// 页点切换（原型：切页同时收起放大态）
    let onPage: (Int) -> Void
    /// 点卡放大 ⇄ 收起（放大时曲线由父层收起）
    let onToggle: () -> Void

    private var width: CGFloat { big ? 248 : 112 }
    private var height: CGFloat { 130 }
    private var shownPage: Int { min(max(pageIdx, 0), max(pageCount - 1, 0)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // mp-bar：模块色顶条（38% 宽 · 3pt）
            Capsule()
                .fill(color.opacity(0.9))
                .frame(width: width * 0.38, height: 3)

            Text(title)
                .font(DSToken.body(12, weight: .bold))
                .foregroundStyle(DSToken.ink)
                .lineLimit(1)

            Text(sub)
                .font(DSToken.body(9.5))
                .foregroundStyle(DSToken.ink2)
                .lineLimit(1)

            // mp-rows：内容骨架行（88% / 64% · 灰渐变）
            VStack(spacing: 5) {
                skeletonRow(w: 0.88)
                skeletonRow(w: 0.64)
            }
            .padding(.top, 3)

            // mp-btn：模块色胶囊按钮骨架（70% 宽）
            Capsule()
                .fill(color.opacity(0.16))
                .overlay(Capsule().strokeBorder(color.opacity(0.45), lineWidth: 1))
                .frame(width: width * 0.7, height: 15)
                .padding(.top, 2)

            // mp-dots：子页点（当前 = 模块色）
            HStack(spacing: 4) {
                ForEach(0..<max(pageCount, 1), id: \.self) { i in
                    Circle()
                        .fill(i == shownPage ? color : DSToken.ink3)
                        .frame(width: 5, height: 5)
                        .onTapGesture { onPage(i) }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.top, 11)
        .padding(.bottom, 9)
        .frame(width: width, height: height, alignment: .top)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.white.opacity(0.97), .white.opacity(0.86)]),
                            startPoint: UnitPoint(x: 0.5, y: 0),
                            endPoint: UnitPoint(x: 0.66, y: 1)
                        )
                    )
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.95), lineWidth: 1)
            }
            .shadow(color: color.opacity(0.26), radius: 16, y: 10)   // 模块色漫射
            .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        )
        .overlay(alignment: .topTrailing) {
            // mp-zoom：放大预览角标（点击冒泡到卡 = 切换放大态）
            Text("⤢")
                .font(DSToken.body(11))
                .foregroundStyle(DSToken.ink3)
                .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { onToggle() }   // 点卡：放大 ⇄ 收起（页点 onTapGesture 优先）
    }

    private func skeletonRow(w: CGFloat) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.14), Color.black.opacity(0.05)]),
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(height: 7)
            .frame(width: width * w, alignment: .leading)
    }
}
