import SwiftUI
import SwiftData
import AppIntents

// MARK: - 共享 ModelContainer（App 本体 + AppIntents 共用同一容器，写库互通）
// AppIntents 默认在 App 进程内执行，但 Intent 代码拿不到 SwiftUI 的
// environment(\.modelContext)，必须经静态共享容器建独立 ModelContext。

enum AppModelContainer {
    /// 启动诊断日志（Documents/launch.log；真机排查可用
    /// `devicectl device copy from --domain-type appDataContainer` 拉取）
    static func launchLog(_ line: String) {
        let text = "\(Date()) \(line)\n"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("launch.log")
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            h.seekToEndOfFile()
            h.write(Data(text.utf8))
        } else {
            try? Data(text.utf8).write(to: url)
        }
    }

    static let shared: ModelContainer = {
        launchLog("container: 开始创建")
        func make() throws -> ModelContainer {
            try ModelContainer(
                for: CheckInItem.self, CheckInRecord.self,
                Thought.self, Draft.self,
                FeedItem.self, CouponCard.self, Preference.self, RssSource.self,
                GameProgress.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        }
        do {
            let c = try make()
            launchLog("container: 创建成功")
            return c
        } catch {
            // 真机闪退根因（2026-10-15）：昨日版本 8 实体 store 遇 9 实体新 schema
            //（C5+ 增 RssSource）自动迁移失败 → fatalError 启动即崩。
            // 开发期自愈：旧库改名备份保留 → 重建空库；seed flags 一并重置让演示数据
            // 重新生成（上架前应补 VersionedSchema 正规迁移替代此兜底）。
            launchLog("container: 打开失败 \(error.localizedDescription) → 备份旧库重建")
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let store = support.appendingPathComponent("default.store")
            let df = DateFormatter()
            df.dateFormat = "yyyyMMdd-HHmmss"
            let bak = support.appendingPathComponent("default.store.bak-\(df.string(from: Date()))")
            try? FileManager.default.removeItem(at: bak)
            try? FileManager.default.moveItem(at: store, to: bak)
            try? FileManager.default.removeItem(at: store.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: store.appendingPathExtension("shm"))
            launchLog("container: 旧库已备份 \(bak.lastPathComponent)")
            // 重建空库后 seed 需全部重新执行：清 seed 幂等 flag
            for key in UserDefaults.standard.dictionaryRepresentation().keys where key.contains("seeded") {
                UserDefaults.standard.removeObject(forKey: key)
            }
            launchLog("container: 已重置 seed flags")
            do {
                let c = try make()
                launchLog("container: 重建成功")
                return c
            } catch {
                launchLog("container: 重建仍失败 \(error.localizedDescription)")
                fatalError("ModelContainer 创建失败: \(error)")
            }
        }
    }()
}

// MARK: - 快捷指令：存券到我看看（C5+ 方案②）
//
// 用法（真机）：美团/抖音券面页 → 分享/复制文字 → 快捷指令「存券到我看看」
// （或 Siri 说「用我看看存券」）→ 启发式解析入库 → p0 今日推送出现新券。
// 解析规则与截图 OCR 共用 CouponScan。

struct SaveCouponIntent: AppIntent {
    static var title: LocalizedStringResource = "存券到我看看"
    static var description = IntentDescription("把分享来的券文字解析成一张券卡，收进生活情报站")
    static var openAppWhenRun = false

    @Parameter(title: "券信息", requestValueDialog: "把券的文字内容发给我看看")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ctx = ModelContext(AppModelContainer.shared)
        let draft = CouponScan.parse(text)
        let title = draft.title.isEmpty ? "手动存券" : draft.title
        let code = ""
        let shops = draft.shops.isEmpty
            ? ["到店核销 · 详见平台券面"]
            : draft.shops
        ctx.insert(CouponCard(
            title: title,
            sub: "快捷指令导入 · 到店出示",
            value: draft.value.isEmpty ? title : draft.value,
            threshold: draft.threshold.isEmpty ? "到店核销 · 不与其他优惠同享" : draft.threshold,
            daysLeft: draft.daysLeft,
            valid: draft.valid.isEmpty ? "导入后 7 天内有效" : draft.valid,
            scope: "到店核销 · 以平台券面为准",
            progress: 100, state: "none", code: code,
            shops: shops
        ))
        try ctx.save()
        return .result(dialog: "已存入「\(title)」，去生活情报站领取")
    }
}

// MARK: - 快捷指令入口注册（App Shortcuts：无需手动建指令，Siri/快捷指令 App 直接可用）

struct FlipCompassShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveCouponIntent(),
            phrases: ["用\(.applicationName)存券", "\(.applicationName)存个券"],
            shortTitle: "存券",
            systemImageName: "ticket"
        )
    }
}
