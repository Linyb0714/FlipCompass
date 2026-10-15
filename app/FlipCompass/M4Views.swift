import SwiftUI

// MARK: - M4 视图组件（原型 .game-hero / .gt-* / .badge / .encourage / .pref-row 转录）

// MARK: 游戏图标块（原型 .gi：渐变块 + 白字；hero 58 / tile 42）

struct M4GameIcon: View {
    let meta: GameMeta
    var side: CGFloat = 58
    var fontSize: CGFloat = 26

    var body: some View {
        Text(meta.glyph)
            .font(DSToken.body(fontSize, weight: .semibold))
            .foregroundStyle(.white)
            .minimumScaleFactor(0.4)
            .frame(width: side, height: side)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [meta.iconTop, meta.iconBottom]),
                    startPoint: UnitPoint(x: 0.2, y: 0), endPoint: .init(x: 0.85, y: 0.95)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: side * 0.29, style: .continuous))
            .shadow(color: DSToken.m4.opacity(0.35), radius: 11, y: 8)
    }
}

// MARK: p0 继续游戏英雄卡（原型 .game-hero：135° 白→模块色微染 + 图标 + 标题 + 胶囊组 + ›）

struct M4GameHero: View {
    let meta: GameMeta
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            M4GameIcon(meta: meta)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(meta.name) · \(meta.continueLevel)")
                    .font(DSToken.body(18, weight: .bold))
                    .foregroundStyle(DSToken.ink)
                    .lineLimit(1)
                // gh-s：b（继续上一局）= 模块色
                (Text("继续上一局")
                    .font(DSToken.body(12.5, weight: .semibold))
                    .foregroundStyle(DSToken.m4)
                 + Text(" · 盘面已存好")
                    .font(DSToken.body(12.5))
                    .foregroundStyle(DSToken.ink2))
                // score-chips 胶囊组
                HStack(spacing: 8) {
                    ForEach(meta.continueChips, id: \.self) { c in
                        Text(c)
                            .font(DSToken.body(12))
                            .foregroundStyle(DSToken.ink2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white))
                            .overlay(
                                Capsule().strokeBorder(DSToken.line, lineWidth: 1)
                            )
                    }
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("›")
                .font(DSToken.body(22))
                .foregroundStyle(selected ? DSToken.m4 : DSToken.ink3)
                .offset(x: selected ? 3 : 0)
        }
        .padding(.horizontal, 19)
        .padding(.vertical, 19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            // 135° 白 40% → 模块色 10%（原型 game-hero 底）
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .white, location: 0.0),
                    .init(color: .white, location: 0.40),
                    .init(color: DSToken.m4.opacity(0.10), location: 1.0),
                ]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                .strokeBorder(
                    selected ? DSToken.m4.opacity(0.55) : Color.white.opacity(0.95),
                    lineWidth: selected ? 1.5 : 1
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        .onTapGesture { onTap() }
    }
}

// MARK: p0 统计卡（原型 .info-card 变体：tag + 「今天已玩 N 局」/「已连玩 N 天」+ 副标）

struct M4StatCard: View {
    let tag: String
    /// 主行富文本（数值已格式化入串）
    let title: AttributedString
    let sub: String
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tag)
                .font(DSToken.body(10.5, weight: .bold))
                .foregroundStyle(DSToken.m4)
                .tracking(0.5)
            Text(title)
                .font(DSToken.body(14))
                .lineLimit(2)
                .padding(.top, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(sub)
                .font(DSToken.body(11.5))
                .foregroundStyle(DSToken.ink2)
                .lineLimit(1)
                .padding(.top, 6)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .m4Card(selected: selected)
        .contentShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        .onTapGesture { onTap() }
    }
}

// MARK: p1 游戏卡（原型 .game-tile：gt-head 图标+名称+副标 + 黄星）

struct M4GameTile: View {
    let meta: GameMeta
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 11) {
                M4GameIcon(meta: meta, side: 42, fontSize: 19)
                VStack(alignment: .leading, spacing: 2) {
                    Text(meta.name)
                        .font(DSToken.body(16, weight: .bold))
                        .foregroundStyle(DSToken.ink)
                        .lineLimit(1)
                    Text(meta.sub)
                        .font(DSToken.body(11.5))
                        .foregroundStyle(DSToken.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 星级：★实 / ☆空 · 黄色 · 字距 2.5
            (Text(String(repeating: "★", count: meta.stars))
             + Text(String(repeating: "☆", count: M4Store.starMax - meta.stars)))
                .font(DSToken.body(13))
                .kerning(2.5)
                .foregroundStyle(DSToken.m4)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 17)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .m4Card(selected: selected)
        .contentShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        .onTapGesture { onTap() }
    }
}

// MARK: p2 勋章（原型 .badge：57 圆 · on 渐变白字 / locked 灰问号 · sel 模块色描边环）

struct M4Badge: View {
    let badge: BadgeDef
    let unlocked: Bool
    let selected: Bool

    var body: some View {
        VStack(spacing: 9) {
            Text(unlocked ? badge.glyph : "?")
                .font(DSToken.body(22, weight: .semibold))
                .foregroundStyle(unlocked ? .white : Color(red: 0xC7/255, green: 0xC7/255, blue: 0xCC/255))
                .frame(width: 57, height: 57)
                .background(
                    Group {
                        if unlocked {
                            LinearGradient(
                                gradient: Gradient(colors: [DSToken.m4.opacity(0.65).mixWhite(), DSToken.m4]),
                                startPoint: UnitPoint(x: 0.2, y: 0), endPoint: .init(x: 0.85, y: 0.95)
                            )
                        } else {
                            Color(red: 0xEF/255, green: 0xEF/255, blue: 0xF4/255)
                        }
                    }
                )
                .clipShape(Circle())
                .overlay(
                    // 选中描边环（白 2 + 模块色 4；locked 灰环）
                    Circle().strokeBorder(
                        selected
                            ? (unlocked ? DSToken.m4 : DSToken.ink3.opacity(0.6))
                            : .clear,
                        lineWidth: 4
                    )
                    .padding(-4)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2).padding(-2))
                    .opacity(selected ? 1 : 0)
                )
                .shadow(color: unlocked ? DSToken.m4.opacity(0.35) : .clear, radius: 8, y: 6)
            Text(badge.name)
                .font(DSToken.body(11, weight: .semibold))
                .foregroundStyle(selected ? DSToken.m4 : DSToken.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - M4 卡片基础样式（轻阴影白玻璃 · 同 m3Card 语言 · 模块色黄）

extension Color {
    /// 白混（color-mix(in srgb, c x%, #fff) 语义）
    func mixWhite(_ amount: Double = 0.35) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: r + (1 - r) * amount,
                     green: g + (1 - g) * amount,
                     blue: b + (1 - b) * amount)
    }
}

extension View {
    func m4Card(selected: Bool) -> some View {
        background(
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [.white.opacity(0.94), .white.opacity(0.70)]),
                    startPoint: .init(x: 0.5, y: 0), endPoint: .init(x: 0.44, y: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
                if selected {
                    LinearGradient(
                        gradient: Gradient(colors: [DSToken.m4.opacity(0.07), DSToken.m4.opacity(0.04)]),
                        startPoint: .top, endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                .strokeBorder(
                    selected ? DSToken.m4.opacity(0.55) : Color.white.opacity(0.95),
                    lineWidth: selected ? 1.5 : 1
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}
