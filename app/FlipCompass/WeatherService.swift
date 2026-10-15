import Foundation
import CoreLocation

// MARK: - 待机屏天气服务（真机数据 · 零依赖方案）
//
// 背景：免费个人团队无法启用 WeatherKit entitlement（需付费开发者账号注册），
// 方案改用系统组合：CLLocation + CLGeocoder + Open-Meteo（免费无 key API）：
//   ① CLLocationManager（whenInUse）取坐标
//   ② CLGeocoder 反地理编码 → 城市名（末尾「市」去除：福州市 → 福州）
//   ③ Open-Meteo current_weather → 温度 + WMO code → 中文天气 + 文本符号
// 刷新（原型 V0.2.5 注释设计）：app 打开 + 前台每 15 分钟；内部节流防重复请求。
// 降级：无授权 / 无网 / 任一步失败 → failed = true → 待机屏隐藏天气行（不回退假数据）。

@MainActor
final class WeatherService: NSObject, ObservableObject {

    struct Info: Equatable {
        let city: String        // 福州
        let icon: String        // ☀︎
        let condition: String   // 晴
        let temperature: String // 26°
    }

    @Published private(set) var info: Info?
    @Published private(set) var failed = false

    private let lm = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastFetchAt: Date?

    /// 刷新节流窗口（秒）；15 分钟
    var throttleInterval: TimeInterval = 15 * 60

    override init() {
        super.init()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// 前台启动 / 15min 定时触发；内部节流（已有数据且未到期则跳过）
    func refresh() {
        if let last = lastFetchAt,
           Date().timeIntervalSince(last) < throttleInterval,
           info != nil { return }
        switch lm.authorizationStatus {
        case .notDetermined:
            lm.requestWhenInUseAuthorization()   // 授权回调（didChangeAuthorization）里继续
        case .authorizedWhenInUse, .authorizedAlways:
            beginFetch()
        default:
            failed = true                        // 拒绝 / 受限
        }
    }

    private func beginFetch() {
        failed = false
        info = nil                               // 清旧值 → 加载态
        lm.requestLocation()
    }

    private func complete(_ location: CLLocation) async {
        lastFetchAt = Date()
        do {
            let city = try await resolveCity(location)
            let w = try await fetchWeather(
                lat: location.coordinate.latitude,
                lon: location.coordinate.longitude
            )
            let (icon, cond) = Self.wmoMapping(w.code)
            info = Info(city: city, icon: icon, condition: cond,
                        temperature: Self.tempText(w.temp))
        } catch {
            failed = true
        }
    }

    // MARK: - 子步骤

    private func resolveCity(_ location: CLLocation) async throws -> String {
        let marks = try await geocoder.reverseGeocodeLocation(location)
        guard let pm = marks.first else { throw URLError(.cannotParseResponse) }
        let raw = pm.locality ?? pm.administrativeArea ?? pm.name ?? "当前位置"
        return Self.cityDisplay(raw)
    }

    private func fetchWeather(lat: Double, lon: Double) async throws -> (temp: Double, code: Int) {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", lat)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", lon)),
            URLQueryItem(name: "current_weather", value: "true"),
        ]
        guard let url = comps.url else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        struct R: Decodable {
            struct CW: Decodable {
                let temperature: Double
                let weathercode: Int
            }
            let current_weather: CW
        }
        let r = try JSONDecoder().decode(R.self, from: data)
        return (r.current_weather.temperature, r.current_weather.weathercode)
    }

    // MARK: - 纯函数（单测覆盖）

    /// 城市名显示优化：去掉行政区划后缀「市」（福州市 → 福州；北京市 → 北京）
    nonisolated static func cityDisplay(_ raw: String) -> String {
        guard raw.hasSuffix("市"), raw.count > 2 else { return raw }
        return String(raw.dropLast())
    }

    /// WMO weather code →（文本符号, 中文）；Open-Meteo 标准编码
    nonisolated static func wmoMapping(_ code: Int) -> (icon: String, condition: String) {
        switch code {
        case 0:          return ("☀︎", "晴")
        case 1, 2:       return ("⛅︎", "多云")
        case 3:          return ("☁︎", "阴")
        case 45, 48:     return ("🌫", "雾")
        case 51...57:    return ("🌦", "毛毛雨")
        case 61, 63:     return ("🌧", "雨")
        case 65...67:    return ("🌧", "大雨")
        case 71...77, 85, 86: return ("❄︎", "雪")
        case 80...82:    return ("🌧", "阵雨")
        case 95...99:    return ("⛈", "雷阵雨")
        default:         return ("☁︎", "多云")
        }
    }

    nonisolated static func tempText(_ t: Double) -> String {
        "\(Int(t.rounded()))°"
    }
}

// MARK: - CLLocationManagerDelegate（回调主队列；显式跳回 MainActor）

extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.info == nil, !self.failed { self.beginFetch() }
            case .denied, .restricted:
                self.failed = true
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in await self.complete(loc) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.failed = true }
    }
}
