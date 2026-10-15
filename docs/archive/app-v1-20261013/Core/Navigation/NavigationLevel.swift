import Foundation

/// 三层导航状态机：L0 待机 → L1 一级目录 → L2 多级页面栈
enum NavigationLevel: Equatable, Hashable {
    case idle
    case module
    case detail
}

/// 设备物理朝向（覆盖四向翻转 + 平放）
enum DeviceOrientation: String, CaseIterable, Codable {
    case portrait           // 竖正：M1
    case portraitUpsideDown // 竖倒：M2
    case landscapeLeft      // 左横：M3
    case landscapeRight     // 右横：M4
    case faceUp             // 平放：待机
    case faceDown

    var azimuth: Double {
        switch self {
        case .portrait: return 0
        case .landscapeLeft: return 90
        case .portraitUpsideDown: return 180
        case .landscapeRight: return 270
        case .faceUp, .faceDown: return -1
        }
    }
}

/// 二级页面栈节点（R7 多级页面栈）
struct DetailRoute: Hashable, Identifiable {
    let id = UUID()
    let module: ModuleKey
    let pageKey: String
    let itemID: String?
    let payload: [String: String]

    init(module: ModuleKey, pageKey: String, itemID: String? = nil, payload: [String: String] = [:]) {
        self.module = module
        self.pageKey = pageKey
        self.itemID = itemID
        self.payload = payload
    }

    static func == (lhs: DetailRoute, rhs: DetailRoute) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension DeviceOrientation {
    static func == (lhs: DeviceOrientation, rhs: DeviceOrientation) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}
