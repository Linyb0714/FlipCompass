import SwiftUI
import SwiftData

/// M2 二级页 - 记录一条（d2 双子页：记录一条 / 草稿箱）
/// R8 草稿三件套核心：字级落盘 + 切走不打断 + 标记看得见
struct ThoughtComposeView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext

    let editingThoughtID: String?       // 非 nil = 编辑模式（V0.4.5 闭环）

    @State private var text: String = ""
    @State private var mood: String? = nil
    @State private var subTab: Int = 0  // 0=记录一条 1=草稿箱
    @State private var drafts: [Draft] = []
    @State private var toast: Toast?

    private let moods = ["开心", "平静", "感动", "疲惫", "焦虑", "期待"]
    private let moduleKey = "thought"
    private let pageKey = "compose"
    private let fieldKey = "content"

    var isEditing: Bool { editingThoughtID != nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            if !isEditing {
                tabs
            }
            if isEditing {
                editingBanner
            }

            if subTab == 0 || isEditing {
                composeBody
            } else {
                draftListBody
            }
        }
        .background(DesignTokens.bgPrimary.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast { ToastView(toast: toast).padding(.bottom, 32) }
        }
        .task { loadInitial() }
    }

    private var header: some View {
        HStack {
            Button(action: { state.backOneLevel() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
            }
            Spacer()
            Text(isEditing ? "编辑想法" : "记录一条")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignTokens.ink)
            Spacer()
            Button(action: publish) {
                Text(isEditing ? "保存" : "发布")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.m2Purple)
            }
        }
        .padding(.horizontal, DesignTokens.spacing)
        .padding(.vertical, 10)
    }

    private var tabs: some View {
        HStack(spacing: 7) {
            ForEach(Array(["记录一条", "草稿箱"].enumerated()), id: \.0) { idx, title in
                Text(title)
                    .font(.system(size: 12, weight: subTab == idx ? .semibold : .regular))
                    .foregroundStyle(subTab == idx ? DesignTokens.ink : DesignTokens.inkSecondary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(subTab == idx ? DesignTokens.m2Purple.opacity(0.14) : Color.clear)
                    .clipShape(Capsule())
                    .onTapGesture {
                        withAnimation(DesignTokens.springEase) { subTab = idx }
                    }
            }
            Spacer()
        }
        .padding(.horizontal, DesignTokens.spacing)
        .padding(.bottom, 6)
    }

    private var editingBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 12))
            Text("正在编辑 · 保存后覆盖原句")
                .font(.system(size: 12, weight: .medium))
            Spacer()
        }
        .foregroundStyle(DesignTokens.m2Purple)
        .padding(.horizontal, DesignTokens.spacing)
        .padding(.vertical, 8)
        .background(DesignTokens.m2Purple.opacity(0.08))
    }

    // MARK: - 记录一条
    private var composeBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacing) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.system(size: 17))
                        .foregroundStyle(DesignTokens.ink)
                        .frame(minHeight: 140)
                        .padding(4)
                        .scrollContentBackground(.hidden)
                        .onChange(of: text) { _, new in
                            if !isEditing {
                                persistDraft(new)
                            }
                        }
                    if text.isEmpty {
                        Text("写一句今天的想法…")
                            .font(.system(size: 17))
                            .foregroundStyle(DesignTokens.inkSecondary.opacity(0.5))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
                .padding(DesignTokens.spacing)
                .glassCard(moduleColor: DesignTokens.m2Purple)

                VStack(alignment: .leading, spacing: 8) {
                    Text("心情标签")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignTokens.inkSecondary)
                    FlowLayout(spacing: 8) {
                        ForEach(moods, id: \.self) { m in
                            Text(m)
                                .font(.system(size: 13, weight: mood == m ? .semibold : .regular))
                                .foregroundStyle(mood == m ? .white : DesignTokens.ink)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(mood == m ? DesignTokens.m2Purple : DesignTokens.bgSecondary)
                                .clipShape(Capsule())
                                .onTapGesture {
                                    withAnimation(DesignTokens.springEase) {
                                        mood = (mood == m) ? nil : m
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, DesignTokens.spacing)
            .padding(.vertical, DesignTokens.spacing)
        }
    }

    // MARK: - 草稿箱
    private var draftListBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacing) {
                if drafts.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 28))
                            .foregroundStyle(DesignTokens.m2Purple.opacity(0.4))
                        Text("没有未写完的")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignTokens.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(drafts, id: \.id) { d in
                        DraftRow(draft: d,
                                 onResume: { resumeDraft(d) },
                                 onDelete: { deleteDraft(d) })
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacing)
            .padding(.vertical, DesignTokens.spacing)
        }
    }

    // MARK: - 数据操作
    private func loadInitial() {
        if let idStr = editingThoughtID,
           let uuid = UUID(uuidString: idStr),
           let t = fetchThought(uuid) {
            text = t.content
            mood = t.mood
        } else {
            // 进入 d2 默认回填最新草稿（草稿 = 当前写作态）
            refreshDrafts()
            if let latest = drafts.first {
                text = latest.payload
            }
        }
    }

    private func refreshDrafts() {
        let dp = DraftProvider(context: modelContext)
        drafts = (try? dp.drafts(module: moduleKey, page: pageKey)) ?? []
    }

    private func fetchThought(_ uuid: UUID) -> Thought? {
        let desc = FetchDescriptor<Thought>(predicate: #Predicate { $0.id == uuid })
        return try? modelContext.fetch(desc).first
    }

    /// R8：字级落盘（同 fieldKey 覆盖；空内容清除）
    private func persistDraft(_ newText: String) {
        let dp = DraftProvider(context: modelContext)
        _ = try? dp.upsert(module: moduleKey, page: pageKey, field: fieldKey, payload: newText)
        refreshDrafts()
    }

    private func resumeDraft(_ d: Draft) {
        text = d.payload
        withAnimation(DesignTokens.springEase) { subTab = 0 }
    }

    private func deleteDraft(_ d: Draft) {
        let dp = DraftProvider(context: modelContext)
        try? dp.remove(d)
        refreshDrafts()
        toast = Toast(module: .thought, text: "已删除草稿")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toast?.text == "已删除草稿" { toast = nil }
        }
    }

    private func publish() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            toast = Toast(module: .thought, text: "写一句再发哦")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if toast?.text == "写一句再发哦" { toast = nil }
            }
            return
        }

        let tp = ThoughtProvider(context: modelContext)
        let dp = DraftProvider(context: modelContext)

        if let idStr = editingThoughtID,
           let uuid = UUID(uuidString: idStr),
           let existing = fetchThought(uuid) {
            // 编辑模式：就地更新，不动草稿
            try? tp.update(existing, content: trimmed, mood: mood)
            toast = Toast(module: .thought, text: "已保存")
        } else {
            // 新建模式：发布 + 草稿出栈
            let t = Thought(content: trimmed, mood: mood)
            try? tp.insert(t)
            try? dp.remove(module: moduleKey, page: pageKey, field: fieldKey)
            toast = Toast(module: .thought, text: "已记下")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            state.backOneLevel()
        }
    }
}

// MARK: - 草稿卡
private struct DraftRow: View {
    let draft: Draft
    let onResume: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.payload)
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(2)
                Text(timeString)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.inkSecondary)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(DesignTokens.error)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(moduleColor: DesignTokens.m2Purple)
        .onTapGesture { onResume() }
    }

    private var timeString: String {
        let f = DateFormatter(); f.dateFormat = "MM-dd HH:mm"
        return f.string(from: draft.updatedAt)
    }
}

// FlowLayout 复用 Core/YAML/ComponentExtras.swift 中的共享实现
