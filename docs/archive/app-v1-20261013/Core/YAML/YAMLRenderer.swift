import SwiftUI

/// IR → SwiftUI 树渲染器（T2 终版管线最后一环）
/// 组件注册表闭合集 + 动作白名单闭合集（市场 YAML 天生无法执行任意代码）
struct YAMLRenderer: View {
    let page: DSLPage
    @StateObject var context: YAMLContext

    var body: some View {
        ComponentRegistry.render(page.layout, ctx: context)
    }
}

/// 模块运行时（加载模块包、按 pageKey 跳转、Provider 接入）
@MainActor
final class ModuleRuntime: ObservableObject {
    @Published var manifest: ModuleManifest
    @Published var pages: [String: DSLPage]
    @Published var currentPageKey: String
    @Published var detailStack: [String]
    let context: YAMLContext

    init(manifest: ModuleManifest,
         pages: [String: DSLPage],
         initialPage: String,
         context: YAMLContext) {
        self.manifest = manifest
        self.pages = pages
        self.currentPageKey = initialPage
        self.detailStack = []
        self.context = context
    }

    func renderCurrent() -> YAMLRenderer {
        let page = pages[currentPageKey] ?? pages.values.first
            ?? DSLPage(key: "empty", layout: .emptyState(title: "页面缺失", hint: nil), bind: nil, onTap: nil)
        return YAMLRenderer(page: page, context: self.context)
    }

    func dispatch(_ action: DSLAction) {
        switch action {
        case .navigate(let key, let payload):
            if pages[key] != nil {
                detailStack.append(currentPageKey)
                currentPageKey = key
                payload?.forEach { self.context.draft[$0.key] = $0.value }
            }
        case .pop:
            if let prev = detailStack.popLast() {
                currentPageKey = prev
            }
        case .submit, .toggle, .setValue, .haptic:
            self.context.dispatch(action)
        }
    }
}
