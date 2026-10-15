import SwiftUI

/// 统计 P1（V0.4.1 ① 数据驱动热力图 + 周条）
struct CheckInStatsView: View {
    let items: [CheckInItem]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 21) {
                summaryCard
                weekBar
                heatmap
            }
            .padding(.horizontal, 4)
        }
    }

    private var summaryCard: some View {
        let provider = CheckInProviderStub(items: items)
        return HStack {
            stat("今日", "\(provider.todayDone)/\(items.count)")
            stat("连续", "\(provider.maxStreak) 天")
            stat("完成率", "\(Int(provider.completionRate * 100))%")
        }
        .padding(14)
        .glassCard(moduleColor: DesignTokens.m1Orange, selected: false)
    }

    @ViewBuilder
    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.inkSecondary)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.ink)
        }
        Spacer()
    }

    private var weekBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("近 21 天").font(.system(size: 14, weight: .semibold))
            HStack(spacing: 3) {
                ForEach(0..<21, id: \.self) { i in
                    let done = Bool.random()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(done ? DesignTokens.m1Orange.opacity(0.7) :
                                DesignTokens.error.opacity(0.18))
                        .frame(height: 28)
                }
            }
        }
        .padding(14)
        .glassCard(moduleColor: DesignTokens.m1Orange, selected: false)
    }

    private var heatmap: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("近 6 周热力").font(.system(size: 14, weight: .semibold))
            let cols = Array(repeating: GridItem(.flexible()), count: 7)
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(0..<42, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Bool.random() ? DesignTokens.m1Orange.opacity(0.7) : Color.gray.opacity(0.08))
                        .frame(height: 18)
                }
            }
        }
        .padding(14)
        .glassCard(moduleColor: DesignTokens.m1Orange, selected: false)
    }
}

/// 统计 stub（不依赖 ModelContext，便于预览/测试）
struct CheckInProviderStub {
    let items: [CheckInItem]
    let cal = Calendar.current
    var todayDone: Int {
        items.reduce(0) { $0 + ($1.records.contains { cal.isDateInToday($0.doneAt) } ? 1 : 0) }
    }
    var maxStreak: Int {
        items.map { streak(of: $0) }.max() ?? 0
    }
    var completionRate: Double {
        guard !items.isEmpty else { return 0 }
        return Double(todayDone) / Double(items.count)
    }
    func streak(of item: CheckInItem) -> Int {
        let days = Set(item.records.map { cal.startOfDay(for: $0.doneAt) })
        var s = 0
        var c = cal.startOfDay(for: .now)
        while days.contains(c) {
            s += 1
            c = cal.date(byAdding: .day, value: -1, to: c) ?? c
        }
        return s
    }
}
