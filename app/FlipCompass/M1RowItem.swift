import SwiftUI

// MARK: p2 条目管理 · 管理行（B1e 真机反馈重构）
// 焦点样式与 p0 打卡卡同步（liquidGlass 模块色微染 + 橙描边 + 左竖条）；
// 行内独立手势：水平 = swipe 露红字「删除」、垂直 = 转发步进——不涉及 tab 切组。

struct M1RowItem: View {
    let item: CheckInItem
    let selected: Bool
    /// 该行当前 swipe 偏移（0 = 收起 · -56 = 展开露红字删除）
    var swipeX: CGFloat = 0
    /// B1i：长按拖动排序中（浮起 + 阴影加深）
    var sorting: Bool = false
    let onDelete: () -> Void
    let onTap: () -> Void
    let onEdit: () -> Void
    // B1e：行手势会话转发（M1Screen 处理 swipe / 步进）
    let onDragBegin: (PagerLogic.Axis) -> Void
    let onDragChange: (PagerLogic.Axis, CGSize) -> Void
    let onDragEnd: (PagerLogic.Axis, CGSize, CGPoint, CGPoint) -> Void
    // B1i：长按拖动排序回调
    let onSortBegin: () -> Void
    let onSortDrag: (CGFloat) -> Void
    let onSortEnd: () -> Void

    @State private var axis: PagerLogic.Axis? = nil

    var body: some View {
        ZStack(alignment: .trailing) {
            // 底层：右缘红色「删除」文字（行内容左滑后露出；收起态不渲染防透出）
            Button(action: onDelete) {
                Text("删除")
                    .font(DSToken.body(14, weight: .semibold))
                    .foregroundStyle(DSToken.bad)
                    .padding(.leading, 12)
                    .padding(.trailing, 18)
                    .frame(height: DSToken.hRow)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(swipeX < -2 ? 1 : 0)

            // 行内容：标题 + 编辑 ›（左滑跟手，露出底层红字）
            HStack(spacing: 11) {
                Text(item.title)
                    .font(DSToken.body(16.5, weight: .semibold))
                    .foregroundStyle(DSToken.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("编辑 ›")
                    .font(DSToken.body(14))
                    .foregroundStyle(selected ? DSToken.m1 : DSToken.ink3)
                    .offset(x: selected ? 3 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture { onEdit() }
            }
            .padding(.horizontal, 18)
            .frame(height: DSToken.hRow)
            .liquidGlass(
                tint: selected ? DSToken.m1 : nil,
                borderColor: selected ? DSToken.m1.opacity(0.55) : Color.white.opacity(0.95)
            )
            .offset(x: swipeX)
            .scaleEffect(sorting ? 1.02 : 1)
            .shadow(color: sorting ? .black.opacity(0.16) : .clear, radius: 14, y: 8)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(DSToken.m1)
                    .frame(width: 4)
                    .padding(.vertical, 14)
                    .opacity(selected ? 0.9 : 0)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
            .onTapGesture { onTap() }
        }
        .frame(height: DSToken.hRow)
        .clipShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        // B1e：行内独立手势（水平 swipe / 垂直步进转发）——行上滑动不涉及 tab
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { v in
                    if axis == nil {
                        axis = PagerLogic.lockAxis(dx: v.translation.width, dy: v.translation.height)
                        if let axis { onDragBegin(axis) }
                    }
                    if let axis { onDragChange(axis, v.translation) }
                }
                .onEnded { v in
                    let ax = axis ?? .horizontal
                    onDragEnd(ax, v.translation, v.predictedEndLocation, v.location)
                    axis = nil
                }
        )
        // B1i：长按 0.35s → 进入拖动排序（与普通拖动互斥：立即拖走时长按取消）
        .gesture(
            LongPressGesture(minimumDuration: 0.35)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onChanged { value in
                    switch value {
                    case .first(true):
                        onSortBegin()
                    case .second(true, let drag?) where axis == nil:
                        onSortDrag(drag.translation.height)
                    default:
                        break
                    }
                }
                .onEnded { _ in onSortEnd() }
        )
    }
}
