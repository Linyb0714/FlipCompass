import XCTest
@testable import FlipCompass

/// YAML DSL 解析器测试（T2 渲染管线第一步）
final class DSLParserTests: XCTestCase {

    func testParseManifest() throws {
        let yaml = """
        moduleKey: m1_checkin
        displayName: 温情打卡
        version: "0.4.1"
        pages:
          - list
          - detail
          - edit
        network:
          endpoint: null
          note: 一期未启用
        """
        let manifest = try DSLParser.parseManifest(yaml: yaml)
        XCTAssertEqual(manifest.moduleKey, "m1_checkin")
        XCTAssertEqual(manifest.displayName, "温情打卡")
        XCTAssertEqual(manifest.pages, ["list", "detail", "edit"])
        XCTAssertNotNil(manifest.network)
    }

    func testParseSimplePage() throws {
        let yaml = """
        key: list
        bind:
          items: $provider.checkin.todayItems
        layout:
          type: vstack
          children:
            - type: text
              value: 标题
              style:
                font: headline
                color: orange
            - type: button
              label: 保存
              action:
                type: submit
                form: checkin
        onTap:
          type: navigate
          pageKey: detail
          payload: {}
        """
        let page = try DSLParser.parsePage(yaml: yaml)
        XCTAssertEqual(page.key, "list")
        XCTAssertEqual(page.bind?["items"], "$provider.checkin.todayItems")
        // 验证 layout 解码正确
        if case .vstack(let children, _) = page.layout {
            XCTAssertEqual(children.count, 2)
        } else { XCTFail("layout 应为 vstack") }
        // 验证子组件
        if case .vstack(let children, _) = page.layout {
            if case .text(let v, _) = children[0] {
                XCTAssertEqual(v, "标题")
            } else { XCTFail("第一个子组件应为 text") }
        }
        // onTap 是 navigate
        if case .navigate(let key, _) = page.onTap {
            XCTAssertEqual(key, "detail")
        } else if page.onTap == nil {
            XCTFail("onTap 不应为 nil")
        }
    }

    func testUnknownComponentThrows() {
        let yaml = """
        key: bad
        layout:
          type: unknown-component
          value: hello
        """
        XCTAssertThrowsError(try DSLParser.parsePage(yaml: yaml)) { error in
            guard case DSLParser.ParseError.irDecode = error else {
                return XCTFail("应为 irDecode 错误，实际：\(error)")
            }
        }
    }

    func testActionWhitelistRejectsUnknown() {
        let yaml = """
        key: bad
        layout:
          type: button
          label: 攻击
          action:
            type: execute-arbitrary-code
            script: rm -rf /
        """
        XCTAssertThrowsError(try DSLParser.parsePage(yaml: yaml)) { error in
            guard case DSLParser.ParseError.irDecode = error else {
                return XCTFail("非白名单动作应被反序列化拒绝，实际：\(error)")
            }
        }
    }

    func testParseListAndGrid() throws {
        let yaml = """
        key: grid-page
        layout:
          type: grid
          cols: 2
          items: $provider.hub.feeds
          template:
            type: text
            value: ${item.title}
        """
        let page = try DSLParser.parsePage(yaml: yaml)
        if case .grid(let cols, _, _) = page.layout {
            XCTAssertEqual(cols, 2)
        } else { XCTFail("layout 应为 grid") }
    }

    func testParseCalendarHeatmap() throws {
        let yaml = """
        key: stats
        layout:
          type: calendar-heatmap
          field: $provider.checkin.heatmap
        """
        let page = try DSLParser.parsePage(yaml: yaml)
        if case .calendarHeatmap(let field) = page.layout {
            XCTAssertEqual(field, "$provider.checkin.heatmap")
        } else { XCTFail("应为 calendar-heatmap 组件") }
    }

    func testParsePagesBundle() throws {
        let bundle = [
            "list": "key: list\nlayout:\n  type: text\n  value: a",
            "detail": "key: detail\nlayout:\n  type: text\n  value: b",
        ]
        let pages = try DSLParser.parsePagesBundle(yamls: bundle)
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages["list"]?.key, "list")
    }
}
