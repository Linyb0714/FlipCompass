import Foundation
import SwiftData

// MARK: - 市场预留（二三期） + App 设置

/// 市场模块本地 KV（市场模块一期不实现，预留结构）
@Model
final class ModuleKV {
    @Attribute(.unique) var id: UUID
    var moduleKey: String           // 已安装的市场模块标识
    var key: String
    var value: String
    var updatedAt: Date

    init(id: UUID = UUID(), moduleKey: String, key: String,
         value: String = "", updatedAt: Date = .now) {
        self.id = id
        self.moduleKey = moduleKey
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }
}

/// 已安装市场模块登记
@Model
final class InstalledModule {
    @Attribute(.unique) var id: UUID
    var moduleKey: String
    var displayName: String
    var version: String
    var manifestURL: String          // 远端清单 URL（一期 Bundle 内置则填 bundle path）
    var installedAt: Date
    var enabled: Bool

    init(id: UUID = UUID(), moduleKey: String, displayName: String,
         version: String = "0.1.0", manifestURL: String = "",
         installedAt: Date = .now, enabled: Bool = true) {
        self.id = id
        self.moduleKey = moduleKey
        self.displayName = displayName
        self.version = version
        self.manifestURL = manifestURL
        self.installedAt = installedAt
        self.enabled = enabled
    }
}

/// App 设置 + 每模块导航位置记忆
@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID
    var hasSeenFirstRunGuide: Bool
    var lastModuleKey: String?          // 平放/启动前最后所在模块
    var lastModulePage: [String: Int]   // 每模块分组页位置记忆
    var lastModuleSelection: [String: Int] // 每模块选中条目
    var motionLogEnabled: Bool          // 真机调试日志开关

    init(id: UUID = UUID(), hasSeenFirstRunGuide: Bool = false,
         lastModuleKey: String? = nil,
         lastModulePage: [String: Int] = [:],
         lastModuleSelection: [String: Int] = [:],
         motionLogEnabled: Bool = true) {
        self.id = id
        self.hasSeenFirstRunGuide = hasSeenFirstRunGuide
        self.lastModuleKey = lastModuleKey
        self.lastModulePage = lastModulePage
        self.lastModuleSelection = lastModuleSelection
        self.motionLogEnabled = motionLogEnabled
    }
}
