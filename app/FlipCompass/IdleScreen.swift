import SwiftUI
import SwiftData

// MARK: - L0 待机屏（三段式定位布局 · v0.8 几何 + V0.2.5 天气行/胶囊列）
// 设计稿 390×844（含安全区 59/34）三段几何按屏高比例投放（适配更长机型）：
//   上段：日期 + 天气 + 时钟（组中心 ≈ 168 / 844 ≈ 0.199H）
//   中段：罗盘（环中心 397 / 844 ≈ 0.470H，环外沿 277~517）
//   下段：提醒胶囊（列）+ 提示词轮播（下空白带 517~810）

struct IdleScreen: View {
    let onEnterModule: (ModuleKey) -> Void
    var tickerPaused: Bool = false
    /// 非待机暂停色卡流光
    var sheenPaused: Bool = false
    /// 返回待机的流光重置（传递给罗盘色卡：返回卡 0s、其余顺时针错峰）
    var sheenRestartModule: ModuleKey? = nil
    var sheenRestartStamp: UUID? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false
    // 天气真机数据（定位 + 反地理 + Open-Meteo；失败隐藏行、成功显示真实城市/天气/温度）
    @StateObject private var weather = WeatherService()

    // D2：待机胶囊实况（四模块统计实算 · 点击直达模块）
    @Query private var checkItems: [CheckInItem]
    @Query private var drafts: [Draft]
    @Query private var feeds: [FeedItem]
    @Query private var coupons: [CouponCard]
    @Query private var games: [GameProgress]

    private var idlePills: [IdleDigest.Pill] {
        IdleDigest.pills(
            itemDays: checkItems.map { Set($0.records.map(\.day)) },
            drafts: drafts.count,
            feedToday: feeds.filter(\.inFeed).count + coupons.filter(\.inFeed).count,
            gamePlaysToday: M4Store.todayCount(games, today: Date()),
            today: Date()
        )
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // 液态环境光斑（四向模块色，缓慢漂移）
                // 性能：非待机（模块屏 opaque 覆盖）整层移除——4 个 blur(46) 光斑的
                // hueRotation 滤镜循环动画是常驻 GPU 重绘，被遮挡期间纯浪费；
                // 返回待机重新插入（光斑从静息位重新漂，视觉无感知）
                if !sheenPaused {
                    AmbientBlobs(size: geo.size, reduceMotion: reduceMotion)
                }

                // ---- 上段：时间组（B1s 换序：时间置顶）----
                // 用户验收：与罗盘色卡太近 → 0.205H 上移至 0.185H（约 +17~19pt 呼吸）
                TimeGroup(weather: weather.info, weatherFailed: weather.failed)
                    .position(x: w / 2, y: h * 0.185)
                    .opacity(appear ? 1 : 0)

                // ---- 中段：罗盘 ----
                IdleCompass(
                    onEnterModule: onEnterModule,
                    paused: sheenPaused,
                    sheenRestartModule: sheenRestartModule,
                    sheenRestartStamp: sheenRestartStamp
                )
                .position(x: w / 2, y: h * 0.47)
                .opacity(appear ? 1 : 0)
                .scaleEffect(appear ? 1 : 0.94)

                // ---- 下段：提醒胶囊（D2 实况 + 点击直达模块）+ 提示词 ----
                VStack(spacing: 0) {
                    ReminderPills(pills: idlePills, onEnterModule: onEnterModule)
                    HintTicker(paused: tickerPaused)
                }
                .position(x: w / 2, y: h * 0.838)
                .opacity(appear ? 1 : 0)
            }
        }
        .background(Color.white)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(reduceMotion ? nil : DSToken.springSlow.delay(0.16)) {
                appear = true
            }
            weather.refresh()
        }
        // 前台每 15 分钟刷新天气（原型 V0.2.5 注释设计；服务内部再节流）
        .onReceive(Timer.publish(every: 15 * 60, on: .main, in: .common).autoconnect()) { _ in
            weather.refresh()
        }
    }
}

// MARK: - 时间组（B1s 换序：上时间 / 中日期星期 / 下城市天气——静态呈现不闪动 V0.2.3 ①）
// 天气：成功 = 真实城市 · 符号 天气 温度；加载中 = 点点占位；失败 = 隐藏行

private struct TimeGroup: View {
    let weather: WeatherService.Info?
    let weatherFailed: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            VStack(spacing: 0) {
                Text(Self.clockString(from: now))
                    .font(DSToken.num(92))
                    .foregroundStyle(DSToken.ink)
                    .tracking(-2.5)
                Text(Self.dateString(from: now))
                    .font(DSToken.body(15, weight: .medium))
                    .foregroundStyle(DSToken.ink2)
                    .tracking(4)
                    .padding(.top, 3)
                if !weatherFailed {
                    weatherRow
                }
            }
        }
    }

    @ViewBuilder
    private var weatherRow: some View {
        Group {
            if let w = weather {
                HStack(spacing: 6) {
                    Text(w.city)
                    Text("·").foregroundStyle(DSToken.ink3)
                    Text(w.icon).font(DSToken.body(14))
                    Text(w.condition)
                    Text(w.temperature).font(DSToken.num(14, weight: .medium))
                }
            } else {
                // 加载中（定位/反地理/天气请求任一步未回）；不显示假数据
                HStack(spacing: 6) {
                    Text("…")
                    Text("·").foregroundStyle(DSToken.ink3)
                    Text("…")
                }
            }
        }
        .font(DSToken.body(13, weight: .medium))
        .foregroundStyle(DSToken.ink2)
        .tracking(1.5)
        .padding(.top, 5)
    }

    /// 「10月12日 星期一」
    static func dateString(from date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.month, .day, .weekday], from: date)
        let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
        return "\(comps.month!)月\(comps.day!)日 星期\(weekdays[comps.weekday! - 1])"
    }

    /// 「21:47」
    static func clockString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - 待机胶囊实况（D2：四模块统计实算 · 纯函数可单测）

enum IdleDigest {
    struct Pill: Equatable {
        let module: ModuleKey
        let text: String
    }

    static func pills(
        itemDays: [Set<Date>],
        drafts: Int,
        feedToday: Int,
        gamePlaysToday: Int,
        today: Date,
        cal: Calendar = .current
    ) -> [Pill] {
        // M1：今日未完成打卡（复用 M1 头部胶囊同一统计口径）
        let c = CheckInStats.todayCount(itemDays: itemDays, today: today, cal: cal)
        let pending = c.total - c.done
        let m1 = pending > 0
            ? "今日还有 \(pending) 个温情打卡没完成"
            : (c.total == 0 ? "打卡清单空着 · 加一件事开始" : "温情打卡全部完成 ✓")
        // M2：未完草稿
        let m2 = drafts > 0 ? "有 \(drafts) 条想法写了一半 · 草稿在等你" : "想法都已记好 · 草稿箱空闲 ✓"
        // M3：今日情报（券 + 情报双列合计，同 M3 头部口径）
        let m3 = feedToday > 0 ? "生活情报站 · 今日 \(feedToday) 条新情报" : "生活情报站 · 今天还没有新推送"
        // M4：每日一局
        let m4 = gamePlaysToday > 0 ? "每日一局已完成 ✓ 休息一下眼睛" : "每日一局没玩 · 益智小游戏在等你"
        return [
            Pill(module: .m1, text: m1),
            Pill(module: .m2, text: m2),
            Pill(module: .m3, text: m3),
            Pill(module: .m4, text: m4),
        ]
    }
}

// MARK: - 提醒胶囊（轻玻璃药丸 · 模块色点 · D2 实况文案 + 点击直达模块）

private struct ReminderPills: View {
    let pills: [IdleDigest.Pill]
    let onEnterModule: (ModuleKey) -> Void

    var body: some View {
        VStack(spacing: 14) {
            ForEach(pills, id: \.module) { p in
                pill(color: p.module.color, text: p.text) {
                    onEnterModule(p.module)
                }
            }
        }
    }

    private func pill(color: Color, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(text)
                    .font(DSToken.body(13))
                    .foregroundStyle(Color(red: 0x55/255, green: 0x55/255, blue: 0x5c/255))
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    Capsule().fill(.ultraThinMaterial)
                    LinearGradient(
                        gradient: Gradient(colors: [.white.opacity(0.72), .white.opacity(0.42)]),
                        startPoint: .init(x: 0.5, y: 0), endPoint: .init(x: 0.33, y: 1)
                    )
                }
                .clipShape(Capsule())
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
            .shadow(color: Color(red: 0.122, green: 0.102, blue: 0.078).opacity(0.07), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 底部提示词（3.6s 翻牌轮播 · V0.2.2 ①；非待机暂停）

private struct HintTicker: View {
    var paused: Bool

    private static let hints = [
        "点色卡 · 或翻转我",
        "上下滑 · 选择条目",
        "左右滑 · 切换分组",
        "双击空白 · 返回上一级",
        "向四方翻转 · 探索模块",
    ]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var flipping = false

    var body: some View {
        Text(Self.hints[index])
            .font(DSToken.body(12))
            .foregroundStyle(DSToken.ink3)
            .tracking(1.2)
            .frame(height: 24)
            .padding(.top, 13)
            .rotation3DEffect(
                .degrees(flipping ? -92 : 0),
                axis: (x: 1, y: 0, z: 0), perspective: 0.62
            )
            .opacity(flipping ? 0 : 1)
            .onReceive(Timer.publish(every: 3.6, on: .main, in: .common).autoconnect()) { _ in
                guard !paused else { return }
                guard !reduceMotion else {
                    index = (index + 1) % Self.hints.count
                    return
                }
                // 翻出 → 换词 → 翻入
                withAnimation(.easeIn(duration: 0.44)) { flipping = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
                    index = (index + 1) % Self.hints.count
                    withAnimation(.easeOut(duration: 0.44)) { flipping = false }
                }
            }
    }
}

// MARK: - 液态环境光斑（四色 blob · 缓慢漂移 + 色相微变 · 46~58s alternate）

private struct AmbientBlobs: View {
    let size: CGSize
    let reduceMotion: Bool
    @State private var phase = false

    var body: some View {
        ZStack {
            blob(color: DSToken.m1, diameter: 250,
                 rest: CGPoint(x: size.width * 0.07, y: size.height * 0.048),   // left 7% top 5%
                 drift: CGSize(width: 24, height: 17))                            // driftA
            blob(color: DSToken.m2, diameter: 230,
                 rest: CGPoint(x: size.width * 0.94, y: size.height * 0.095),    // right 6% top 8%
                 drift: CGSize(width: -21, height: 22))                           // driftB
            blob(color: DSToken.m3, diameter: 240,
                 rest: CGPoint(x: size.width * 0.04, y: size.height * 0.893),    // left 4% bottom 7%
                 drift: CGSize(width: 23, height: -19))                           // driftC
            blob(color: DSToken.m4, diameter: 250,
                 rest: CGPoint(x: size.width * 0.93, y: size.height * 0.933),    // right 7% bottom 4%
                 drift: CGSize(width: -24, height: -15))                          // driftD
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 25).repeatForever(autoreverses: true)) {
                phase = true
            }
        }
    }

    private func blob(color: Color, diameter: CGFloat, rest: CGPoint, drift: CGSize) -> some View {
        Circle()
            .fill(color.opacity(0.15))
            .frame(width: diameter, height: diameter)
            .blur(radius: 46)
            .hueRotation(.degrees(phase ? 38 : 0))   // 缓慢色相漂移（hue-rotate 简化）
            .position(
                x: phase ? rest.x + drift.width : rest.x - drift.width / 2,
                y: phase ? rest.y + drift.height : rest.y - drift.height / 2
            )
    }
}
