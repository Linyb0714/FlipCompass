import Foundation
import Observation

// MARK: - 设备物理朝向（覆盖四向翻转 + 平放）

enum DeviceOrientation: String, CaseIterable, Codable {
    case portrait           // 竖正：M1
    case portraitUpsideDown // 竖倒：M2
    case landscapeLeft      // 左横：M3
    case landscapeRight     // 右横：M4
    case faceUp             // 平放：待机
    case faceDown
}

// MARK: - 导航状态机（R7）
// L0 待机（罗盘零位）→ L1 一级目录（四向翻转 / 色卡 / swipe 进入，模块间可直切）
// → L2 二级页面栈（C 阶段逐步完善）
// 平放（faceUp/faceDown 确认）收拢回待机；L1 内四向翻转 = 模块直切。

extension Notification.Name {
    /// B1i：模块字飞行（进入/返回时携带模块字+色块，userInfo：module/enter）
    static let moduleFlight = Notification.Name("moduleFlight")
}

@Observable
final class AppState {

    enum Level: Equatable {
        case idle      // L0
        case module    // L1（module 非 nil；L2 详情栈 C 阶段加入）
    }

    /// 层级切换的稳定标识（转场动画的 value）
    enum ScreenID: Equatable {
        case idle
        case module(ModuleKey)
    }

    private(set) var level: Level = .idle
    private(set) var module: ModuleKey?

    /// 二级页（hero 详情/编辑）打开层数（红线修复：>0 时屏蔽翻转导航）
    private(set) var detailDepth = 0

    // —— 返回待机的流光重置（V0.3.3 sheenRestart）：记录刚离开的模块；
    //    stamp 每次返回刷新，驱动色卡重算错峰相位（返回卡 0s、其余顺时针 1.6/3.2/4.8s）——
    private(set) var lastExitedModule: ModuleKey?
    private(set) var idleRestartStamp: UUID?

    var screenID: ScreenID {
        if level == .module, let module { return .module(module) }
        return .idle
    }

    // MARK: 导航

    func enterModule(_ key: ModuleKey) {
        if module == key && level == .module { return }   // 已在该模块，忽略
        module = key
        level = .module
        // B1i：字飞行——色卡 → 模块头图标（通知机制，不依赖视图依赖追踪）
        NotificationCenter.default.post(
            name: .moduleFlight, object: nil,
            userInfo: ["module": key.rawValue, "enter": true]
        )
    }

    /// 二级页打开/关闭上报（各模块屏 openHero / HeroOverlay.onClosed 调用）
    func enterDetail() { detailDepth += 1 }

    func exitDetail() { detailDepth = max(0, detailDepth - 1) }

    func backToIdle() {
        lastExitedModule = module          // 待机色卡流光重置用
        idleRestartStamp = UUID()
        let exiting = module
        level = .idle
        module = nil
        // B1i：字飞行——模块头图标 → 色卡
        if let exiting {
            NotificationCenter.default.post(
                name: .moduleFlight, object: nil,
                userInfo: ["module": exiting.rawValue, "enter": false]
            )
        }
    }

    // MARK: R8 翻转事件 → 导航（V2.1 · 用户定稿：本期只监听「上」）
    //
    // 红线修复（2026-10-16 真机反馈：无操作却自动退回待机/上一级、编辑一半被打断）：
    // ① 二级页（hero 详情/编辑）打开期间忽略一切翻转事件——编辑中绝不被导航打断；
    // ② 翻转导航仅在待机页响应——模块内此前会因「放下手机」（俯仰旋转 + 停稳平放）
    //    被误判为「平放收拢」而自动回待机，拿起手机放桌上即触发，严重干扰使用；
    //    模块内回待机改由明确交互承担（双击空白 / 边缘返回 / 色卡）。
    func handleFlipEvent(direction: FlipDirection?, orientation: DeviceOrientation) {
        guard detailDepth == 0 else { return }   // 二级页中：全部忽略
        guard level == .idle else { return }     // 仅在待机页响应翻转进入
        if direction == .up {
            enterModule(.m1)
        }
    }
}
