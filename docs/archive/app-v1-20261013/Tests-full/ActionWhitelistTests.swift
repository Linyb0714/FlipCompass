import XCTest
@testable import FlipCompass

/// 动作白名单闭合集测试（T2 安全模型）
final class ActionWhitelistTests: XCTestCase {

    func testAllAllowedActions() {
        XCTAssertTrue(ActionWhitelist.isAllowed("navigate"))
        XCTAssertTrue(ActionWhitelist.isAllowed("pop"))
        XCTAssertTrue(ActionWhitelist.isAllowed("submit"))
        XCTAssertTrue(ActionWhitelist.isAllowed("toggle"))
        XCTAssertTrue(ActionWhitelist.isAllowed("set-value"))
        XCTAssertTrue(ActionWhitelist.isAllowed("haptic"))
    }

    func testDisallowedActions() {
        XCTAssertFalse(ActionWhitelist.isAllowed("execute"))
        XCTAssertFalse(ActionWhitelist.isAllowed("network-request"))
        XCTAssertFalse(ActionWhitelist.isAllowed("file-write"))
        XCTAssertFalse(ActionWhitelist.isAllowed("shell"))
        XCTAssertFalse(ActionWhitelist.isAllowed("fetch-remote"))
    }

    func testNavigateValidationAgainstKnownPages() {
        let known: Set<String> = ["list", "detail", "edit"]
        XCTAssertTrue(ActionWhitelist.validateNavigate(pageKey: "detail", knownPages: known))
        XCTAssertFalse(ActionWhitelist.validateNavigate(pageKey: "exec", knownPages: known))
    }

    func testActionDescription() {
        XCTAssertEqual(ActionWhitelist.describe(.pop), "pop")
        XCTAssertEqual(ActionWhitelist.describe(.navigate(pageKey: "detail", payload: [:])),
                       "navigate → detail")
        XCTAssertTrue(ActionWhitelist.describe(.toggle(field: "x")).contains("toggle"))
    }

    func testClosedSetSize() {
        // 闭合集大小应恰好为 6（文档明确：navigate/pop/submit/toggle/setValue/haptic）
        XCTAssertEqual(ActionWhitelist.allowedActions.count, 6)
    }
}

/// IR 编码往返测试（DSL 编码 → 解码 → 一致）
final class DSLIRRoundTripTests: XCTestCase {
    func testTextRoundTrip() throws {
        let original = DSLLayout.text("标题", DSLTextStyle(font: "headline", color: "orange", weight: "semibold"))
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let restored = try decoder.decode(DSLLayout.self, from: data)
        XCTAssertEqual(original, restored)
    }

    func testButtonActionRoundTrip() throws {
        let original = DSLLayout.button(label: "保存", action: .submit(form: "checkin"))
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(DSLLayout.self, from: data)
        XCTAssertEqual(original, restored)
    }

    func testUnknownActionDecodeFails() {
        let json = #"{"type":"button","label":"x","action":{"type":"shell","cmd":"rm"}}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(DSLLayout.self, from: json))
    }
}
