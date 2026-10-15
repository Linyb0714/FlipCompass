import Foundation

// MARK: - 券面截图 OCR 文本解析器（C5+ 方案①：截图 OCR 录券）
//
// 输入 Vision 识别出的多行文本（美团/抖音/点评券面截图），启发式提取：
// 券名（首个短行/含「券」行）· 面额（买一送一/半价/折/减 N）· 门槛（满 N 元/无门槛）·
// 有效期（MM-dd 至 MM-dd / 有效期至 / N 天内）· 门店（含地址特征的短行）。
// 纯函数无依赖 → 可单测；识别不准时表单内可手工修正。

struct CouponDraft {
    var title = ""
    var value = ""
    var threshold = ""
    var valid = ""
    var daysLeft = 7
    var shops: [String] = []
}

enum CouponScan {

    /// 解析 OCR 多行文本 → 券草稿（未识别字段留空，由表单兜底）
    static func parse(_ raw: String, now: Date = Date(), cal: Calendar = .current) -> CouponDraft {
        var d = CouponDraft()
        let lines = raw
            .split(whereSeparator: { $0 == "\n" || $0 == "\r" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // —— 面额：从全文找首个面额特征短语 ——
        d.value = extractValue(lines) ?? ""

        // —— 门槛：满 N 元可用 / 无门槛 ——
        d.threshold = extractThreshold(lines) ?? "到店核销 · 不与其他优惠同享"

        // —— 有效期 + 剩余天数 ——
        let (valid, days) = extractValidity(lines, now: now, cal: cal)
        d.valid = valid
        d.daysLeft = days

        // —— 门店：含地址特征的短行（最多 3 家）——
        d.shops = extractShops(lines)

        // —— 券名：首个非元信息短行（面额/门槛/日期行跳过）——
        d.title = extractTitle(lines) ?? "截图导入的券"

        // 面额兜底：短券名本身就是面额（如「奶茶第二杯半价」）
        if d.value.isEmpty, d.title.count <= 12 {
            d.value = d.title
        }
        return d
    }

    // MARK: 提取子规则

    /// 面额短语（按优先级：固定优惠词 → 折扣 → 立减/减 N → 金额）
    private static func extractValue(_ lines: [String]) -> String? {
        let fixed = ["买一送一", "第二件半价", "2件半价", "第二杯半价", "半价", "免费领取", "免费"]
        for l in lines {
            for w in fixed where l.contains(w) { return w }
        }
        let patterns = [
            #"买(\d+)送(\d+)"#, #"\d+(\.\d+)?折"#, #"立减\d+(\.\d+)?"#, #"[减满]\d+(\.\d+)?元?"#,
        ]
        for p in patterns {
            if let m = firstMatch(pattern: p, in: lines) { return m }
        }
        return nil
    }

    /// 门槛行（「满 20 元可用」「单笔满 N」「无门槛」→ 取整行）
    private static func extractThreshold(_ lines: [String]) -> String? {
        for l in lines {
            if l.range(of: #"无门槛"#) != nil { return "无门槛 · 单笔可用" }
            if l.range(of: #"(单笔|订单|首单)?满\s?\d+(\.\d+)?\s?元??(可用|起|即可|起用)?"#, options: .regularExpression) != nil,
               l.contains("满") {
                return l
            }
        }
        return nil
    }

    /// 有效期：区间（MM-dd 至 MM-dd / M月d日 至 M月d日）→ 单点（有效期至 MM-dd）→ 相对（N 天内有效）
    static func extractValidity(_ lines: [String], now: Date, cal: Calendar) -> (String, Int) {
        // 区间：MM-dd 至 MM-dd（年份按当前年，结束早于今天超 90 天视为跨年）
        if let m = firstMatch(pattern: #"(\d{1,2})[-月](\d{1,2})[日]?\s*[至到~－-]\s*(\d{1,2})[-月](\d{1,2})[日]?"#, in: lines),
           let range = matchNumbers(m) {
            let days = daysLeft(from: range.end, now: now, cal: cal)
            return ("\(range.start) 至 \(range.end)", max(days, 0))
        }
        // 单点：有效期至 / 有效日期 MM-dd
        if let m = firstMatch(pattern: #"(?:有效期)?[至到]?\s*[:：]?\s*(\d{1,2})[-月](\d{1,2})[日]?"#, in: lines),
           let end = singleDate(m) {
            let days = daysLeft(from: end, now: now, cal: cal)
            return ("至 \(end)", max(days, 0))
        }
        // 相对：N 天内有效
        if let m = firstMatch(pattern: #"(\d+)\s*天(内|有效期|内有效)"#, in: lines),
           let n = Int(m.prefix { $0.isNumber }) {
            return ("\(n) 天内有效", n)
        }
        return ("", 7)
    }

    /// 门店：含「店/广场/路/街/大道/中心」的短行（去前缀符号；冒号右侧优先）
    private static func extractShops(_ lines: [String]) -> [String] {
        var out: [String] = []
        for l in lines where 3 < l.count && l.count < 40 {
            if l.contains("店") || l.contains("广场") || l.contains("路") || l.contains("街") || l.contains("大道") {
                var clean = l.replacingOccurrences(of: "门店", with: "")
                if clean.hasPrefix("：") || clean.hasPrefix(":") { clean = String(clean.dropFirst()) }
                let trimmed = clean.trimmingCharacters(in: CharacterSet(charactersIn: "· 　0123456789"))
                if !trimmed.isEmpty, trimmed.count >= 2 { out.append(trimmed) }
            }
            if out.count >= 3 { break }
        }
        return out
    }

    /// 券名：首个 ≤16 字、非面额/门槛/日期/规则/门店/平台名的行
    private static func extractTitle(_ lines: [String]) -> String? {
        let startsMeta = ["有效期", "满", "单笔", "订单", "规则", "说明", "适用", "门店", "使用",
                          "领取", "兑换", "券码", "编号", "无门槛", "到店", "地址"]
        let platforms = ["美团", "大众点评", "抖音", "饿了么", "美团券", "大众点评券", "抖音券"]
        for l in lines where l.count <= 16 {
            if l.range(of: #"^\d+(\.\d+)?(元|折|天)"#, options: .regularExpression) != nil { continue }
            if platforms.contains(l) { continue }                      // 平台名行（首行常见）
            if startsMeta.contains(where: l.hasPrefix) { continue }     // 元信息行
            return l
        }
        return nil
    }

    // MARK: 小工具

    private static func firstMatch(pattern: String, in lines: [String]) -> String? {
        let re = try? NSRegularExpression(pattern: pattern)
        for l in lines {
            if let m = re?.firstMatch(in: l, range: NSRange(l.startIndex..., in: l)) {
                if let r = Range(m.range, in: l) { return String(l[r]) }
            }
        }
        return nil
    }

    /// 「MM-dd 至 MM-dd」数字组 → 起止字符串
    private static func matchNumbers(_ s: String) -> (start: String, end: String)? {
        let re = try? NSRegularExpression(pattern: #"(\d{1,2})[-月](\d{1,2})[日]?\s*[至到~－-]\s*(\d{1,2})[-月](\d{1,2})"#)
        guard let m = re?.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let r = Range(m.range, in: s),
              m.numberOfRanges >= 5 else { return nil }
        func grp(_ i: Int) -> Int? {
            guard let rr = Range(m.range(at: i), in: s) else { return nil }
            return Int(s[rr])
        }
        guard let m1 = grp(1), let d1 = grp(2), let m2 = grp(3), let d2 = grp(4) else { return nil }
        return ("\(String(format: "%02d", m1))-\(String(format: "%02d", d1))",
                "\(String(format: "%02d", m2))-\(String(format: "%02d", d2))")
    }

    /// 单日期「MM-dd」格式化
    private static func singleDate(_ s: String) -> String? {
        let re = try? NSRegularExpression(pattern: #"(\d{1,2})[-月](\d{1,2})[日]?"#)
        guard let m = re?.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let r = Range(m.range, in: s) else { return nil }
        return String(s[r])
    }

    /// 结束日距今天数（按当前年；早于今天超 90 天 → 跨年 +1）
    private static func daysLeft(from mmdd: String, now: Date, cal: Calendar) -> Int {
        let parts = mmdd.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return 7 }
        let year = cal.component(.year, from: now)
        guard let end = cal.date(from: DateComponents(year: year, month: parts[0], day: parts[1])) else { return 7 }
        let finalEnd: Date
        if end < cal.startOfDay(for: now) - 90 * 86400 {
            finalEnd = cal.date(byAdding: .year, value: 1, to: end) ?? end
        } else {
            finalEnd = end
        }
        return cal.dateComponents([.day], from: cal.startOfDay(for: now), to: finalEnd).day ?? 7
    }
}
