import Foundation
import SwiftData

/// SwiftData 实体清单（T3 14 实体 + V0.4.4 M4 三件套扩展）
enum ModelContainerFactory {
    static var allModels: [any PersistentModel.Type] {
        [
            CheckInItem.self,
            CheckInRecord.self,
            Thought.self,
            Draft.self,
            Preference.self,
            CollectionItem.self,
            CouponCard.self,
            FeedSource.self,
            FeedItem.self,
            GameProgress.self,
            GameRecord.self,
            GameBadge.self,
            GameSettings.self,
            MotionLogEntry.self,
            ModuleKV.self,
            InstalledModule.self,
            AppSettings.self,
        ]
    }

    static func make() throws -> ModelContainer {
        let schema = Schema(allModels)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    static func makeInMemory() throws -> ModelContainer {
        let schema = Schema(allModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
