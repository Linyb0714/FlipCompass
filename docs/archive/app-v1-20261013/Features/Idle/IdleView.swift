import SwiftUI
import SwiftData

/// 待机屏（L0）
/// V0.2.5 / V0.3.5 / V0.4.1：三段式定位 + 罗盘环 + 提醒胶囊 + 提示词轮播
struct IdleView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext
    @State private var reminders: [IdleReminders.Reminder] = []
    @State private var now = Date()
    @State private var hintIndex = 0
    private let hintTimer = Timer.publish(every: 3.6, on: .main, in: .common).autoconnect()
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let hints = [
        "点色卡进入对应模块",
        "上下滑选条目",
        "左右滑换分组",
        "双击空白返回",
        "四向翻转探索",
    ]

    var body: some View {
        ZStack {
            DesignTokens.bgPrimary.ignoresSafeArea()
            ambientBlobs
            VStack(spacing: 0) {
                topZone
                Spacer()
                compassZone
                Spacer()
                bottomZone
            }
            .padding(.horizontal, 28)
        }
        .task { await refreshReminders() }
        .onReceive(clockTimer) { now = $0 }
        .onReceive(hintTimer) { _ in
            withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                hintIndex = (hintIndex + 1) % hints.count
            }
        }
    }

    // MARK: - 上段：日期+天气+时钟
    private var topZone: some View {
        VStack(spacing: 4) {
            Text(now.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh-Hans"))))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DesignTokens.inkSecondary)
                .tracking(4)
            Text("福州 · ☀︎晴 26°")
                .font(.system(size: 13))
                .foregroundStyle(DesignTokens.inkSecondary)
                .padding(.top, 2)
            Text(clockString(from: now))
                .font(.system(size: 64, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.ink)
                .padding(.top, 6)
        }
    }

    // MARK: - 中段：罗盘四向指示
    private var compassZone: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [DesignTokens.m1Orange, DesignTokens.m2Purple,
                                 DesignTokens.m3Green, DesignTokens.m4Yellow,
                                 DesignTokens.m1Orange],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: 250, height: 250)
            Circle()
                .stroke(DesignTokens.inkSecondary.opacity(0.15), lineWidth: 1)
                .frame(width: 250, height: 250)
            ForEach(ModuleKey.allCases) { mod in
                compassDot(for: mod)
            }
            Text("罗盘")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DesignTokens.inkSecondary)
            if let pending = state.prefeedbackOrientation,
               let target = ModuleKey(orientation: pending) {
                Text(target.glyph)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(target.themeColor)
                    .offset(y: -135)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func compassDot(for mod: ModuleKey) -> some View {
        let angle: Double
        switch mod {
        case .checkIn: angle = -90
        case .thought: angle = 90
        case .hub: angle = 180
        case .game: angle = 0
        }
        return VStack(spacing: 4) {
            Circle()
                .fill(mod.themeColor)
                .frame(width: 14, height: 14)
                .shadow(color: mod.themeColor.opacity(0.6), radius: 6)
            Text(mod.displayName.prefix(2))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignTokens.inkSecondary)
        }
        .offset(y: -135)
        .rotationEffect(.degrees(angle))
    }

    // MARK: - 下段：提醒胶囊
    private var bottomZone: some View {
        VStack(spacing: 14) {
            if reminders.isEmpty {
                Text("今天都很轻松，安心休息一下吧 ☺︎")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.inkSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(reminders) { r in
                        HStack(spacing: 8) {
                            Circle().fill(r.module.themeColor).frame(width: 8, height: 8)
                            Text(r.text)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DesignTokens.ink)
                            if let sub = r.subtitle {
                                Text(sub)
                                    .font(.system(size: 12))
                                    .foregroundStyle(DesignTokens.inkSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                    }
                }
            }
            Text(hints[hintIndex])
                .font(.system(size: 13))
                .foregroundStyle(DesignTokens.inkSecondary)
                .id(hintIndex)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - 环境光斑（待机装饰）
    private var ambientBlobs: some View {
        ZStack {
            Circle()
                .fill(DesignTokens.m1Orange.opacity(0.15))
                .blur(radius: 46)
                .frame(width: 250, height: 250)
                .offset(x: -120, y: -200)
            Circle()
                .fill(DesignTokens.m2Purple.opacity(0.13))
                .blur(radius: 46)
                .frame(width: 230, height: 230)
                .offset(x: 120, y: -180)
            Circle()
                .fill(DesignTokens.m3Green.opacity(0.13))
                .blur(radius: 46)
                .frame(width: 240, height: 240)
                .offset(x: -110, y: 200)
            Circle()
                .fill(DesignTokens.m4Yellow.opacity(0.15))
                .blur(radius: 46)
                .frame(width: 250, height: 250)
                .offset(x: 120, y: 200)
        }
    }

    private func clockString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func refreshReminders() async {
        do {
            let checkin = CheckInProvider(context: modelContext)
            let thoughts = ThoughtProvider(context: modelContext)
            let drafts = DraftProvider(context: modelContext)
            let agg = IdleReminders(checkInProvider: checkin, thoughtProvider: thoughts, draftProvider: drafts)
            let result = try agg.reminders()
            await MainActor.run { reminders = result }
        } catch {
            await MainActor.run { reminders = [] }
        }
    }
}
