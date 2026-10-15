import XCTest
@testable import FlipCompass

/// WeatherService 纯函数单测（WMO 映射 / 温度格式 / 城市名优化）
final class WeatherServiceTests: XCTestCase {

    func testWMOMapping() {
        XCTAssertEqual(WeatherService.wmoMapping(0).condition, "晴")
        XCTAssertEqual(WeatherService.wmoMapping(0).icon, "☀︎")
        XCTAssertEqual(WeatherService.wmoMapping(1).condition, "多云")
        XCTAssertEqual(WeatherService.wmoMapping(3).condition, "阴")
        XCTAssertEqual(WeatherService.wmoMapping(45).condition, "雾")
        XCTAssertEqual(WeatherService.wmoMapping(51).condition, "毛毛雨")
        XCTAssertEqual(WeatherService.wmoMapping(61).condition, "雨")
        XCTAssertEqual(WeatherService.wmoMapping(65).condition, "大雨")
        XCTAssertEqual(WeatherService.wmoMapping(71).condition, "雪")
        XCTAssertEqual(WeatherService.wmoMapping(80).condition, "阵雨")
        XCTAssertEqual(WeatherService.wmoMapping(95).condition, "雷阵雨")
        // 未知编码回退多云
        XCTAssertEqual(WeatherService.wmoMapping(42).condition, "多云")
    }

    func testTempText() {
        XCTAssertEqual(WeatherService.tempText(26.3), "26°")
        XCTAssertEqual(WeatherService.tempText(26.5), "27°")
        XCTAssertEqual(WeatherService.tempText(18.7), "19°")
        XCTAssertEqual(WeatherService.tempText(-2.4), "-2°")
    }

    func testCityDisplay() {
        XCTAssertEqual(WeatherService.cityDisplay("福州市"), "福州")
        XCTAssertEqual(WeatherService.cityDisplay("北京市"), "北京")
        XCTAssertEqual(WeatherService.cityDisplay("厦门市"), "厦门")
        // 少数名族地区/直辖市无「市」后缀或短名保持原样
        XCTAssertEqual(WeatherService.cityDisplay("呼和浩特市"), "呼和浩特")
        XCTAssertEqual(WeatherService.cityDisplay("北京市辖区"), "北京市辖区")   // 非末尾市不改
        XCTAssertEqual(WeatherService.cityDisplay("市"), "市")                  // 单字保护
        XCTAssertEqual(WeatherService.cityDisplay("深圳"), "深圳")
    }
}
