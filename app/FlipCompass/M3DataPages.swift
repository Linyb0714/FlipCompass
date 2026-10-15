import SwiftUI
import SwiftData
import CoreLocation

// MARK: - 数据源两页（C5+ 方案③④）
// M3RssPage：情报订阅源管理（列表 + 添加 + 开关 + 删除 + 立即拉取）
// M3NearbyPage：附近好店（高德 Key 引导 → 定位 → 关键词搜索 → 一键收进情报）

// MARK: ③ 情报订阅（RSS/Atom）

struct M3RssPage: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\RssSource.createdAt, order: .reverse)]) private var sources: [RssSource]
    @Query(sort: [SortDescriptor(\FeedItem.createdAt, order: .reverse)]) private var feeds: [FeedItem]

    let onClose: () -> Void
    let onToast: (String) -> Void

    @State private var newTitle = ""
    @State private var newUrl = ""
    @State private var refreshing = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    Text("情报订阅")
                        .font(DSToken.body(27, weight: .bold))
                        .foregroundStyle(DSToken.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                    Text("RSS/Atom 公开源 · 拉取后混进今日推送")
                        .font(DSToken.body(12.5))
                        .foregroundStyle(DSToken.ink2)
                        .padding(.top, 8)

                    // 源列表
                    VStack(spacing: 8) {
                        if sources.isEmpty {
                            Text("还没有订阅源\n在下面添加一个试试")
                                .font(DSToken.body(13))
                                .foregroundStyle(DSToken.ink3)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 26)
                        }
                        ForEach(sources) { s in
                            sourceRow(s)
                        }
                    }
                    .padding(.top, 22)

                    // 添加区
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("添加源")
                                .font(DSToken.body(12, weight: .semibold))
                                .foregroundStyle(DSToken.ink2)
                            Text("名称 + 地址（https://…/feed）")
                                .font(DSToken.body(10.5))
                                .foregroundStyle(DSToken.ink3)
                        }
                        HStack(spacing: 10) {
                            TextField("少数派", text: $newTitle)
                                .textFieldStyle(.plain)
                                .font(DSToken.body(15))
                                .padding(.horizontal, 12)
                                .frame(width: 104, height: 40)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white.opacity(0.92)))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(DSToken.line, lineWidth: 1))
                            TextField("https://sspai.com/feed", text: $newUrl)
                                .textFieldStyle(.plain)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(DSToken.body(14))
                                .padding(.horizontal, 12)
                                .frame(height: 40)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white.opacity(0.92)))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(DSToken.line, lineWidth: 1))
                            Button(action: addSource) {
                                Text("添加")
                                    .font(DSToken.body(13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .frame(height: 40)
                                    .background(Capsule().fill(DSToken.m3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 20)

                    // 立即拉取
                    Button(action: refreshAll) {
                        HStack(spacing: 8) {
                            if refreshing { ProgressView().tint(.white) }
                            Text(refreshing ? "拉取中…" : "立即拉取全部启用源")
                                .font(DSToken.body(16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [DSToken.m3.mixedWithWhite(0.25), DSToken.m3]),
                                        startPoint: UnitPoint(x: 0.5, y: 0), endPoint: UnitPoint(x: 0.33, y: 1)
                                    )
                                )
                        )
                        .shadow(color: DSToken.m3.opacity(0.32), radius: 12, y: 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(refreshing)
                    .opacity(refreshing ? 0.6 : 1)
                    .padding(.top, 20)

                    HStack(spacing: 6) {
                        Text("✎")
                        Text("拉取失败静默跳过 · 同名条目自动去重")
                    }
                    .font(DSToken.body(11))
                    .foregroundStyle(DSToken.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 9)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            HeroBackButton(title: "生活情报站", color: DSToken.m3) { onClose() }
        }
    }

    private func sourceRow(_ s: RssSource) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(s.title)
                    .font(DSToken.body(14, weight: .semibold))
                    .foregroundStyle(DSToken.ink)
                Text(s.url)
                    .font(DSToken.body(11))
                    .foregroundStyle(DSToken.ink3)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("上次拉取 \(RssService.shortDate(s.lastFetched, cal: .current))")
                    .font(DSToken.body(10))
                    .foregroundStyle(DSToken.ink3.opacity(0.8))
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(
                get: { s.enabled },
                set: { s.enabled = $0 }
            ))
                .labelsHidden()
                .tint(DSToken.m3)
            Button {
                withAnimation(DSToken.spring) { modelContext.delete(s) }
            } label: {
                Text("×")
                    .font(DSToken.body(17))
                    .foregroundStyle(DSToken.ink3)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(DSToken.line.opacity(0.7), lineWidth: 1)
        )
    }

    private func addSource() {
        let t = newTitle.trimmingCharacters(in: .whitespaces)
        let u = newUrl.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, u.contains("http") else {
            onToast("名称和 https:// 地址都要填")
            return
        }
        guard !sources.contains(where: { $0.url == u }) else {
            onToast("这个地址已经订阅过了")
            return
        }
        modelContext.insert(RssSource(title: t, url: u))
        newTitle = ""; newUrl = ""
        onToast("已添加「\(t)」· 点「立即拉取」试试")
    }

    private func refreshAll() {
        let active = sources.filter(\.enabled)
        guard !active.isEmpty else {
            onToast("没有启用中的源")
            return
        }
        refreshing = true
        let titles = feeds.map(\.title)
        let ctx = modelContext
        Task { @MainActor in
            var inserted = 0, failed = 0
            for s in active {
                do {
                    let r = try await RssService.importItems(from: s, into: ctx, existingTitles: titles)
                    inserted += r.inserted
                    s.lastFetched = Date()
                } catch {
                    failed += 1
                }
            }
            refreshing = false
            onToast("拉取完成 · 新增 \(inserted) 条" + (failed > 0 ? " · \(failed) 个源失败" : ""))
        }
    }
}

// MARK: ④ 附近好店（高德周边搜索 → 收进情报）

struct M3NearbyPage: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var feeds: [FeedItem]

    let onClose: () -> Void
    let onToast: (String) -> Void

    @State private var keyInput = PoiService.savedKey
    @State private var locating = false
    @State private var searching = false
    @State private var pois: [Poi] = []
    @State private var keyword = "美食"
    @State private var locationText = ""
    @State private var locOnce = LocationOnce()

    private let keywords = ["美食", "奶茶", "亲子", "面包", "超市", "咖啡"]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    Text("附近好店")
                        .font(DSToken.body(27, weight: .bold))
                        .foregroundStyle(DSToken.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                    Text("高德周边搜索 · 逛到哪收到哪")
                        .font(DSToken.body(12.5))
                        .foregroundStyle(DSToken.ink2)
                        .padding(.top, 8)

                    if PoiService.savedKey.isEmpty {
                        keyGuide
                    } else {
                        searchArea
                    }
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)

            HeroBackButton(title: "生活情报站", color: DSToken.m3) { onClose() }
        }
    }

    // MARK: Key 引导（无 Key 时）

    private var keyGuide: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("先填一个高德 Key（免费）")
                .font(DSToken.body(15, weight: .bold))
                .foregroundStyle(DSToken.ink)
            Text("① 打开 lbs.amap.com 注册 → 控制台 → 创建应用\n② 新增 Key，服务平台选「Web 服务」\n③ 把 Key 粘贴到下面（只存本机）")
                .font(DSToken.body(12.5))
                .foregroundStyle(DSToken.ink2)
                .lineSpacing(5)
            HStack(spacing: 10) {
                TextField("粘贴 32 位 Key", text: $keyInput)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(DSToken.body(14))
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.95)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(DSToken.line, lineWidth: 1))
                Button {
                    PoiService.saveKey(keyInput)
                    onToast(PoiService.savedKey.isEmpty ? "Key 不能为空" : "Key 已保存 · 开始搜周边")
                } label: {
                    Text("保存")
                        .font(DSToken.body(13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 42)
                        .background(Capsule().fill(DSToken.m3))
                }
                .buttonStyle(.plain)
            }
            Text("✎ Key 只存本机 UserDefaults · 搜索结果仅展示不入库")
                .font(DSToken.body(10.5))
                .foregroundStyle(DSToken.ink3)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                .fill(DSToken.m3.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                .strokeBorder(DSToken.m3.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [7, 5]))
        )
        .padding(.top, 22)
    }

    // MARK: 搜索区

    private var searchArea: some View {
        VStack(spacing: 0) {
            // 关键词 chips
            HStack(spacing: 8) {
                ForEach(keywords, id: \.self) { k in
                    Text(k)
                        .font(DSToken.body(12.5, weight: k == keyword ? .semibold : .regular))
                        .foregroundStyle(k == keyword ? DSToken.m3 : DSToken.ink2)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white))
                        .overlay(
                            Capsule().strokeBorder(
                                k == keyword ? DSToken.m3.opacity(0.55) : DSToken.line, lineWidth: 1
                            )
                        )
                        .onTapGesture {
                            keyword = k
                            Task { await search() }
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 18)

            HStack(spacing: 10) {
                Button(action: { Task { await search() } }) {
                    HStack(spacing: 7) {
                        if searching { ProgressView().tint(.white) }
                        else { Image(systemName: "location.fill").font(.system(size: 12)) }
                        Text(searching ? "搜索中…" : (locating ? "定位中…" : "搜周边"))
                            .font(DSToken.body(14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [DSToken.m3.mixedWithWhite(0.25), DSToken.m3]),
                                    startPoint: .top, endPoint: UnitPoint(x: 0.33, y: 1)
                                )
                            )
                    )
                    .shadow(color: DSToken.m3.opacity(0.3), radius: 10, y: 7)
                }
                .buttonStyle(.plain)
                .disabled(searching || locating)
                if !locationText.isEmpty {
                    Text(locationText)
                        .font(DSToken.body(11))
                        .foregroundStyle(DSToken.ink3)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.top, 14)

            // 结果列表
            VStack(spacing: 8) {
                if pois.isEmpty && !searching {
                    Text("点「搜周边」看看附近有什么\n（模拟器：Features → Location → 自定位置）")
                        .font(DSToken.body(12.5))
                        .foregroundStyle(DSToken.ink3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
                ForEach(pois) { p in
                    poiRow(p)
                }
            }
            .padding(.top, 14)
        }
    }

    private func poiRow(_ p: Poi) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(p.name)
                    .font(DSToken.body(13.5, weight: .semibold))
                    .foregroundStyle(DSToken.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(p.type)
                        .font(DSToken.body(10))
                        .foregroundStyle(DSToken.m3)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(DSToken.m3.opacity(0.10)))
                    Text(p.address.isEmpty ? "地址见高德" : p.address)
                        .font(DSToken.body(10.5))
                        .foregroundStyle(DSToken.ink3)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            Text(p.distanceText)
                .font(DSToken.num(11, weight: .semibold))
                .foregroundStyle(DSToken.ink2)
            Button {
                collect(p)
            } label: {
                Text("收")
                    .font(DSToken.body(12, weight: .bold))
                    .foregroundStyle(DSToken.m3)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(DSToken.m3.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.white.opacity(0.88)))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(DSToken.line.opacity(0.6), lineWidth: 1))
    }

    // MARK: 动作

    private func search() async {
        locating = true
        let loc = await locOnce.requestOnce()
        locating = false
        guard let loc else {
            onToast("定位不可用 · 模拟器请在 Features → Location 选一个位置")
            return
        }
        locationText = String(format: "%.4f, %.4f", loc.coordinate.longitude, loc.coordinate.latitude)
        searching = true
        defer { searching = false }
        do {
            pois = try await PoiService.search(
                lng: loc.coordinate.longitude, lat: loc.coordinate.latitude, keywords: keyword
            )
            onToast(pois.isEmpty ? "周边没找到 \(keyword) 店" : "找到 \(pois.count) 家 \(keyword)")
        } catch PoiError.noKey {
            onToast("Key 失效了 · 重新填一下")
        } catch PoiError.api(let info) {
            onToast("高德说：\(info)")
        } catch {
            onToast("搜索失败 · 稍后再试")
        }
    }

    /// 收进生活情报（FeedItem · 去重同名）
    private func collect(_ p: Poi) {
        guard !feeds.contains(where: { $0.title == p.name }) else {
            onToast("「\(p.name)」已经在情报里了")
            return
        }
        modelContext.insert(FeedItem(
            tag: "附近",
            title: p.name,
            sub: "\(p.type) · \(p.distanceText)",
            source: "附近好店",
            time: "今天",
            tags: ["附近", p.type],
            fav: false,
            inFeed: true,
            paragraphs: [p.address.isEmpty ? "高德周边搜索收录 · 详见高德地图。" : "地址：\(p.address)",
                         "来自「附近好店」，\(p.distanceText) 范围内。"]
        ))
        onToast("已收进情报 · \(p.name)")
    }
}

// MARK: 定位一次性封装（CLLocationManager delegate → async）

final class LocationOnce: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
    }

    func requestOnce() async -> CLLocation? {
        await withCheckedContinuation { c in
            continuation = c
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                continuation = nil
                c.resume(returning: nil)
            }
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.first)
        continuation = nil
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        if m.authorizationStatus == .authorizedWhenInUse || m.authorizationStatus == .authorizedAlways {
            m.requestLocation()
        }
    }
}
