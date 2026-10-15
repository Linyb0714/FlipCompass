import SwiftUI
import SwiftData

/// M1 温情打卡 根视图（V0.4.1）
/// 分组页：P0 清单 / P1 统计（热力图+周条） / P2 条目管理（iOS 删除）
struct CheckInRootView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext
    @State private var items: [CheckInItem] = []
    @State private var pageIndex: Int = 0
    @State private var selection: Int = 0
    @State private var toast: Toast?
    private let pages = ["清单", "统计", "管理"]

    var body: some View {
        VStack(spacing: 0) {
            // 分组 tabs
            HStack(spacing: 7) {
                ForEach(Array(pages.enumerated()), id: \.0) { idx, title in
                    Text(title)
                        .font(.system(size: 13, weight: idx == pageIndex ? .semibold : .regular))
                        .foregroundStyle(idx == pageIndex ? DesignTokens.ink : DesignTokens.inkSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(idx == pageIndex ?
                                    DesignTokens.m1Orange.opacity(0.16) : Color.clear)
                        .clipShape(Capsule())
                        .onTapGesture {
                            withAnimation(DesignTokens.springEase) { pageIndex = idx }
                        }
                }
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 7)

            ZStack {
                switch pageIndex {
                case 0: CheckInListView(items: items,
                                        selection: selection,
                                        onSelect: { idx in selection = idx },
                                        onToggle: { item in toggleDone(item) },
                                        onDetail: { item in enterDetail(item, page: "detail") })
                case 1: CheckInStatsView(items: items)
                case 2: CheckInManageView(items: items,
                                          onEdit: { item in enterDetail(item, page: "edit") },
                                          onNew: { enterDetail(nil, page: "edit") },
                                          onDelete: { item in delete(item) },
                                          onChange: { refresh() })
                default: EmptyView()
                }
            }
            .padding(.top, 4)
        }
        .overlay(alignment: .bottom) {
            if let toast = toast { ToastView(toast: toast).padding(.bottom, 32) }
        }
        .task { await seedIfNeeded(); refresh() }
        .onChange(of: state.level) { refresh() }
    }

    // MARK: - 数据操作
    private func toggleDone(_ item: CheckInItem) {
        Task {
            let provider = CheckInProvider(context: modelContext)
            let cal = Calendar.current
            let doneToday = item.records.contains { cal.isDateInToday($0.doneAt) }
            do {
                if doneToday {
                    toast = Toast(module: .checkIn,
                                  text: "今天已完成 · \(todayTime(item))")
                } else {
                    let record = try provider.checkToday(item: item)
                    _ = record
                    let s = provider.streak(of: item)
                    toast = Toast(module: .checkIn,
                                  text: "打卡成功 💛 连续第 \(s) 天")
                }
                refresh()
            } catch {
                toast = Toast(module: .checkIn, text: "出错了：\(error.localizedDescription)")
            }
        }
    }

    private func enterDetail(_ item: CheckInItem?, page: String) {
        let route = DetailRoute(module: .checkIn,
                                 pageKey: page,
                                 itemID: item?.id.uuidString)
        state.enterDetail(route)
    }

    private func delete(_ item: CheckInItem) {
        modelContext.delete(item)
        try? modelContext.save()
        refresh()
        toast = Toast(module: .checkIn, text: "已删除")
    }

    private func refresh() {
        let provider = CheckInProvider(context: modelContext)
        if let fetched = try? provider.todayItems() {
            items = fetched
        }
    }

    private func todayTime(_ item: CheckInItem) -> String {
        let cal = Calendar.current
        let record = item.records.last { cal.isDateInToday($0.doneAt) }
        guard let r = record else { return "--:--" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: r.doneAt)
    }

    private func seedIfNeeded() async {
        let provider = CheckInProvider(context: modelContext)
        if let existing = try? provider.todayItems(), existing.isEmpty {
            let seeds = [
                CheckInItem(title: "抱抱宝宝", desc: "今天给宝宝一个温暖的拥抱", sortOrder: 0),
                CheckInItem(title: "拥抱爱人", desc: "一句我爱你", remindHour: 19, remindMinute: 30, sortOrder: 1),
                CheckInItem(title: "陪家人散步", desc: "晚饭后一起走走", remindHour: 20, sortOrder: 2),
                CheckInItem(title: "给爸妈打电话", desc: "聊聊近况", remindHour: 21, sortOrder: 3),
            ]
            for item in seeds { modelContext.insert(item) }
            try? modelContext.save()
        }
    }
}

// MARK: - Toast
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let module: ModuleKey
    let text: String
}

struct ToastView: View {
    let toast: Toast
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(toast.module.themeColor).frame(width: 8, height: 8)
                .shadow(color: toast.module.themeColor.opacity(0.8), radius: 5)
            Text(toast.text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                Capsule().fill(Color(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255).opacity(0.78))
                Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        )
        .shadow(color: toast.module.themeColor.opacity(0.16), radius: 12)
        .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
