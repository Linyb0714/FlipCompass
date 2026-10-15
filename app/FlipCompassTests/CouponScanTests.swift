import XCTest
@testable import FlipCompass

// MARK: - C5+ 数据源四路解析测试（截图 OCR 解析器 / RSS XML 解析）

final class CouponScanTests: XCTestCase {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }
    private var now: Date { cal.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 12))! }

    /// 美团券面典型 OCR 输出：平台名行 / 券名 / 门槛 / 日期区间 / 门店
    func testParse_美团券面全要素() {
        let raw = """
        美团券
        奶茶买一送一
        单笔满20元可用
        10-13 至 10-16
        楼下那家·万象店
        """
        let d = CouponScan.parse(raw, now: now, cal: cal)
        XCTAssertEqual(d.title, "奶茶买一送一")          // 平台名行被跳过
        XCTAssertEqual(d.value, "买一送一")
        XCTAssertEqual(d.threshold, "单笔满20元可用")
        XCTAssertEqual(d.valid, "10-13 至 10-16")
        XCTAssertEqual(d.daysLeft, 2)                    // 10-14 → 10-16
        XCTAssertEqual(d.shops, ["楼下那家·万象店"])
    }

    /// 相对有效期 + 无门槛 + 立减面额
    func testParse_相对天数与立减() {
        let raw = """
        咖啡立减8元
        无门槛
        3天内有效
        街角咖啡：中山路店
        """
        let d = CouponScan.parse(raw, now: now, cal: cal)
        XCTAssertEqual(d.title, "咖啡立减8元")
        XCTAssertEqual(d.value, "立减8")
        XCTAssertEqual(d.threshold, "无门槛 · 单笔可用")
        XCTAssertEqual(d.valid, "3 天内有效")
        XCTAssertEqual(d.daysLeft, 3)
        XCTAssertEqual(d.shops, ["街角咖啡：中山路店".replacingOccurrences(of: "门店", with: "")])
    }

    /// 已过期的日期区间 → 0 天（跨年保护不触发时）
    func testParse_过期区间归零() {
        let raw = "面包券\n第二件半价\n09-01 至 10-01\n万达店"
        let d = CouponScan.parse(raw, now: now, cal: cal)
        XCTAssertEqual(d.value, "第二件半价")
        XCTAssertEqual(d.daysLeft, 0)
    }

    /// 表单反推：改了有效期字段后剩余天数联动
    func testDaysLeft_按有效期字段推算() {
        XCTAssertEqual(CouponScan.daysLeft(valid: "10-20", now: now, cal: cal), 6)
        XCTAssertEqual(CouponScan.daysLeft(valid: "10-13 至 10-16", now: now, cal: cal), 2)
        XCTAssertEqual(CouponScan.daysLeft(valid: "看不懂的格式", now: now, cal: cal), 7)  // 兜底
    }
}

final class RssServiceTests: XCTestCase {

    /// RSS 2.0（RSS 链接在 <link> 文本节点）
    func testParse_RSS2() {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0"><channel><title>测试源</title>
        <item><title>周末爬山路线</title><link>https://example.com/1</link><description>带娃爬山攻略</description><pubDate>Wed, 14 Oct 2026 08:00:00 GMT</pubDate></item>
        <item><title>糖水铺地图</title><link>https://example.com/2</link><description>六家糖水铺</description><pubDate>Wed, 14 Oct 2026 09:30:00 GMT</pubDate></item>
        </channel></rss>
        """
        let items = RssService.parse(data: Data(xml.utf8))
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "周末爬山路线")
        XCTAssertEqual(items[0].link, "https://example.com/1")
        XCTAssertEqual(items[1].title, "糖水铺地图")
        XCTAssertNotNil(items[0].pubDate)
    }

    /// Atom（链接在 href 属性 · summary → description）
    func testParse_Atom() {
        let xml = """
        <?xml version="1.0"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
        <entry><title type="html">少数派更新</title><link rel="alternate" href="https://sspai.com/x"/><summary>好文章</summary><updated>2026-10-14T10:00:00Z</updated></entry>
        </feed>
        """
        let items = RssService.parse(data: Data(xml.utf8))
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "少数派更新")
        XCTAssertEqual(items[0].link, "https://sspai.com/x")
        XCTAssertEqual(items[0].description, "好文章")
        XCTAssertNotNil(items[0].pubDate)
    }

    func testStripHtml() {
        let s = "<p>第一段&nbsp;内容</p><a href=\"x\">链接</a>"
        let out = RssService.stripHtml(s)
        XCTAssertEqual(out, "第一段 内容链接")
    }
}
