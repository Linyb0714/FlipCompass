import SwiftUI

/// 打卡清单 P0（V0.4.1 ①）
/// 列表项 = 标题+描述；未选中点 ✓ = 先选中，已选中点 ✓ = 打卡成功；右侧 › = 进详情
struct CheckInListView: View {
    let items: [CheckInItem]
    let selection: Int
    let onSelect: (Int) -> Void
    let onToggle: (CheckInItem) -> Void
    let onDetail: (CheckInItem) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    row(idx: idx, item: item)
                }
                newCard
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 28)
        }
    }

    private func row(idx: Int, item: CheckInItem) -> some View {
        let isSelected = idx == selection
        let cal = Calendar.current
        let doneToday = item.records.contains { cal.isDateInToday($0.doneAt) }
        let lastRecord = item.records.last { cal.isDateInToday($0.doneAt) }
        return HStack(spacing: 10) {
            Button {
                if !isSelected { onSelect(idx) }
                else { onToggle(item) }
            } label: {
                Image(systemName: doneToday ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(doneToday ? DesignTokens.m1Orange : DesignTokens.inkSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
                if !item.desc.isEmpty {
                    Text(item.desc)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.inkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()

            if let r = lastRecord {
                Text(r.doneAt, format: .dateTime.hour().minute())
                    .font(.system(size: 11, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.inkSecondary)
            }
            Button { onDetail(item) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkSecondary)
                    .padding(.leading, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: DesignTokens.hRow, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: DesignTokens.rCard)
                        .fill(DesignTokens.m1Orange.opacity(0.06))
                }
            }
        )
        .glassCard(moduleColor: DesignTokens.m1Orange, selected: isSelected)
        .overlay(alignment: .leading) {
            // accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignTokens.m1Orange)
                .frame(width: 4)
                .padding(.vertical, 10)
                .opacity(isSelected ? 1 : 0)
                .offset(x: -2)
        }
        .onTapGesture {
            if isSelected { onDetail(item) } else { onSelect(idx) }
        }
    }

    private var newCard: some View {
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
        .onTapGesture {
            if let first = items.first { onDetail(first) } // 占位触发新建路径
        }
    }
}
