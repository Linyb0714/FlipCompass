import Foundation

// MARK: - 高德周边搜索服务（C5+ 方案④：附近好店）
//
// 「生活情报站 · 附近好店」数据源：高德 Web 服务 API 周边搜索。
// Key 由用户在页内填写（个人开发者免费申请：lbs.amap.com → 控制台 → 应用 → Key，
// 服务平台选「Web 服务」），存 UserDefaults；无 Key 时页内给申请引导，不崩溃。
// 返回门店名/类别/地址/距离，可一键收进生活情报（FeedItem）。

struct Poi: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let type: String
    let address: String
    let distance: Int        // 米（高德返回）
    var distanceText: String {
        distance >= 1000 ? String(format: "%.1fkm", Double(distance) / 1000) : "\(distance)m"
    }
}

enum PoiError: Error {
    case noKey, badUrl, http, api(String)
}

enum PoiService {

    static let keyStoreKey = "m3.amap.key"

    static var savedKey: String {
        UserDefaults.standard.string(forKey: keyStoreKey) ?? ""
    }

    static func saveKey(_ k: String) {
        UserDefaults.standard.set(k.trimmingCharacters(in: .whitespaces), forKey: keyStoreKey)
    }

    /// 周边搜索（高德 v3/place/around；keywords 空则全类目）
    static func search(lng: Double, lat: Double, keywords: String,
                       radius: Int = 1000, offset: Int = 20) async throws -> [Poi] {
        let key = savedKey
        guard !key.isEmpty else { throw PoiError.noKey }
        var comps = URLComponents(string: "https://restapi.amap.com/v3/place/around")
        comps?.queryItems = [
            .init(name: "key", value: key),
            .init(name: "location", value: String(format: "%.6f,%.6f", lng, lat)),
            .init(name: "keywords", value: keywords.isEmpty ? "美食" : keywords),
            .init(name: "radius", value: "\(radius)"),
            .init(name: "offset", value: "\(offset)"),
            .init(name: "page", value: "1"),
            .init(name: "extensions", value: "base"),
            .init(name: "output", value: "json"),
        ]
        guard let url = comps?.url else { throw PoiError.badUrl }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw PoiError.http }

        // 解析（手写 JSONSerialization：条目字段少，不值得引模型层）
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = obj["status"] as? String else { throw PoiError.http }
        guard status == "1" else {
            let info = (obj["info"] as? String) ?? "高德接口错误"
            throw PoiError.api(info)
        }
        let pois = (obj["pois"] as? [[String: Any]]) ?? []
        return pois.compactMap { p in
            let name = p["name"] as? String ?? ""
            guard !name.isEmpty else { return nil }
            let type = ((p["type"] as? String) ?? "")
                .split(separator: ";").first.map(String.init) ?? "门店"
            let address = p["address"] as? String ?? ""
            let distance = Int(p["distance"] as? String ?? "0") ?? 0
            return Poi(name: name, type: type, address: address, distance: distance)
        }
    }
}
