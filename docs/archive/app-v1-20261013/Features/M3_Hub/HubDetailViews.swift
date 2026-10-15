import SwiftUI
import SwiftData

/// M3 二级页 - 券详情（d4）
/// V0.4.2 状态机：未领 → 已领 → 已用 / 过期
struct CouponDetailView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext

    let itemID: String?

    @State private var coupon: CouponCard? = nil
    @State private var toast: Toast?

    var body: some View {
        VStack(spacing: 0) {
            header
            if let c = coupon {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.spacing) {
                        heroCard(c)
                        infoSection(c)
                        if shouldShowCode(c) {
                            codeSection(c)
                        }
                        if !c.shops.isEmpty {
                            shopsSection(c)
                        }
                        ctaSection(c)
                    }
                    .padding(.horizontal, DesignTokens.spacing)
                    .padding(.vertical, DesignTokens.spacing)
                }
            } else {
                Spacer()
                Text("券不存在").foregroundStyle(DesignTokens.inkSecondary)
                Spacer()
            }
        }
        .background(DesignTokens.bgPrimary.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast { ToastView(toast: toast).padding(.bottom, 32) }
        }
        .task { load() }
    }

    private var header: some View {
        HStack {
            Button(action: { state.backOneLevel() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
            }
            Spacer()
            Text("券详情").font(.system(size: 15, weight: .semibold)).foregroundStyle(DesignTokens.ink)
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, DesignTokens.spacing)
        .padding(.vertical, 10)
    }

    private func heroCard(_ c: CouponCard) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(c.source)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignTokens.inkSecondary)
                Spacer()
                Text(stateText(c))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(stateColor(c))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(stateColor(c).opacity(0.14))
                    .clipShape(Capsule())
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(c.value)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignTokens.m3Green)
                Spacer()
            }
            Text(c.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DesignTokens.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                Text("剩余 \(daysLeft(c)) 天")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(daysLeft(c) <= 2 ? DesignTokens.error : DesignTokens.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            // 虚线撕口
            DashedDivider()
                .padding(.top, 4)
        }
        .padding(DesignTokens.spacing)
        .glassCard(moduleColor: DesignTokens.m3Green)
    }

    private func infoSection(_ c: CouponCard) -> some View {
        VStack(spacing: 0) {
            InfoRow(icon: "cart", label: "使用门槛", value: c.threshold.isEmpty ? "无门槛" : c.threshold)
            Divider().padding(.leading, 36)
            InfoRow(icon: "calendar", label: "有效期", value: "至 \(fullDateString(c.expireAt))")
            Divider().padding(.leading, 36)
            InfoRow(icon: "mappin.circle", label: "适用范围", value: c.scope.isEmpty ? "全场通用" : c.scope)
        }
        .glassCard(moduleColor: DesignTokens.m3Green)
    }

    private func codeSection(_ c: CouponCard) -> some View {
        VStack(spacing: 6) {
            Text("券码")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignTokens.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text(c.code)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(DesignTokens.ink)
                Spacer()
                Button(action: { copyCode(c) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("复制")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignTokens.m3Green)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(DesignTokens.m3Green.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.spacing)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(DesignTokens.m3Green.opacity(0.4))
            )
        }
    }

    private func shopsSection(_ c: CouponCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("可用门店")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.inkSecondary)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(c.shops.enumerated()), id: \.0) { idx, shop in
                    if idx > 0 { Divider().padding(.leading, 36) }
                    InfoRow(icon: "mappin", label: shop, value: "")
                }
            }
            .glassCard(moduleColor: DesignTokens.m3Green)
        }
    }

    private func ctaSection(_ c: CouponCard) -> some View {
        Button(action: { advance(c) }) {
            Text(ctaText(c))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ctaEnabled(c) ? DesignTokens.m3Green : DesignTokens.inkSecondary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!ctaEnabled(c))
    }

    // MARK: - 状态机
    private func stateText(_ c: CouponCard) -> String {
        switch c.state {
        case .unclaimed: return "未领取"
        case .claimed: return "已领取"
        case .used: return "已使用"
        case .expired: return "已过期"
        }
    }
    private func stateColor(_ c: CouponCard) -> Color {
        switch c.state {
        case .unclaimed: return DesignTokens.m3Green
        case .claimed: return DesignTokens.success
        case .used: return DesignTokens.inkSecondary
        case .expired: return DesignTokens.error
        }
    }
    private func shouldShowCode(_ c: CouponCard) -> Bool {
        c.state == .claimed || c.state == .used
    }
    private func ctaText(_ c: CouponCard) -> String {
        switch c.state {
        case .unclaimed: return "领取"
        case .claimed: return "标记已使用"
        case .used: return "已使用"
        case .expired: return "已过期"
        }
    }
    private func ctaEnabled(_ c: CouponCard) -> Bool {
        c.state == .unclaimed || c.state == .claimed
    }

    private func advance(_ c: CouponCard) {
        let hp = HubProvider(context: modelContext)
        switch c.state {
        case .unclaimed:
            try? hp.claim(c)
            toast = Toast(module: .hub, text: "已领取，去使用吧")
        case .claimed:
            try? hp.markUsed(c)
            toast = Toast(module: .hub, text: "已核销")
        default:
            break
        }
        load()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { toast = nil }
    }

    private func copyCode(_ c: CouponCard) {
        UIPasteboard.general.string = c.code
        toast = Toast(module: .hub, text: "券码已复制")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { toast = nil }
    }

    private func load() {
        guard let idStr = itemID, let uuid = UUID(uuidString: idStr) else { return }
        let desc = FetchDescriptor<CouponCard>(predicate: #Predicate { $0.id == uuid })
        coupon = try? modelContext.fetch(desc).first
    }

    private func daysLeft(_ c: CouponCard) -> Int {
        let days = Calendar.current.dateComponents([.day], from: .now, to: c.expireAt).day ?? 0
        return max(0, days)
    }
    private func fullDateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}

private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(DesignTokens.m3Green)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(DesignTokens.inkSecondary)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignTokens.ink)
            }
        }
        .padding(.horizontal, DesignTokens.spacing)
        .padding(.vertical, 12)
    }
}

private struct DashedDivider: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                let y = geo.size.height / 2
                var x: CGFloat = 0
                while x < geo.size.width {
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: min(x + 5, geo.size.width), y: y))
                    x += 9
                }
            }
            .stroke(DesignTokens.inkSecondary.opacity(0.4), lineWidth: 1)
        }
        .frame(height: 8)
    }
}

/// M3 二级页 - 情报详情（d5）
/// 段落正文 + 底部收藏/取消收藏
struct FeedDetailView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext

    let itemID: String?

    @State private var item: CollectionItem? = nil
    @State private var toast: Toast?

    var body: some View {
        VStack(spacing: 0) {
            header
            if let f = item {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.spacing) {
                        metaSection(f)
                        titleSection(f)
                        tagsSection(f)
                        bodySection(f)
                        favButton(f)
                    }
                    .padding(.horizontal, DesignTokens.spacing)
                    .padding(.vertical, DesignTokens.spacing)
                }
            } else {
                Spacer()
                Text("内容不存在").foregroundStyle(DesignTokens.inkSecondary)
                Spacer()
            }
        }
        .background(DesignTokens.bgPrimary.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast { ToastView(toast: toast).padding(.bottom, 32) }
        }
        .task { load() }
    }

    private var header: some View {
        HStack {
            Button(action: { state.backOneLevel() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
            }
            Spacer()
            Text("情报详情").font(.system(size: 15, weight: .semibold)).foregroundStyle(DesignTokens.ink)
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, DesignTokens.spacing)
        .padding(.vertical, 10)
    }

    private func metaSection(_ f: CollectionItem) -> some View {
        HStack(spacing: 6) {
            ForEach(f.tags.prefix(3), id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.m3Green)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(DesignTokens.m3Green.opacity(0.14))
                    .clipShape(Capsule())
            }
            if !f.source.isEmpty {
                Text("· \(f.source)")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.inkSecondary)
            }
            Spacer()
            Text(timeString(f.createdAt))
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.inkSecondary)
        }
    }

    private func titleSection(_ f: CollectionItem) -> some View {
        Text(f.title)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(DesignTokens.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tagsSection(_ f: CollectionItem) -> some View {
        Text(f.summary)
            .font(.system(size: 13))
            .foregroundStyle(DesignTokens.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bodySection(_ f: CollectionItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(f.body.components(separatedBy: "\n\n").enumerated()), id: \.0) { _, para in
                Text(para)
                    .font(.system(size: 14))
                    .lineSpacing(11)
                    .foregroundStyle(DesignTokens.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.spacing)
        .glassCard(moduleColor: DesignTokens.m3Green)
    }

    private func favButton(_ f: CollectionItem) -> some View {
        Button(action: { toggleFav(f) }) {
            HStack(spacing: 6) {
                Image(systemName: f.isFav ? "heart.fill" : "heart")
                Text(f.isFav ? "取消收藏" : "收藏")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(f.isFav ? .white : DesignTokens.m3Green)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(f.isFav ? DesignTokens.m3Green : DesignTokens.m3Green.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }

    private func toggleFav(_ f: CollectionItem) {
        let hp = HubProvider(context: modelContext)
        try? hp.toggleFav(f)
        toast = Toast(module: .hub, text: f.isFav ? "已收藏" : "已取消收藏")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { toast = nil }
    }

    private func load() {
        guard let idStr = itemID, let uuid = UUID(uuidString: idStr) else { return }
        let desc = FetchDescriptor<CollectionItem>(predicate: #Predicate { $0.id == uuid })
        item = try? modelContext.fetch(desc).first
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MM-dd"
        return f.string(from: d)
    }
}

/// M3 二级页 - 偏好编辑（d7）
/// tag-picker 多选 + slider 单选
struct HubPreferenceEditView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext

    @State private var tastes: Set<String> = []
    @State private var priceLevel: Int = 1     // 0=只看低价 1=适中 2=看品质
    @State private var toast: Toast?

    private let tasteOptions = ["中餐", "西餐", "日料", "轻食", "咖啡", "甜品"]
    private let priceLabels = ["只看低价", "适中", "看品质"]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacing2) {
                    tasteSection
                    priceSection
                }
                .padding(.horizontal, DesignTokens.spacing)
                .padding(.vertical, DesignTokens.spacing)
            }
        }
        .background(DesignTokens.bgPrimary.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast { ToastView(toast: toast).padding(.bottom, 32) }
        }
        .task { load() }
    }

    private var header: some View {
        HStack {
            Button(action: { state.backOneLevel() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
            }
            Spacer()
            Text("偏好编辑").font(.system(size: 15, weight: .semibold)).foregroundStyle(DesignTokens.ink)
            Spacer()
            Button(action: save) {
                Text("保存")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.m3Green)
            }
        }
        .padding(.horizontal, DesignTokens.spacing)
        .padding(.vertical, 10)
    }

    private var tasteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("口味偏好 · 常点外卖")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.inkSecondary)
            HubFlowLayout(spacing: 8) {
                ForEach(tasteOptions, id: \.self) { t in
                    let selected = tastes.contains(t)
                    Text(t)
                        .font(.system(size: 13, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? .white : DesignTokens.ink)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(selected ? DesignTokens.m3Green : DesignTokens.bgSecondary)
                        .clipShape(Capsule())
                        .onTapGesture {
                            withAnimation(DesignTokens.springEase) {
                                if selected { tastes.remove(t) } else { tastes.insert(t) }
                            }
                        }
                }
            }
            .padding(DesignTokens.spacing)
            .glassCard(moduleColor: DesignTokens.m3Green)
        }
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("价格敏感度")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.inkSecondary)
            VStack(spacing: 14) {
                HStack {
                    ForEach(0..<3, id: \.self) { idx in
                        Text(priceLabels[idx])
                            .font(.system(size: 12, weight: priceLevel == idx ? .semibold : .regular))
                            .foregroundStyle(priceLevel == idx ? DesignTokens.m3Green : DesignTokens.inkSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(DesignTokens.bgSecondary)
                            .frame(height: 6)
                        Capsule()
                            .fill(DesignTokens.m3Green)
                            .frame(width: fillWidth(in: geo.size.width), height: 6)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 22, height: 22)
                            .shadow(color: DesignTokens.m3Green.opacity(0.3), radius: 4, y: 2)
                            .overlay(Circle().stroke(DesignTokens.m3Green, lineWidth: 2))
                            .offset(x: knobOffset(in: geo.size.width))
                            .gesture(
                                DragGesture()
                                    .onChanged { v in
                                        let ratio = min(max(0, v.location.x / geo.size.width), 1)
                                        let newLevel = Int(round(ratio * 2))
                                        if newLevel != priceLevel {
                                            priceLevel = newLevel
                                        }
                                    }
                            )
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let ratio = min(max(0, v.location.x / geo.size.width), 1)
                                let newLevel = Int(round(ratio * 2))
                                if newLevel != priceLevel {
                                    priceLevel = newLevel
                                }
                            }
                    )
                }
                .frame(height: 22)
            }
            .padding(DesignTokens.spacing)
            .glassCard(moduleColor: DesignTokens.m3Green)
        }
    }

    private func fillWidth(in w: CGFloat) -> CGFloat {
        let ratio = CGFloat(priceLevel) / 2.0
        return max(6, ratio * w)
    }
    private func knobOffset(in w: CGFloat) -> CGFloat {
        let ratio = CGFloat(priceLevel) / 2.0
        return ratio * (w - 22)
    }

    private func load() {
        let hp = HubProvider(context: modelContext)
        let prefs = (try? hp.preferences()) ?? []
        if let tastePref = prefs.first(where: { $0.key == "taste" }) {
            tastes = Set(tastePref.value.components(separatedBy: ",").filter { !$0.isEmpty })
        } else {
            tastes = ["中餐", "咖啡"]
        }
        if let pricePref = prefs.first(where: { $0.key == "priceLevel" }),
           let v = Int(pricePref.value) {
            priceLevel = min(max(0, v), 2)
        }
    }

    private func save() {
        let hp = HubProvider(context: modelContext)
        try? hp.setPreference(key: "taste", value: tastes.sorted().joined(separator: ","), category: "food")
        try? hp.setPreference(key: "priceLevel", value: String(priceLevel), category: "food")
        toast = Toast(module: .hub, text: "已保存")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            state.backOneLevel()
        }
    }
}

// MARK: - FlowLayout（M3 专用）
private struct HubFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width {
                x = 0; y += lineH + spacing; lineH = 0
            }
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
        return CGSize(width: width, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX {
                x = bounds.minX; y += lineH + spacing; lineH = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
    }
}
