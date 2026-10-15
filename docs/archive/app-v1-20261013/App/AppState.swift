import SwiftUI
import Combine

/// 应用根状态机（@Observable 架构）
/// 维护三层导航状态机 L0 待机 / L1 一级目录 / L2 多级页面栈，
/// 与 MotionKit 协同响应四向翻转事件。
@Observable
final class AppState {
    // MARK: - 导航层级
    var level: NavigationLevel = .idle
    var currentModule: ModuleKey? = nil
    var modulePage: [ModuleKey: Int] = [:]
    var moduleSelection: [ModuleKey: Int] = [:]
    var detailStack: [DetailRoute] = []

    // MARK: - 翻转判定
    var lastOrientation: DeviceOrientation = .faceUp
    var pendingOrientation: DeviceOrientation? = nil
    var prefeedbackOrientation: DeviceOrientation? = nil

    // MARK: - 真机调试
    var motionLogEnabled: Bool = true
    var lastMotionEvent: String? = nil

    // MARK: - 首用引导
    var hasSeenFirstRunGuide: Bool = false

    // MARK: - 运动引擎
    private weak var motionKitRef: MotionKit?
    private var cancellables = Set<AnyCancellable>()

    @MainActor
    func bind(motionKit: MotionKit) {
        self.motionKitRef = motionKit
        motionKit.$flipState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleFlipState(state)
            }
            .store(in: &cancellables)
        motionKit.$confirmedOrientation
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] orientation in
                self?.handleConfirmedOrientation(orientation)
            }
            .store(in: &cancellables)
    }

    // MARK: - 翻转事件处理
    private func handleFlipState(_ state: FlipState) {
        switch state {
        case .flipping(let target):
            prefeedbackOrientation = target
        case .settling(let target):
            prefeedbackOrientation = target
        case .idle:
            prefeedbackOrientation = nil
        case .confirmed:
            break
        }
    }

    private func handleConfirmedOrientation(_ orientation: DeviceOrientation) {
        lastOrientation = orientation
        switch orientation {
        case .faceUp, .faceDown:
            // 平放：任何状态收拢回待机
            backToIdle()
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            // 翻转进模块
            if let module = ModuleKey(orientation: orientation) {
                enterModule(module)
            }
        }
    }

    // MARK: - 导航动作
    func enterModule(_ module: ModuleKey) {
        if currentModule != module {
            currentModule = module
            level = .module
            detailStack.removeAll()
            modulePage[module] = modulePage[module] ?? 0
            moduleSelection[module] = moduleSelection[module] ?? 0
        }
    }

    func backToIdle() {
        level = .idle
        detailStack.removeAll()
        currentModule = nil
        prefeedbackOrientation = nil
    }

    func backOneLevel() {
        if !detailStack.isEmpty {
            detailStack.removeLast()
            if detailStack.isEmpty {
                level = .module
            }
        } else if level == .module {
            backToIdle()
        }
    }

    func enterDetail(_ route: DetailRoute) {
        detailStack.append(route)
        level = .detail
    }

    func selectItem(_ index: Int) {
        guard let module = currentModule else { return }
        moduleSelection[module] = index
    }

    func switchPage(_ delta: Int, pageCount: Int) {
        guard let module = currentModule else { return }
        let current = modulePage[module] ?? 0
        let next = min(max(0, current + delta), pageCount - 1)
        modulePage[module] = next
    }
}
