import SwiftUI
import SwiftData

/// 条目管理 P2（V0.4.1 ③ iOS 删除规则）
/// 左侧 − 圆钮 → 行内容右移露出红色删除钮 → 确认/点其他收起
struct CheckInManageView: View {
    let items: [CheckInItem]
    let onEdit: (CheckInItem) -> Void
    let onNew: () -> Void
    let onDelete: (CheckInItem) -> Void
    let onChange: () -> Void

    @State private var revealingID: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: 7) {
                ForEach(items, id: \.id) { item in
                    row(item)
                }
                newCard
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 28)
        }
    }

    private func row(_ item: CheckInItem) -> some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(DesignTokens.springEase) {
                    revealingID = (revealingID == item.id) ? nil : item.id
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.red.opacity(0.8))
                    .frame(width: 32, height: DesignTokens.hRow)
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignTokens.ink)
                    if !item.desc.isEmpty {
                        Text(item.desc).font(.system(size: 12))
                            .foregroundStyle(DesignTokens.inkSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button {
                    onEdit(item)
                } label: {
                    HStack(spacing: 3) {
                        Text("编辑").font(.system(size: 13))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(DesignTokens.m1Orange)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: DesignTokens.hRow)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.rCard))
            .overlay(alignment: .trailing) {
                if revealingID == item.id {
                    Button {
                        onDelete(item)
                        revealingID = nil
                        onChange()
                    } label: {
                        Text("删除")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 66, height: DesignTokens.hRow)
                            .background(DesignTokens.error)
                    }
                    .buttonStyle(.plain)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.rCard))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if revealingID == item.id { revealingID = nil }
        }
    }

    private var newCard: some View {
        Button { onNew() } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(DesignTokens.m1Orange)
                Text("新建打卡项")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(minHeight: DesignTokens.hRow, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(moduleColor: DesignTokens.m1Orange, selected: false)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.rCard)
                    .stroke(DesignTokens.m1Orange.opacity(0.3),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
    }
}
