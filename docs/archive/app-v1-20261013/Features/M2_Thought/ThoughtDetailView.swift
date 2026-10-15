import SwiftUI
import SwiftData

/// M2 二级页 - 想法详情（d9）
/// 字段：日期 / 心情胶囊 / 时间 / 全文 / 编辑·删除
struct ThoughtDetailView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext

    let itemID: String?

    @State private var thought: Thought? = nil
    @State private var toast: Toast?
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if let t = thought {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.spacing) {
                        metaSection(t)
                        contentSection(t)
                        actionsSection(t)
                    }
                    .padding(.horizontal, DesignTokens.spacing)
                    .padding(.vertical, DesignTokens.spacing)
                }
            } else {
                Spacer()
                Text("想法不存在")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.inkSecondary)
                Spacer()
            }
        }
        .background(DesignTokens.bgPrimary.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast { ToastView(toast: toast).padding(.bottom, 32) }
        }
        .task { load() }
        .confirmationDialog("删除这条想法？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) { performDelete() }
            Button("取消", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            Button(action: { state.backOneLevel() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
            }
            Spacer()
            Text("想法详情")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignTokens.ink)
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, DesignTokens.spacing)
        .padding(.vertical, 10)
    }

    private func metaSection(_ t: Thought) -> some View {
        HStack(spacing: 8) {
            Text(dateString(t.createdAt))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.inkSecondary)
            if let mood = t.mood, !mood.isEmpty {
                Text(mood)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.m2Purple)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(DesignTokens.m2Purple.opacity(0.14))
                    .clipShape(Capsule())
            }
            Spacer()
            Text(timeString(t.createdAt))
                .font(.system(size: 12, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.inkSecondary)
        }
    }

    private func contentSection(_ t: Thought) -> some View {
        Text(t.content)
            .font(.system(size: 16.5))
            .lineSpacing(14)
            .foregroundStyle(DesignTokens.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.spacing)
            .glassCard(moduleColor: DesignTokens.m2Purple)
    }

    private func actionsSection(_ t: Thought) -> some View {
        HStack(spacing: 12) {
            Button(action: enterEdit) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                    Text("编辑")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignTokens.m2Purple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(DesignTokens.m2Purple.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Button(action: { showDeleteConfirm = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("删除")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignTokens.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(DesignTokens.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func load() {
        guard let idStr = itemID, let uuid = UUID(uuidString: idStr) else { return }
        let desc = FetchDescriptor<Thought>(predicate: #Predicate { $0.id == uuid })
        thought = try? modelContext.fetch(desc).first
    }

    private func enterEdit() {
        guard let t = thought else { return }
        // 进入编辑：复用 d2（compose），传 thoughtID
        state.detailStack.append(DetailRoute(
            module: .thought, pageKey: "compose", itemID: t.id.uuidString
        ))
    }

    private func performDelete() {
        guard let t = thought else { return }
        let tp = ThoughtProvider(context: modelContext)
        try? tp.delete(t)
        toast = Toast(module: .thought, text: "已删除")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            state.backOneLevel()
        }
    }

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月 d 日"
        return f.string(from: d)
    }
    private func timeString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}
