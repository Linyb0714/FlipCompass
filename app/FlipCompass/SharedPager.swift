import SwiftUI

// MARK: - 共享基建 · 模块页手势系统（B1 建立，B2~B4 复用 · B1b 按真机反馈重构）
// 切分组 = 覆盖式转场（拖动只见当前页阻尼跟手，松手新页自滑动方向弹入——不露邻页内容）；
// 上下滑 = 逐行步进（每滑过一行高，焦点立即跳一行，原型 selStep 语义）；
// 行 swipe（p2 删除）：水平拖动命中行 → 行内 swipe 露删除钮，优先于切组；
// 主轴锁定一次一个。B5 范围的连击保护暂不含。

enum PagerLogic {
    enum Axis { case horizontal, vertical }

    /// 主轴锁定：任一方向位移 ≥ 8pt 后锁定（原型主轴判定）
    static func lockAxis(dx: CGFloat, dy: CGFloat) -> Axis? {
        guard abs(dx) > 8 || abs(dy) > 8 else { return nil }
        return abs(dx) > abs(dy) ? .horizontal : .vertical
    }

    /// 松手落页决策（原始位移 >30% 页宽或快扫切页；越界方向 bump 回弹）
    /// 快扫判据 = predictedEndLocation 与落点的差值（预测外推 60pt）
    static func settlePage(dragX: CGFloat, width: CGFloat,
                           fastNext: Bool, fastPrev: Bool,
                           page: Int, pageCount: Int) -> (page: Int, bumped: Bool) {
        let threshold = width * 0.30
        let wantNext = dragX < -threshold || (fastNext && dragX < 0)
        let wantPrev = dragX > threshold || (fastPrev && dragX > 0)
        if wantNext {
            let next = page + 1
            return next < pageCount ? (next, false) : (page, true)
        }
        if wantPrev {
            let prev = page - 1
            return prev >= 0 ? (prev, false) : (page, true)
        }
        return (page, false)
    }

    /// 垂直拖动逐行步进（焦点跟手势方向：下滑 → sel+1 下移，上滑 → sel-1；
    /// 原型验证记录「下滑 sel 0→1 · 上滑回 0」；startSel = 手势起点选中）
    static func stepSel(dragY: CGFloat, rowHeight: CGFloat,
                        startSel: Int, count: Int) -> Int {
        guard count > 0, startSel >= 0 else { return startSel }
        let h = max(rowHeight, 1)
        let steps = Int(dragY / h)           // 下滑正位移 → 正向步进
        return min(max(startSel + steps, 0), count - 1)
    }

    /// 垂直松手快扫补步进（拖动量小但快 → 至少步进一档；返回 nil = 不动）
    /// fastDown = 下滑快扫（正向），fastUp = 上滑快扫（反向）
    static func flickStep(dragY: CGFloat, fastDown: Bool, fastUp: Bool,
                          sel: Int, startSel: Int, count: Int) -> Int? {
        guard count > 0, sel >= 0, sel == startSel else { return nil }
        if fastDown && dragY > 0 { return min(sel + 1, count - 1) }
        if fastUp && dragY < 0 { return max(sel - 1, 0) }
        return nil
    }

    /// 行 swipe 松手：露出一半以上 → 保持展开（-reveal），否则收起（0）
    static func settleSwipe(swipeX: CGFloat, reveal: CGFloat = 56) -> CGFloat {
        swipeX < -reveal * 0.5 ? -reveal : 0
    }
}

// MARK: - 拖动会话（B5a：@GestureState 承载——被 ScrollView/行手势打断时系统自动复位归零）
// 根治「画布卡在半途」：旧 @State + onEnded 手动复位，手势被垂直滚动/行手势抢占时
// onEnded 不回调 → 残留半途 offset 画布钉死；@GestureState 无论正常结束还是被打断都归零。
// 「步长固定」：idle 态画布位置恒为 -page*(W+gap) 的整数槽位，松手只落在槽位（回弹或前进）；
// 复位动画统一：canvas 挂 .animation(session.locked ? nil : pageSwitch, value: session)——
// 锁定中 1:1 跟手（无动画），松手/被打断的重置以 pageSwitch 平滑归位。

import SwiftUI

struct PagerSession: Equatable {
    enum Mode: Equatable {
        case idle       // 未锁定（无手势 / 垂直意图交 ScrollView 滚动）
        case page       // 水平切组锁定
        case vertical   // 垂直步进锁定（仅 M1）
    }
    var mode: Mode = .idle
    var offset: CGSize = .zero
    var locked: Bool { mode != .idle }
}
