import SwiftUI

/// 四个一级模块（朝向↔模块映射 R4）
enum ModuleKey: String, CaseIterable, Identifiable, Codable {
    case checkIn   // M1 温情打卡（竖正）
    case thought   // M2 今天的想法（竖倒）
    case hub       // M3 生活情报站（左横）
    case game      // M4 益智小游戏（右横）

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .checkIn: return "温情打卡"
        case .thought: return "今天的想法"
        case .hub: return "生活情报站"
        case .game: return "益智小游戏"
        }
    }

    var glyph: String {
        switch self {
        case .checkIn: return "心"
        case .thought: return "思"
        case .hub: return "知"
        case .game: return "玩"
        }
    }

    var themeColor: Color {
        switch self {
        case .checkIn: return Color(red: 0xFF/255, green: 0x95/255, blue: 0x00/255) // 系统橙
        case .thought: return Color(red: 0xAF/255, green: 0x52/255, blue: 0xDE/255) // 系统紫
        case .hub: return Color(red: 0x34/255, green: 0xC7/255, blue: 0x59/255) // 系统绿
        case .game: return Color(red: 0xFF/255, green: 0xCC/255, blue: 0x00/255) // 系统黄
        }
    }

    var themeHex: String {
        switch self {
        case .checkIn: return "#FF9500"
        case .thought: return "#AF52DE"
        case .hub: return "#34C759"
        case .game: return "#FFCC00"
        }
    }

    var fromDirection: Axis {
        switch self {
        case .checkIn: return .vertical
        case .thought: return .vertical
        case .hub: return .horizontal
        case .game: return .horizontal
        }
    }

    init?(orientation: DeviceOrientation) {
        switch orientation {
        case .portrait: self = .checkIn
        case .portraitUpsideDown: self = .thought
        case .landscapeLeft: self = .hub
        case .landscapeRight: self = .game
        case .faceUp, .faceDown: return nil
        }
    }
}

enum Axis {
    case vertical
    case horizontal
}
