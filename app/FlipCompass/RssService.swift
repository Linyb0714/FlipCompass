import Foundation
import SwiftData

// MARK: - RSS/Atom 情报订阅服务（C5+ 方案③）
//
// 生活情报站的「自己想要的推荐」来源之一：订阅公开 RSS/Atom 源，
// 拉取条目 → 转成 FeedItem 混入 p0 今日推送（source = 源名）。
// 解析纯函数（给定 XML 字符串）可单测；网络拉取失败静默降级不打断 UI。

struct RssItem: Equatable {
    let title: String
    let link: String
    let description: String
    let pubDate: Date?
}

enum RssService {

    // MARK: XML 解析（RSS 2.0 <item> / Atom <entry> 双格式）

    /// 纯解析：给定 RSS/Atom 文档 → 条目数组（无网络依赖，可单测）
    static func parse(data: Data) -> [RssItem] {
        let delegate = RssParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.items
    }

    // MARK: 网络拉取

    static func fetch(urlString: String, timeout: TimeInterval = 12) async throws -> [RssItem] {
        guard let url = URL(string: urlString) else { throw RssError.badUrl }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw RssError.http }
        let items = parse(data: data)
        guard !items.isEmpty else { throw RssError.empty }
        return items
    }

    // MARK: 入库（去重：同标题不重复插）

    /// 拉取一个源 → 转成 FeedItem 入库；返回 (新增数, 跳过数)
    @discardableResult
    static func importItems(from source: RssSource,
                            into ctx: ModelContext,
                            existingTitles: [String]) async throws -> (inserted: Int, skipped: Int) {
        let items = try await fetch(urlString: source.url)
        var exist = Set(existingTitles)
        var inserted = 0, skipped = 0
        let cal = Calendar.current
        for it in items where !it.title.isEmpty {
            guard !exist.contains(it.title) else { skipped += 1; continue }
            let dateStr = it.pubDate.map { RssService.shortDate($0, cal: cal) } ?? "刚刚"
            ctx.insert(FeedItem(
                tag: "订阅",
                title: it.title,
                sub: "\(source.title) · \(dateStr)",
                source: source.title,
                time: dateStr,
                tags: ["订阅", source.title],
                fav: false,
                inFeed: true,
                paragraphs: [stripHtml(it.description)]
            ))
            exist.insert(it.title)
            inserted += 1
        }
        return (inserted, skipped)
    }

    static func shortDate(_ d: Date, cal: Calendar) -> String {
        let now = Date()
        if cal.isDate(d, inSameDayAs: now) { return "今天" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: now)).day ?? 0
        return days == 1 ? "昨天" : String(format: "%02d-%02d", cal.component(.month, from: d), cal.component(.day, from: d))
    }

    /// 剥 HTML 标签 → 纯文本段落
    static func stripHtml(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        out = out.replacingOccurrences(of: "&nbsp;", with: " ")
        out = out.replacingOccurrences(of: "&amp;", with: "&")
        out = out.replacingOccurrences(of: "&lt;", with: "<")
        out = out.replacingOccurrences(of: "&gt;", with: ">")
        out = out.replacingOccurrences(of: "&quot;", with: "\"")
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum RssError: Error {
    case badUrl, http, empty
}

// MARK: - XMLParser 委托（RSS <item> 与 Atom <entry> 通用）

private final class RssParserDelegate: NSObject, XMLParserDelegate {
    var items: [RssItem] = []

    private var inEntry = false
    private var currentTag = ""
    private var buf = ""
    private var title = "", link = "", desc = ""
    private var pubDate: Date?

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        let tag = name.lowercased()
        if tag == "item" || tag == "entry" {
            inEntry = true
            title = ""; link = ""; desc = ""; pubDate = nil
        }
        // Atom 链接在属性上（rel="alternate"）
        if inEntry && tag == "link" {
            let href = attributes["href"]
            if let href, !href.isEmpty, attributes["rel"] != "self" { link = href }
            else if href == nil, attributes.isEmpty { currentTag = "link" }
        }
        if inEntry && ["title", "description", "summary", "content", "pubdate", "published", "updated"].contains(tag) {
            currentTag = tag == "summary" || tag == "content" ? "description" : tag
            buf = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inEntry, !currentTag.isEmpty { buf += string }
        else if currentTag == "link", inEntry { link += string }   // RSS <link> 文本节点
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        let tag = name.lowercased()
        defer { buf = "" }
        // 只有结束标签与当前内容标签匹配才赋值（Atom 自闭合 <link rel=…/> 不清掉 title）
        if inEntry, tag == currentTag || (currentTag == "description" && ["summary", "content"] .contains(tag)) {
            switch currentTag {
            case "title": title = buf.trimmingCharacters(in: .whitespacesAndNewlines)
            case "description": if desc.isEmpty { desc = buf.trimmingCharacters(in: .whitespacesAndNewlines) }
            case "link": if link.isEmpty { link = buf.trimmingCharacters(in: .whitespacesAndNewlines) }
            case "pubdate", "published", "updated":
                if pubDate == nil { pubDate = parseDate(buf) }
            default: break
            }
        }
        if tag == "item" || tag == "entry" {
            inEntry = false
            currentTag = ""
            if !title.isEmpty {
                items.append(RssItem(title: title, link: link, description: desc, pubDate: pubDate))
            }
        }
    }

    private func parseDate(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // RFC 822（RSS：Tue, 15 Oct 2026 08:00:00 GMT）与 ISO 8601（Atom）
        let f822 = DateFormatter()
        f822.locale = Locale(identifier: "en_US_POSIX")
        f822.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        if let d = f822.date(from: trimmed) { return d }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: trimmed) { return d }
        return nil
    }
}
