import SwiftUI
import SwiftData

/// 打卡编辑/新建 d3（V0.4.1 ③）
/// 字段：标题（必填）/描述/提醒时间 chips（19:00~22:00+不提醒）；iOS 删除规则
struct CheckInEditView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext
    let itemID: String?

    @State private var title: String = ""
    @State private var desc: String = ""
    @State private var remindHour: Int? = 19
    @State private var remindMinute: Int? = 0
    @State private var toast: Toast?
    @State private var loaded: Bool = false

    private let timeOptions: [(hour: Int, minute: Int)] = [
        (19, 0), (19, 30), (20, 0), (20, 30), (21, 0), (21, 30), (22, 0)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 21) {
                    field("标题") {
                        TextField("必填，如「抱抱宝宝」", text: $title)
                            .padding(14)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    field("描述") {
                        TextField("一句描述", text: $desc, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(14)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    field("提醒时间") {
                        FlowLayout(spacing: 7) {
                            chip("不提醒", hour: nil, minute: nil)
                            ForEach(timeOptions, id: \.hour) { opt in
                                chip(String(format: "%02d:%02d", opt.hour, opt.minute),
                                     hour: opt.hour, minute: opt.minute)
                            }
                        }
                    }
                    saveButton
                }
                .padding(14)
            }
            .navigationTitle(itemID == nil ? "新建打卡项" : "编辑打卡项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { state.backOneLevel() }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = toast { ToastView(toast: toast).padding(.bottom, 32) }
            }
            .task { await loadItem() }
        }
    }

    @ViewBuilder
    private func field<C: View>(_ name: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.inkSecondary)
            content()
        }
    }

    private func chip(_ label: String, hour: Int?, minute: Int?) -> some View {
        let isSelected = (remindHour == hour) && (remindMinute == minute)
        return Text(label)
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? DesignTokens.m1Orange.opacity(0.22) :
                        Color.gray.opacity(0.08))
            .clipShape(Capsule())
            .onTapGesture {
                remindHour = hour
                remindMinute = minute
            }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("保存")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(DesignTokens.m1Orange)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func save() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            toast = Toast(module: .checkIn, text: "标题不能为空")
            return
        }
        if let id = itemID.flatMap(UUID.init(uuidString:)) {
            let fetchDesc = FetchDescriptor<CheckInItem>(predicate: #Predicate { $0.id == id })
            if let item = try? modelContext.fetch(fetchDesc).first {
                item.title = title
                item.desc = desc
                item.remindHour = remindHour
                item.remindMinute = remindMinute
                try? modelContext.save()
            }
        } else {
            let item = CheckInItem(title: title, desc: desc,
                                   remindHour: remindHour, remindMinute: remindMinute)
            modelContext.insert(item)
            try? modelContext.save()
        }
        toast = Toast(module: .checkIn, text: "已保存")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            state.backOneLevel()
        }
    }

    private func loadItem() async {
        guard !loaded else { return }
        loaded = true
        guard let id = itemID.flatMap(UUID.init(uuidString:)) else { return }
        let fetchDesc = FetchDescriptor<CheckInItem>(predicate: #Predicate { $0.id == id })
        if let item = try? modelContext.fetch(fetchDesc).first {
            title = item.title
            desc = item.desc
            remindHour = item.remindHour
            remindMinute = item.remindMinute
        }
    }
}
