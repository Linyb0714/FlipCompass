import XCTest
@testable import FlipCompass

/// 色卡流光时序单测（V3 持续巡游：14s 周期 / 错峰 = 周期/4 = 3.5s / 单卡光斑 2.2s；
/// 四卡均匀衔接循环，无整轮安静期；返回重置语义不变）
final class SheenTimingTests: XCTestCase {

    func testInitialDelayRingOrder() {
        // 初始（restart=nil）：顺时针环序错峰 —— M1 0s / M4 3.5 / M2 7 / M3 10.5
        XCTAssertEqual(SheenTiming.delay(for: .m1, restart: nil), 0)
        XCTAssertEqual(SheenTiming.delay(for: .m4, restart: nil), 3.5, accuracy: 0.0001)
        XCTAssertEqual(SheenTiming.delay(for: .m2, restart: nil), 7.0, accuracy: 0.0001)
        XCTAssertEqual(SheenTiming.delay(for: .m3, restart: nil), 10.5, accuracy: 0.001)
    }

    func testRestartFromM1() {
        XCTAssertEqual(SheenTiming.delay(for: .m1, restart: .m1), 0)
        XCTAssertEqual(SheenTiming.delay(for: .m4, restart: .m1), 3.5, accuracy: 0.0001)
        XCTAssertEqual(SheenTiming.delay(for: .m2, restart: .m1), 7.0, accuracy: 0.0001)
        XCTAssertEqual(SheenTiming.delay(for: .m3, restart: .m1), 10.5, accuracy: 0.001)
    }

    func testRestartFromM3Clockwise() {
        // 从 M3（左）返回：M3 0s；顺时针（左→上→右→下）
        XCTAssertEqual(SheenTiming.delay(for: .m3, restart: .m3), 0)
        XCTAssertEqual(SheenTiming.delay(for: .m1, restart: .m3), 3.5, accuracy: 0.0001)
        XCTAssertEqual(SheenTiming.delay(for: .m4, restart: .m3), 7.0, accuracy: 0.0001)
        XCTAssertEqual(SheenTiming.delay(for: .m2, restart: .m3), 10.5, accuracy: 0.001)
    }

    func testRestartFromM4() {
        XCTAssertEqual(SheenTiming.delay(for: .m4, restart: .m4), 0)
        XCTAssertEqual(SheenTiming.delay(for: .m2, restart: .m4), 3.5, accuracy: 0.0001)
        XCTAssertEqual(SheenTiming.delay(for: .m3, restart: .m4), 7.0, accuracy: 0.0001)
        XCTAssertEqual(SheenTiming.delay(for: .m1, restart: .m4), 10.5, accuracy: 0.001)
    }

    func testProgressModulo() {
        XCTAssertEqual(SheenTiming.progress(elapsed: -1.0), 0)
        XCTAssertEqual(SheenTiming.progress(elapsed: 0), 0)
        XCTAssertEqual(SheenTiming.progress(elapsed: 7.0), 0.5, accuracy: 0.0001)
        XCTAssertEqual(SheenTiming.progress(elapsed: 15.4), 1.4 / 14, accuracy: 0.0001)
    }

    func testSweepCurve() {
        XCTAssertEqual(SheenTiming.sweep(progress: 0), 0)
        // 扫光中点：sweepRatio/2 → ease 中点 0.5
        XCTAssertEqual(SheenTiming.sweep(progress: SheenTiming.sweepRatio / 2), 0.5, accuracy: 0.001)
        XCTAssertEqual(SheenTiming.sweep(progress: SheenTiming.sweepRatio), 1.0)
        XCTAssertEqual(SheenTiming.sweep(progress: 0.5), 1.0)   // 闪光后余下周期归位屏外（渲染层已关）
        XCTAssertLessThan(SheenTiming.sweep(progress: 0.02), SheenTiming.sweep(progress: 0.1))  // 单调
    }

    /// V3 性质①：持续巡游——错峰 × 4 = 周期（数学上四卡相位均分，循环衔接无断档）
    func testStaggerEqualsQuarterPeriod() {
        XCTAssertEqual(SheenTiming.staggerRelay * 4, SheenTiming.period, accuracy: 0.0001,
                       "错峰×4 必须等于周期（均匀衔接，无整轮安静期）")
    }

    /// V3 性质②：逐个闪过——单卡光斑时长 < 错峰 → 任一时刻至多 1 张卡在闪
    func testAtMostOneActiveAtAnyTime() {
        XCTAssertLessThan(SheenTiming.sweepDuration, SheenTiming.staggerRelay,
                          "光斑时长应短于错峰（逐个闪过不重叠）")
        let active: (Double) -> Bool = { elapsed in
            guard elapsed > 0 else { return false }
            let p = SheenTiming.progress(elapsed: elapsed)
            return p > 0 && p < SheenTiming.sweepRatio
        }
        for t in stride(from: 0.0, through: SheenTiming.period * 2, by: 0.1) {
            let n = (0..<4).filter { active(t - Double($0) * SheenTiming.staggerRelay) }.count
            XCTAssertLessThanOrEqual(n, 1, "t=\(t) 同时 \(n) 张卡在闪（应逐个）")
        }
    }

    /// V3 性质③：无长静默——相邻闪光之间的空窗 = 错峰 − 光斑时长（~1.3s），< 2 秒
    /// （用户反馈「不要等待几秒安静」：任何时刻距下一次起闪 ≤ stagger 3.5s，
    ///  实际空窗更短）
    func testSilenceGapShortBetweenFlashes() {
        let nominal = SheenTiming.staggerRelay - SheenTiming.sweepDuration
        XCTAssertLessThan(nominal, 2.0, "相邻闪光空窗应短于 2 秒")
        let active: (Double) -> Bool = { elapsed in
            guard elapsed > 0 else { return false }
            let p = SheenTiming.progress(elapsed: elapsed)
            return p > 0 && p < SheenTiming.sweepRatio
        }
        // 实测最长静默段（0.1s 采样）
        var lastActiveAt: Double? = nil
        var maxSilence = 0.0
        for t in stride(from: 0.0, through: SheenTiming.period * 2, by: 0.1) {
            let anyActive = (0..<4).contains { active(t - Double($0) * SheenTiming.staggerRelay) }
            if anyActive {
                lastActiveAt = t
            } else if let last = lastActiveAt {
                maxSilence = max(maxSilence, t - last)
            }
        }
        XCTAssertLessThanOrEqual(maxSilence, nominal + 0.25,
                                 "实测最长静默 \(maxSilence)s 超出理论 \(nominal)s")
    }

    func testBandXTravelsLeftToRight() {
        let w: Double = 66
        let startX = SheenTiming.bandCenterX(sweep: 0, cardWidth: w)
        let midX = SheenTiming.bandCenterX(sweep: 0.5, cardWidth: w)
        let endX = SheenTiming.bandCenterX(sweep: 1, cardWidth: w)
        XCTAssertLessThan(startX, 0, "起点屏外左侧")
        XCTAssertGreaterThan(endX, w, "终点屏外右侧")
        XCTAssertGreaterThan(midX, startX)
        XCTAssertLessThan(midX, endX)
    }
}
