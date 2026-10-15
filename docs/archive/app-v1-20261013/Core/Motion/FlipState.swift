import Foundation

/// 四态状态机（R8 已确认）：IDLE → FLIPPING → SETTLING → CONFIRMED
enum FlipState: Equatable, Hashable {
    case idle
    case flipping(target: DeviceOrientation)
    case settling(target: DeviceOrientation)
    case confirmed

    var rawValue: String {
        switch self {
        case .idle: return "idle"
        case .flipping(let t): return "flipping:\(t.rawValue)"
        case .settling(let t): return "settling:\(t.rawValue)"
        case .confirmed: return "confirmed"
        }
    }

    static func == (lhs: FlipState, rhs: FlipState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.confirmed, .confirmed): return true
        case (.flipping(let a), .flipping(let b)): return a == b
        case (.settling(let a), .settling(let b)): return a == b
        default: return false
        }
    }
}
