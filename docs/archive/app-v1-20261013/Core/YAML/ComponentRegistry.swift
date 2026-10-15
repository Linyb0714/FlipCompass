import SwiftUI

/// 组件注册表（T2 安全模型：闭合集，市场 YAML 无法执行任意代码）
/// 14 基础组件 + 4 布局，IR → SwiftUI 渲染
enum ComponentRegistry {
    static func render(_ layout: DSLLayout, ctx: YAMLContext) -> AnyView {
        switch layout {
        case .vstack(let children, let spacing):
            return AnyView(
                VStack(spacing: spacing.map { CGFloat($0) }) {
                    ForEach(Array(children.enumerated()), id: \.0) { _, c in
                        render(c, ctx: ctx)
                    }
                }
            )
        case .hstack(let children, let spacing):
            return AnyView(
                HStack(spacing: spacing.map { CGFloat($0) }) {
                    ForEach(Array(children.enumerated()), id: \.0) { _, c in
                        render(c, ctx: ctx)
                    }
                }
            )
        case .list(let items, let template):
            let values = ctx.resolveArray(items)
            return AnyView(
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(values.enumerated()), id: \.0) { _, item in
                            render(template, ctx: ctx.injecting(item: .string(item)))
                        }
                    }
                }
            )
        case .grid(let cols, let items, let template):
            let values = ctx.resolveArray(items)
            let columns = Array(repeating: GridItem(.flexible()), count: cols)
            return AnyView(
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(values.enumerated()), id: \.0) { _, item in
                            render(template, ctx: ctx.injecting(item: .string(item)))
                        }
                    }
                }
            )
        case .text(let v, let style):
            return AnyView(
                Text(ctx.resolve(v))
                    .font(resolveFont(style?.font))
                    .fontWeight(resolveWeight(style?.weight))
                    .foregroundStyle(resolveColor(style?.color))
            )
        case .image(let r):
            return AnyView(
                Image(systemName: ctx.resolve(r))
                    .imageScale(.large)
            )
        case .icon(let r):
            return AnyView(
                Image(systemName: ctx.resolve(r))
            )
        case .card(let title, let sub, let children):
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    Text(ctx.resolve(title)).font(.headline)
                    if let sub = sub {
                        Text(ctx.resolve(sub)).font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 4) {
                        ForEach(Array(children.enumerated()), id: \.0) { _, c in
                            render(c, ctx: ctx)
                        }
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 21))
            )
        case .button(let label, let action):
            return AnyView(
                Button {
                    ctx.dispatch(action)
                } label: {
                    Text(ctx.resolve(label))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.accentColor.opacity(0.16))
                        .clipShape(Capsule())
                }
            )
        case .textEditor(let field, let placeholder):
            return AnyView(
                TextEditor(text: ctx.binding(for: field))
                    .overlay(alignment: .topLeading) {
                        if let placeholder, ctx.binding(for: field).wrappedValue.isEmpty {
                            Text(placeholder).foregroundStyle(.tertiary).padding(8)
                        }
                    }
                    .frame(minHeight: 84)
            )
        case .tagPicker(let field, let options):
            return AnyView(
                FlowLayout(spacing: 7) {
                    ForEach(options, id: \.self) { opt in
                        let isSelected = ctx.binding(for: field).wrappedValue == opt
                        Text(opt)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(isSelected ? Color.accentColor.opacity(0.22) : Color.gray.opacity(0.08))
                            .clipShape(Capsule())
                            .onTapGesture { ctx.binding(for: field).wrappedValue = opt }
                    }
                }
            )
        case .toggle(let field, let label):
            return AnyView(
                Toggle(ctx.resolve(label), isOn: boolBinding(ctx, field))
            )
        case .slider(let field, let min, let max):
            return AnyView(
                Slider(value: doubleBinding(ctx, field), in: min...max)
            )
        case .progress(let value, let total):
            return AnyView(
                ProgressView(value: min(value, total), total: total)
            )
        case .emptyState(let title, let hint):
            return AnyView(
                VStack(spacing: 7) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text(ctx.resolve(title)).font(.headline)
                    if let hint {
                        Text(ctx.resolve(hint)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            )
        case .calendarHeatmap(let field):
            return AnyView(
                CalendarHeatmapView(data: ctx.resolveArray(field))
            )
        case .countdownCard(let field):
            return AnyView(
                CountdownCardView(date: ctx.resolve(field))
            )
        }
    }

    // MARK: - helpers
    static func resolveFont(_ name: String?) -> Font {
        switch name ?? "body" {
        case "title": return .title2
        case "largeTitle": return .largeTitle
        case "headline": return .headline
        case "body": return .body
        case "caption": return .caption
        default: return .body
        }
    }

    static func resolveWeight(_ name: String?) -> Font.Weight? {
        switch name ?? "regular" {
        case "bold": return .bold
        case "semibold": return .semibold
        case "medium": return .medium
        case "light": return .light
        default: return .regular
        }
    }

    static func resolveColor(_ name: String?) -> Color {
        switch name ?? "primary" {
        case "primary": return .primary
        case "secondary": return .secondary
        case "accent": return .accentColor
        case "orange": return Color(red: 0xFF/255, green: 0x95/255, blue: 0x00/255)
        case "purple": return Color(red: 0xAF/255, green: 0x52/255, blue: 0xDE/255)
        case "green": return Color(red: 0x34/255, green: 0xC7/255, blue: 0x59/255)
        case "yellow": return Color(red: 0xFF/255, green: 0xCC/255, blue: 0x00/255)
        case "success": return Color(red: 0x22/255, green: 0xc5/255, blue: 0x5e/255)
        case "error": return Color(red: 0xf5/255, green: 0x22/255, blue: 0x2d/255)
        default: return .primary
        }
    }

    static func boolBinding(_ ctx: YAMLContext, _ field: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { (ctx.binding(for: field).wrappedValue.lowercased() == "true") },
            set: { v in ctx.binding(for: field).wrappedValue = v ? "true" : "false" }
        )
    }

    static func doubleBinding(_ ctx: YAMLContext, _ field: String) -> Binding<Double> {
        Binding<Double>(
            get: { Double(ctx.binding(for: field).wrappedValue) ?? 0 },
            set: { v in ctx.binding(for: field).wrappedValue = String(v) }
        )
    }
}

// MARK: - 上下文（绑定/插值/Provider 数据源）
final class YAMLContext: ObservableObject {
    @Published var draft: [String: String]
    var item: BoundValue?
    let provider: ProviderHost
    let dispatcher: (DSLAction) -> Void

    init(draft: [String: String] = [:],
         item: BoundValue? = nil,
         provider: ProviderHost = ProviderHost.preview(),
         dispatcher: @escaping (DSLAction) -> Void = { _ in }) {
        self.draft = draft
        self.item = item
        self.provider = provider
        self.dispatcher = dispatcher
    }

    func resolve(_ key: String) -> String {
        // ${item.title} / $draft.field / 普通字符串
        if key.hasPrefix("${item.") {
            let k = String(key.dropFirst("${item.".count).dropLast())
            return item?.resolve(k) ?? ""
        }
        if key.hasPrefix("$draft.") {
            let k = String(key.dropFirst("$draft.".count))
            return draft[k] ?? ""
        }
        return key
    }

    func resolveArray(_ key: String) -> [String] {
        if key.hasPrefix("$provider.") {
            let k = String(key.dropFirst("$provider.".count))
            return provider.array(for: k)
        }
        if key.hasPrefix("${item.") {
            let v = resolve(key)
            return v.split(separator: ",").map { String($0) }
        }
        return [resolve(key)]
    }

    func binding(for field: String) -> Binding<String> {
        Binding(
            get: { self.draft[field] ?? "" },
            set: { self.draft[field] = $0 }
        )
    }

    func injecting(item: BoundValue) -> YAMLContext {
        let n = YAMLContext(draft: draft, item: item, provider: provider, dispatcher: dispatcher)
        return n
    }

    func dispatch(_ action: DSLAction) {
        dispatcher(action)
    }
}

enum BoundValue {
    case string(String)
    case dict([String: String])

    func resolve(_ key: String) -> String {
        switch self {
        case .string(let s): return s
        case .dict(let d): return d[key] ?? ""
        }
    }
}

/// Provider 宿主（一期内置模块直连 SwiftData，市场模块仅 KV）
final class ProviderHost: ObservableObject {
    var values: [String: [String]] = [:]
    static func preview() -> ProviderHost {
        let h = ProviderHost()
        h.values = ["checkin.todayItems": ["抱抱宝宝", "拥抱爱人", "陪家人散步", "给爸妈打电话"]]
        return h
    }
    func array(for key: String) -> [String] { values[key] ?? [] }
}
