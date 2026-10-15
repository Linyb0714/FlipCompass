import Foundation

/// 动作白名单闭合集（T2 安全模型）—— 校验、解释、附加审核
/// 仅允许：navigate / pop / submit / toggle / setValue / haptic
/// 任何不在此列表内的动作声明会被 DSLParser 直接拒绝（IR 反序列化失败）
enum ActionWhitelist {
    static let allowedActions: Set<String> = [
        "navigate", "pop", "submit", "toggle", "set-value", "haptic"
    ]

    static func isAllowed(_ type: String) -> Bool {
        allowedActions.contains(type)
    }

    static func describe(_ action: DSLAction) -> String {
        switch action {
        case .navigate(let pageKey, _): return "navigate → \(pageKey)"
        case .pop: return "pop"
        case .submit(let form): return "submit ∷ \(form)"
        case .toggle(let field): return "toggle ∷ \(field)"
        case .setValue(let field, let value): return "set \(field) = \(value)"
        case .haptic(let style): return "haptic ∷ \(style)"
        }
    }

    /// 安全审核：导航目标必须在白名单页面内（防止越权）
    static func validateNavigate(pageKey: String,
                                  knownPages: Set<String>) -> Bool {
        knownPages.contains(pageKey)
    }
}
