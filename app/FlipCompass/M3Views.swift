import SwiftUI
import SwiftData

// MARK: - M3 视图组件（原型 .coupon / .info-card / .chips / .pref-row 双列栅格转录）
// B3a：卡片统一「白玻璃 + 轻描边 + 轻阴影（radius 8 → 不越界不裁切）」，
// 与头部胶囊拉开层次（解决第一卡与头部相似不明显）。

// MARK: M3 卡片基础样式（轻阴影白玻璃 · 选中描边+微染）

extension View {
    func m3Card(selected: Bool, corner: CGFloat = DSToken.rCard) -> some View {
        background(
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [.white.opacity(0.94), .white.opacity(0.70)]),
                    startPoint: .init(x: 0.5, y: 0), endPoint: .init(x: 0.44, y: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                if selected {
                    LinearGradient(
                        gradient: Gradient(colors: [DSToken.m3.opacity(0.07), DSToken.m3.opacity(0.04)]),
                        startPoint: .top, endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(
                    selected ? DSToken.m3.opacity(0.55) : Color.white.opacity(0.95),
                    lineWidth: selected ? 1.5 : 1
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: p0 券卡（原型 .coupon：tag 行 + 标题 + 副题 + 倒计时大数字 + 状态条）

struct M3CouponCard: View {
    let coupon: CouponCard
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("优惠券")
                    .font(DSToken.body(10.5, weight: .bold))
                    .foregroundStyle(DSToken.m3)
                    .tracking(0.5)
                if coupon.fav {
                    Text("♡")
                        .font(DSToken.body(10.5))
                        .foregroundStyle(DSToken.m3.opacity(0.85))
                }
            }
            Text(coupon.title)
                .font(DSToken.body(16, weight: .bold))
                .foregroundStyle(DSToken.ink)
                .lineLimit(1)
                .padding(.top, 7)
            Text(coupon.sub)
                .font(DSToken.body(12))
                .foregroundStyle(DSToken.ink2)
                .lineLimit(1)
                .padding(.top, 4)
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("\(coupon.daysLeft)")
                    .font(DSToken.num(38, weight: .semibold))
                    .foregroundStyle(DSToken.m3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("天后过期")
                    .font(DSToken.body(12.5))
                    .foregroundStyle(DSToken.ink2)
                    .lineLimit(1)
            }
            .padding(.top, 12)
            // cp-bar：绿渐变状态条（progress % → 实际宽度）
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(red: 0xEF / 255, green: 0xEF / 255, blue: 0xF4 / 255))
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [DSToken.m3, Color(red: 0x5F / 255, green: 0xD8 / 255, blue: 0x78 / 255)]),
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * min(1, CGFloat(coupon.progress) / 100)))
                }
            }
            .frame(height: 7)
            .padding(.top, 12)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .m3Card(selected: selected)
        .opacity(M3Store.couponDimmed(state: coupon.state) ? 0.55 : 1)
        .contentShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        .onTapGesture { onTap() }
    }
}

// MARK: p0/p1 情报卡（原型 .info-card：tag 行 + ♥ + 标题 + 副题）

struct M3InfoCard: View {
    let item: FeedItem
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(item.tag)
                    .font(DSToken.body(10.5, weight: .bold))
                    .foregroundStyle(DSToken.m3)
                    .tracking(0.5)
                if item.fav {
                    Text("♥")
                        .font(DSToken.body(10.5))
                        .foregroundStyle(DSToken.m3.opacity(0.85))
                }
            }
            Text(item.title)
                .font(DSToken.body(15, weight: .semibold))
                .foregroundStyle(DSToken.ink)
                .lineSpacing(4)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 7)
            Text(item.sub)
                .font(DSToken.body(11.5))
                .foregroundStyle(DSToken.ink2)
                .lineLimit(1)
                .padding(.top, 6)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 122)
        .m3Card(selected: selected)
        .contentShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        .onTapGesture { onTap() }
    }
}

// MARK: p1 筛选 chips（原型 .chips + .chip：横滚，on = 模块色；hscroll 内部滚动优先）

struct M3Chips: View {
    let tags: [String]
    let current: String
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(tags, id: \.self) { tag in
                    let on = tag == current
                    Text(tag)
                        .font(DSToken.body(12.5, weight: on ? .semibold : .regular))
                        .foregroundStyle(on ? DSToken.m3 : DSToken.ink2)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white))
                        .overlay(
                            Capsule().strokeBorder(
                                on ? DSToken.m3.opacity(0.55) : DSToken.line,
                                lineWidth: 1
                            )
                        )
                        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                        .contentShape(Capsule())
                        .onTapGesture { onSelect(tag) }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: p2 偏好行（原型 .pref-row：label + 值 + › · 63px 行；RSS 后置灰）

struct M3PrefRow: View {
    let title: String
    let value: String
    let note: String?          // （V0.4.2 后置）
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DSToken.body(14.5, weight: .semibold))
                    .foregroundStyle(DSToken.ink)
                Text(value + (note ?? ""))
                    .font(DSToken.body(12.5))
                    .foregroundStyle(DSToken.ink2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if note == nil {
                Text("›")
                    .font(DSToken.body(17))
                    .foregroundStyle(selected ? DSToken.m3 : DSToken.ink3)
                    .offset(x: selected ? 3 : 0)
            } else {
                Text("›")
                    .font(DSToken.body(17))
                    .foregroundStyle(DSToken.ink3.opacity(0.35))
            }
        }
        .padding(.horizontal, 18)
        .frame(height: DSToken.hRow)
        .m3Card(selected: selected, corner: DSToken.rCard)
        .contentShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        .onTapGesture { onTap() }
    }
}
// MARK: - d4 · 券详情（C5 · 原型 #scr-d4 · hero 卡片生长页）
// 券票大卡（值+倒计时+状态胶囊 · 中缝穿孔虚线）→ 三行元信息 → 券码（已领显示 · 复制）→
// 可用门店列表 → 主 CTA（四态切换：领取 → 标记已使用 → 已使用；过期置灰不可点）。

struct M3CouponDetailPage: View {
    @Environment(\.modelContext) private var modelContext
    let coupon: CouponCard
    let onBack: () -> Void
    /// CTA 点击（父级推进状态机 + toast）
    let onAdvance: () -> Void
    /// 页内轻提示（复制券码等）
    let onToast: (String) -> Void

    /// used/expired 终态（CTA 置灰不可点 · cp-code 是否显示分：claimed/used 显示）
    private var terminal: Bool { M3Store.couponDimmed(state: coupon.state) }
    private var codeVisible: Bool { coupon.state == "claimed" || coupon.state == "used" }

    private var stateColor: Color {
        switch coupon.state {
        case "used": return DSToken.ink2
        case "expired": return DSToken.bad
        default: return DSToken.m3
        }
    }

    private var stateBorder: Color {
        switch coupon.state {
        case "used": return DSToken.line
        case "expired": return DSToken.bad.opacity(0.38)
        default: return DSToken.m3.opacity(0.40)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    Text(coupon.title)
                        .font(DSToken.body(27, weight: .bold))
                        .foregroundStyle(DSToken.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)

                    Text(coupon.sub)
                        .font(DSToken.body(12.5))
                        .foregroundStyle(DSToken.ink2)
                        .padding(.top, 8)

                    // ---- 券票大卡（.cp-hero：模块色渐变 · 中缝穿孔虚线）----
                    ticketHero
                        .padding(.top, 22)

                    // ---- 元信息三行（.cp-meta）----
                    VStack(spacing: 11) {
                        metaRow("使用门槛", coupon.threshold)
                        metaRow("有效期", coupon.valid)
                        metaRow("适用范围", coupon.scope)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 20)

                    // ---- 券码（.cp-code：已领/已用显示 · 复制）----
                    if codeVisible {
                        HStack(spacing: 10) {
                            Text(coupon.code)
                                .font(DSToken.body(17, weight: .semibold))
                                .tracking(2.5)
                                .foregroundStyle(DSToken.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                UIPasteboard.general.string =
                                    coupon.code.replacingOccurrences(of: " ", with: "")
                                onToast("券码已复制")
                            } label: {
                                Text("复制券码")
                                    .font(DSToken.body(11.5, weight: .semibold))
                                    .foregroundStyle(DSToken.m3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.9))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(DSToken.m3.opacity(0.42),
                                              style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        )
                        .padding(.top, 14)
                    }

                    // ---- 可用门店 ----
                    HStack(spacing: 6) {
                        Text("可用门店")
                            .font(DSToken.body(12, weight: .semibold))
                            .foregroundStyle(DSToken.ink2)
                            .tracking(0.5)
                        Text("\(coupon.shops.count) 家")
                            .font(DSToken.body(10.5))
                            .foregroundStyle(DSToken.ink3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 2)
                    .padding(.top, 22)
                    .padding(.bottom, 6)

                    VStack(spacing: 8) {
                        ForEach(Array(coupon.shops.enumerated()), id: \.offset) { i, shop in
                            shopRow(index: i + 1, text: shop)
                        }
                    }

                    // ---- 主 CTA（四态切换 · 终态置灰不可点）----
                    Button(action: onAdvance) {
                        Text(M3Store.couponCTA(state: coupon.state))
                            .font(DSToken.body(16.5, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                                    .fill(
                                        terminal
                                        ? AnyShapeStyle(DSToken.ink3)
                                        : AnyShapeStyle(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    DSToken.m3.mixedWithWhite(0.25),
                                                    DSToken.m3
                                                ]),
                                                startPoint: UnitPoint(x: 0.5, y: 0),
                                                endPoint: UnitPoint(x: 0.33, y: 1)
                                            )
                                        )
                                    )
                            )
                            .shadow(color: terminal ? .clear : DSToken.m3.opacity(0.32),
                                    radius: 13, y: 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(terminal)
                    .opacity(terminal ? 0.75 : 1)
                    .padding(.top, 18)

                    HStack(spacing: 6) {
                        Text("✎")
                        Text("领取后可出示券码到店核销 · 过期自动失效")
                    }
                    .font(DSToken.body(11))
                    .foregroundStyle(DSToken.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 9)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)

            // 返回按钮压在 ScrollView 之上（ZStack 后写 = 上层），防被全屏 ScrollView 拦截
            HeroBackButton(title: "生活情报站", color: DSToken.m3) { onBack() }
        }
    }

    /// 券票大卡（.cp-hero：值 40 + 倒计时 + 状态胶囊 · 中缝穿孔虚线 · 顶部内嵌高光）
    private var ticketHero: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("券")
                    .font(DSToken.body(16, weight: .semibold))
                    .foregroundStyle(DSToken.m3)
                Text(coupon.value)
                    .font(DSToken.body(40, weight: .semibold))
                    .foregroundStyle(DSToken.m3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Text(coupon.daysLeft > 0 ? "\(coupon.daysLeft) 天后过期" : "今日过期")
                .font(DSToken.body(11.5))
                .foregroundStyle(DSToken.ink2)
                .padding(.top, 8)

            HStack(spacing: 5) {
                Circle().fill(stateColor).frame(width: 4, height: 4)
                Text(M3Store.couponLabel(state: coupon.state))
                    .font(DSToken.body(11, weight: .semibold))
                    .foregroundStyle(stateColor)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 4)
            .background(Capsule().fill(.white))
            .overlay(Capsule().strokeBorder(stateBorder, lineWidth: 1))
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(
            ZStack(alignment: .top) {
                LinearGradient(
                    gradient: Gradient(colors: [
                        DSToken.m3.mixedWithWhite(0.84),   // color-mix(m3 16%, #fff)
                        DSToken.m3.mixedWithWhite(0.95),   // color-mix(m3 5%, #fff)
                    ]),
                    startPoint: UnitPoint(x: 0.5, y: 0), endPoint: UnitPoint(x: 0.44, y: 1)
                )
                LinearGradient(
                    gradient: Gradient(colors: [.white.opacity(0.95), .white.opacity(0)]),
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 3)   // inset 顶部高光
            }
            .clipShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        )
        .overlay(
            // 中缝穿孔虚线（原型 .cp-hero::after top:50%）
            GeometryReader { g in
                Path { p in
                    p.move(to: CGPoint(x: 0, y: g.size.height / 2))
                    p.addLine(to: CGPoint(x: g.size.width, y: g.size.height / 2))
                }
                .stroke(DSToken.m3.opacity(0.26),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [7, 5]))
            }
        )
        .shadow(color: DSToken.m3.opacity(0.22), radius: 12, y: 6)
    }

    private func metaRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(k)
                .font(DSToken.body(12))
                .foregroundStyle(DSToken.ink2)
                .frame(width: 58, alignment: .leading)
            Text(v)
                .font(DSToken.body(13))
                .foregroundStyle(DSToken.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 门店行（.cp-shop：序号块 + 名称：距离）
    private func shopRow(index: Int, text: String) -> some View {
        HStack(spacing: 9) {
            Text("\(index)")
                .font(DSToken.body(11, weight: .semibold))
                .foregroundStyle(DSToken.m3)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(DSToken.m3.mixedWithWhite(0.86))
                )
            Text(text)
                .font(DSToken.body(12.5))
                .foregroundStyle(DSToken.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - d5 · 情报详情（C6 · 原型 #scr-d5 · hero 卡片生长页）
// 标题 + 来源行（tag 胶囊 + 副题）+ 标签组 + 段落正文（1.78 行距）+ 底部收藏钮
// （♡/♥ 切换 · on 态模块色染底）；收藏/取消即时联动 p0 卡片 ♥ 角标与 p1 收藏夹。

struct M3FeedDetailPage: View {
    let item: FeedItem
    let onBack: () -> Void
    /// 页内轻提示（收藏/取消收藏）
    let onToast: (String) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.title)
                            .font(DSToken.body(27, weight: .bold))
                            .foregroundStyle(DSToken.ink)
                            .lineSpacing(4)
                            .padding(.top, 120)

                        // d5-src：来源行（tag 胶囊 + 副题）
                        HStack(spacing: 8) {
                            Text(item.tag)
                                .font(DSToken.body(10.5, weight: .bold))
                                .foregroundStyle(DSToken.m3)
                                .tracking(0.5)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(DSToken.m3.mixedWithWhite(0.88))   // color-mix(m3 12%, #fff)
                                )
                            Text(item.sub)
                                .font(DSToken.body(11.5))
                                .foregroundStyle(DSToken.ink2)
                        }
                        .padding(.top, 12)

                        // d5-tags：标签组胶囊
                        HStack(spacing: 6) {
                            ForEach(item.tags, id: \.self) { t in
                                Text(t)
                                    .font(DSToken.body(11))
                                    .foregroundStyle(DSToken.ink2)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(.white.opacity(0.9)))
                                    .overlay(Capsule().strokeBorder(DSToken.line, lineWidth: 1))
                            }
                        }
                        .padding(.top, 10)

                        // d5-body-text：段落正文（1.78 行距 · 段间距 12）
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(item.paragraphs.enumerated()), id: \.offset) { _, p in
                                Text(p)
                                    .font(DSToken.body(14))
                                    .foregroundStyle(DSToken.ink)
                                    .lineSpacing(11)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.top, 18)
                    }
                    .padding(.bottom, 6)
                }
                .scrollIndicators(.hidden)

                // d5-foot：收藏钮（默认白底 34% 边；on = 12% 模块染底 + 55% 边）
                Button(action: toggleFav) {
                    HStack(spacing: 7) {
                        Text(item.fav ? "♥" : "♡")
                            .font(DSToken.body(16))
                        Text(item.fav ? "已收藏" : "收藏")
                            .font(DSToken.body(15, weight: .semibold))
                    }
                    .foregroundStyle(DSToken.m3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                            .fill(item.fav ? DSToken.m3.mixedWithWhite(0.88) : Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                            .strokeBorder(
                                DSToken.m3.opacity(item.fav ? 0.55 : 0.34),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 28)

            // 返回按钮压在 ScrollView 之上（ZStack 后写 = 上层），防被全屏 ScrollView 拦截
            HeroBackButton(title: "生活情报站", color: DSToken.m3) { onBack() }
        }
    }

    /// 收藏切换：@Model 属性即时持久化；p0 ♥ 角标与 p1 收藏夹由查询自动联动
    private func toggleFav() {
        item.fav.toggle()
        onToast(item.fav ? "已收藏「\(item.title)」" : "已取消收藏「\(item.title)」")
    }
}

// MARK: - d7 · 偏好编辑（C7 · 原型 #scr-d7 · hero 卡片生长页）
// taste/takeout = 标签多选（draft 隔离，取消不污染）；price = 三档 slider
// （轨道 6pt + 模块绿渐变填充 + 24pt 白旋钮 + 点按/拖动吸附三档）；保存写回 + toast。

struct M3PrefEditPage: View {
    let pref: Preference
    let onBack: () -> Void
    /// 保存回调（父级 toast + 原路收回）
    let onSaved: (String) -> Void

    @State private var draft: [String] = []
    @State private var level: Int = 1

    private var isPrice: Bool { pref.key == "price" }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    Text(pref.title)
                        .font(DSToken.body(27, weight: .bold))
                        .foregroundStyle(DSToken.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)

                    Text(pref.sub)
                        .font(DSToken.body(12.5))
                        .foregroundStyle(DSToken.ink2)
                        .padding(.top, 8)

                    if isPrice {
                        fieldLabel("价格敏感度", hint: "单选")
                            .padding(.top, 24)
                        priceSlider
                    } else {
                        fieldLabel(pref.key == "takeout" ? "外卖标签" : "口味标签", hint: "可多选")
                            .padding(.top, 24)
                        tagGroup
                            .padding(.top, 6)
                    }

                    // 保存（原型 .primary-btn）
                    Button(action: save) {
                        Text("保存")
                            .font(DSToken.body(16.5, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [DSToken.m3.mixedWithWhite(0.25), DSToken.m3]),
                                            startPoint: UnitPoint(x: 0.5, y: 0), endPoint: UnitPoint(x: 0.33, y: 1)
                                        )
                                    )
                            )
                            .shadow(color: DSToken.m3.opacity(0.32), radius: 13, y: 10)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 18)

                    HStack(spacing: 6) {
                        Text("✎")
                        Text("保存后情报推荐会按你的偏好重新排序")
                    }
                    .font(DSToken.body(11))
                    .foregroundStyle(DSToken.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 9)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)

            HeroBackButton(title: "生活情报站", color: DSToken.m3) { onBack() }
        }
        .onAppear {
            draft = pref.selected          // draft 隔离：取消不写回
            level = pref.level
        }
    }

    // MARK: 多选标签组（原型 .d7-group chip on/off）

    private var tagGroup: some View {
        HStack(spacing: 8) {
            ForEach(pref.options, id: \.self) { t in
                let on = draft.contains(t)
                Text(t)
                    .font(DSToken.body(12.5, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? DSToken.m3 : DSToken.ink2)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(on ? DSToken.m3.mixedWithWhite(0.88) : Color.white)
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            on ? DSToken.m3.opacity(0.55) : DSToken.line, lineWidth: 1
                        )
                    )
                    .onTapGesture {
                        withAnimation(DSToken.spring) {
                            if let i = draft.firstIndex(of: t) {
                                draft.remove(at: i)
                            } else {
                                draft.append(t)
                            }
                        }
                    }
            }
        }
    }

    // MARK: 三档价格 slider（原型 .d7-slider：track 6pt + 渐变 fill + 24pt knob + 三档吸附）

    private var priceSlider: some View {
        VStack(spacing: 0) {
            GeometryReader { g in
                let pct = [0.0, 0.5, 1.0][min(max(level, 0), 2)]
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(red: 0xEF / 255, green: 0xEF / 255, blue: 0xF4 / 255))
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [DSToken.m3,
                                    Color(red: 0x5F / 255, green: 0xD8 / 255, blue: 0x78 / 255)]),
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(g.size.width * pct, 6), height: 6)
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
                        .shadow(color: .black.opacity(0.04), radius: 1)
                        .offset(x: g.size.width * pct - 12)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let raw = v.location.x / g.size.width
                            let snapped = min(max(Int((raw * 2).rounded()), 0), 2)
                            if snapped != level {
                                withAnimation(DSToken.spring) { level = snapped }
                            }
                        }
                )
            }
            .frame(height: 28)
            .padding(.top, 10)

            // scale 三档文字
            HStack {
                ForEach(M3Store.priceTiers, id: \.self) { t in
                    Text(t)
                        .font(DSToken.body(10.5))
                        .foregroundStyle(DSToken.ink3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 9)

            // cur 当前档
            Text(M3Store.priceTiers[min(max(level, 0), 2)])
                .font(DSToken.body(13, weight: .semibold))
                .foregroundStyle(DSToken.m3)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
    }

    // MARK: 保存（写回 @Model 即时生效；父级收回 + toast）

    private func save() {
        if isPrice {
            pref.level = level
        } else {
            pref.selected = draft
        }
        onSaved("偏好已保存 · 情报推荐会重新排序")
    }

    private func fieldLabel(_ text: String, hint: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(DSToken.body(12, weight: .semibold))
                .foregroundStyle(DSToken.ink2)
                .tracking(0.5)
            Text(hint)
                .font(DSToken.body(10.5))
                .foregroundStyle(DSToken.ink3)
                .padding(.leading, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 2)
    }
}
