import Foundation
import SwiftData

// MARK: - 草稿三件套（R8 确认：永不丢 + 不打断 + 看得见）
/// 定位键 = moduleKey + pageKey（精确到字段可后续扩展）
@Model
final class Draft {
    @Attribute(.unique) var id: UUID
    var moduleKey: String
    var pageKey: String
    var fieldKey: String            // 字段级定位，便于细粒度恢复
    var payload: String             // 文本内容（多类型后续拆字段）
    var updatedAt: Date
    var isPersistent: Bool          // 永久保留（草稿不主动清，用户删除/发布才清）

    init(id: UUID = UUID(), moduleKey: String, pageKey: String,
         fieldKey: String = "default", payload: String = "",
         updatedAt: Date = .now, isPersistent: Bool = true) {
        self.id = id
        self.moduleKey = moduleKey
        self.pageKey = pageKey
        self.fieldKey = fieldKey
        self.payload = payload
        self.updatedAt = updatedAt
        self.isPersistent = isPersistent
    }
}
