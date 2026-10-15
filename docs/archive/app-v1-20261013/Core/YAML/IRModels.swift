import Foundation

// MARK: - YAML DSL 强类型 IR（T2 渲染管线：Yams → IR → 组件注册表 → SwiftUI 树）

/// 模块包清单（module.yaml）
struct ModuleManifest: Codable, Equatable {
    let moduleKey: String
    let displayName: String
    let version: String
    let pages: [String]              // 引用的页面文件名
    let assets: [String]?
    let network: NetworkConfig?      // 一期预留，不启用
}

struct NetworkConfig: Codable, Equatable {
    let endpoint: String?
    let note: String?               // "未启用" 标记
}

/// DSL 顶层：pages（多页定义，多级页面栈靠 navigate 跳）
struct DSLPage: Codable, Equatable {
    let key: String                 // 页面唯一键
    let layout: DSLLayout           // 嵌套容器/children
    let bind: [String: String]?     // $draft.*/${item.*} 插值/provider 数据源
    let onTap: DSLAction?           // 顶层动作
}

/// 嵌套容器：4 布局 + 14 基础组件
indirect enum DSLLayout: Codable, Equatable {
    case vstack(children: [DSLLayout], spacing: Int?)
    case hstack(children: [DSLLayout], spacing: Int?)
    case list(items: String, template: DSLLayout)  // items=数据绑定，template=每行布局
    case grid(cols: Int, items: String, template: DSLLayout)

    case text(String, DSLTextStyle?)
    case image(String)                              // 资源名/SFSymbol
    case icon(String)                               // SF Symbol
    case card(title: String, subtitle: String?, children: [DSLLayout])
    case button(label: String, action: DSLAction)
    case textEditor(field: String, placeholder: String?)
    case tagPicker(field: String, options: [String])
    case toggle(field: String, label: String)
    case slider(field: String, min: Double, max: Double)
    case progress(value: Double, total: Double)
    case emptyState(title: String, hint: String?)
    case calendarHeatmap(field: String)            // 用户补充（T2）
    case countdownCard(field: String)              // 用户补充（T2）

    enum CodingKeys: String, CodingKey {
        case type, children, spacing, items, template, cols, value, total,
             title, subtitle, label, action, field, placeholder, options,
             min, max, hint, resource, style
    }

    // 解码：根据 type 分流
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let t = try c.decode(String.self, forKey: .type)
        switch t {
        case "vstack":
            let ch = try c.decode([DSLLayout].self, forKey: .children)
            let sp = try c.decodeIfPresent(Int.self, forKey: .spacing)
            self = .vstack(children: ch, spacing: sp)
        case "hstack":
            let ch = try c.decode([DSLLayout].self, forKey: .children)
            let sp = try c.decodeIfPresent(Int.self, forKey: .spacing)
            self = .hstack(children: ch, spacing: sp)
        case "list":
            let items = try c.decode(String.self, forKey: .items)
            let tmpl = try c.decode(DSLLayout.self, forKey: .template)
            self = .list(items: items, template: tmpl)
        case "grid":
            let cols = try c.decode(Int.self, forKey: .cols)
            let items = try c.decode(String.self, forKey: .items)
            let tmpl = try c.decode(DSLLayout.self, forKey: .template)
            self = .grid(cols: cols, items: items, template: tmpl)
        case "text":
            let v = try c.decode(String.self, forKey: .value)
            let s = try c.decodeIfPresent(DSLTextStyle.self, forKey: .style)
            self = .text(v, s)
        case "image":
            let r = try c.decode(String.self, forKey: .resource)
            self = .image(r)
        case "icon":
            let r = try c.decode(String.self, forKey: .resource)
            self = .icon(r)
        case "card":
            let title = try c.decode(String.self, forKey: .title)
            let sub = try c.decodeIfPresent(String.self, forKey: .subtitle)
            let ch = try c.decode([DSLLayout].self, forKey: .children)
            self = .card(title: title, subtitle: sub, children: ch)
        case "button":
            let label = try c.decode(String.self, forKey: .label)
            let action = try c.decode(DSLAction.self, forKey: .action)
            self = .button(label: label, action: action)
        case "text-editor":
            let field = try c.decode(String.self, forKey: .field)
            let placeholder = try c.decodeIfPresent(String.self, forKey: .placeholder)
            self = .textEditor(field: field, placeholder: placeholder)
        case "tag-picker":
            let field = try c.decode(String.self, forKey: .field)
            let options = try c.decode([String].self, forKey: .options)
            self = .tagPicker(field: field, options: options)
        case "toggle":
            let field = try c.decode(String.self, forKey: .field)
            let label = try c.decode(String.self, forKey: .label)
            self = .toggle(field: field, label: label)
        case "slider":
            let field = try c.decode(String.self, forKey: .field)
            let min = try c.decode(Double.self, forKey: .min)
            let max = try c.decode(Double.self, forKey: .max)
            self = .slider(field: field, min: min, max: max)
        case "progress":
            let value = try c.decode(Double.self, forKey: .value)
            let total = try c.decode(Double.self, forKey: .total)
            self = .progress(value: value, total: total)
        case "empty-state":
            let title = try c.decode(String.self, forKey: .title)
            let hint = try c.decodeIfPresent(String.self, forKey: .hint)
            self = .emptyState(title: title, hint: hint)
        case "calendar-heatmap":
            let field = try c.decode(String.self, forKey: .field)
            self = .calendarHeatmap(field: field)
        case "countdown-card":
            let field = try c.decode(String.self, forKey: .field)
            self = .countdownCard(field: field)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c,
                debugDescription: "未知组件类型: \(t)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .vstack(let ch, let sp):
            try c.encode("vstack", forKey: .type)
            try c.encode(ch, forKey: .children)
            try c.encodeIfPresent(sp, forKey: .spacing)
        case .hstack(let ch, let sp):
            try c.encode("hstack", forKey: .type)
            try c.encode(ch, forKey: .children)
            try c.encodeIfPresent(sp, forKey: .spacing)
        case .list(let items, let tmpl):
            try c.encode("list", forKey: .type)
            try c.encode(items, forKey: .items)
            try c.encode(tmpl, forKey: .template)
        case .grid(let cols, let items, let tmpl):
            try c.encode("grid", forKey: .type)
            try c.encode(cols, forKey: .cols)
            try c.encode(items, forKey: .items)
            try c.encode(tmpl, forKey: .template)
        case .text(let v, let s):
            try c.encode("text", forKey: .type)
            try c.encode(v, forKey: .value)
            try c.encodeIfPresent(s, forKey: .style)
        case .image(let r):
            try c.encode("image", forKey: .type)
            try c.encode(r, forKey: .resource)
        case .icon(let r):
            try c.encode("icon", forKey: .type)
            try c.encode(r, forKey: .resource)
        case .card(let title, let sub, let ch):
            try c.encode("card", forKey: .type)
            try c.encode(title, forKey: .title)
            try c.encodeIfPresent(sub, forKey: .subtitle)
            try c.encode(ch, forKey: .children)
        case .button(let label, let action):
            try c.encode("button", forKey: .type)
            try c.encode(label, forKey: .label)
            try c.encode(action, forKey: .action)
        case .textEditor(let field, let placeholder):
            try c.encode("text-editor", forKey: .type)
            try c.encode(field, forKey: .field)
            try c.encodeIfPresent(placeholder, forKey: .placeholder)
        case .tagPicker(let field, let options):
            try c.encode("tag-picker", forKey: .type)
            try c.encode(field, forKey: .field)
            try c.encode(options, forKey: .options)
        case .toggle(let field, let label):
            try c.encode("toggle", forKey: .type)
            try c.encode(field, forKey: .field)
            try c.encode(label, forKey: .label)
        case .slider(let field, let min, let max):
            try c.encode("slider", forKey: .type)
            try c.encode(field, forKey: .field)
            try c.encode(min, forKey: .min)
            try c.encode(max, forKey: .max)
        case .progress(let value, let total):
            try c.encode("progress", forKey: .type)
            try c.encode(value, forKey: .value)
            try c.encode(total, forKey: .total)
        case .emptyState(let title, let hint):
            try c.encode("empty-state", forKey: .type)
            try c.encode(title, forKey: .title)
            try c.encodeIfPresent(hint, forKey: .hint)
        case .calendarHeatmap(let field):
            try c.encode("calendar-heatmap", forKey: .type)
            try c.encode(field, forKey: .field)
        case .countdownCard(let field):
            try c.encode("countdown-card", forKey: .type)
            try c.encode(field, forKey: .field)
        }
    }
}

struct DSLTextStyle: Codable, Equatable {
    let font: String                // title / body / caption / largeTitle
    let color: String?
    let weight: String?
}

/// 动作白名单（T2 安全模型闭合集）：navigate/pop/submit/toggle/setValue/haptic
indirect enum DSLAction: Codable, Equatable {
    case navigate(pageKey: String, payload: [String: String]?)
    case pop
    case submit(form: String)
    case toggle(field: String)
    case setValue(field: String, value: String)
    case haptic(style: String)

    enum CodingKeys: String, CodingKey {
        case type, pageKey, payload, form, field, value, style
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let t = try c.decode(String.self, forKey: .type)
        switch t {
        case "navigate":
            let pageKey = try c.decode(String.self, forKey: .pageKey)
            let payload = try c.decodeIfPresent([String: String].self, forKey: .payload) ?? [:]
            self = .navigate(pageKey: pageKey, payload: payload)
        case "pop":
            self = .pop
        case "submit":
            let form = try c.decode(String.self, forKey: .form)
            self = .submit(form: form)
        case "toggle":
            let field = try c.decode(String.self, forKey: .field)
            self = .toggle(field: field)
        case "set-value":
            let field = try c.decode(String.self, forKey: .field)
            let value = try c.decode(String.self, forKey: .value)
            self = .setValue(field: field, value: value)
        case "haptic":
            let style = try c.decode(String.self, forKey: .style)
            self = .haptic(style: style)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c,
                debugDescription: "动作不在白名单内: \(t)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .navigate(let pageKey, let payload):
            try c.encode("navigate", forKey: .type)
            try c.encode(pageKey, forKey: .pageKey)
            try c.encode(payload, forKey: .payload)
        case .pop:
            try c.encode("pop", forKey: .type)
        case .submit(let form):
            try c.encode("submit", forKey: .type)
            try c.encode(form, forKey: .form)
        case .toggle(let field):
            try c.encode("toggle", forKey: .type)
            try c.encode(field, forKey: .field)
        case .setValue(let field, let value):
            try c.encode("set-value", forKey: .type)
            try c.encode(field, forKey: .field)
            try c.encode(value, forKey: .value)
        case .haptic(let style):
            try c.encode("haptic", forKey: .type)
            try c.encode(style, forKey: .style)
        }
    }
}
