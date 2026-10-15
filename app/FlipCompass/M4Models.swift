import Foundation
import SwiftUI
import SwiftData

// MARK: - M4 数据模型（V0.4.4 架构：GameProgress 实体 + 游戏元信息/勋章静态表）
// 游戏本体（玩法/盘面 snapshot）后置；B4 一级页面 = 今日/清单/勋章墙，全部由 records 实算。

/// 逐局成绩（原型 M4.records；day = 当天零时，streak/勋章/胶囊的统计源）
@Model
final class GameProgress {
    @Attribute(.unique) var id: UUID
    /// 游戏 key（hrd / maze / g2048 / one）
    var gameKey: String
    /// 当天零时（按日聚合）
    var day: Date
    /// 本局时刻
    var playedAt: Date
    /// 成绩文案（"84 步" / "58s" / "1024"）
    var score: String
    /// 星级 0~3
    var stars: Int
    var createdAt: Date

    init(id: UUID = UUID(), gameKey: String, day: Date, playedAt: Date,
         score: String, stars: Int, createdAt: Date = Date()) {
        self.id = id
        self.gameKey = gameKey
        self.day = day
        self.playedAt = playedAt
        self.score = score
        self.stars = stars
        self.createdAt = createdAt
    }
}

// MARK: - 游戏元信息（静态四款 · 原型 M4.games；指标详情 d11 阶段细化）

struct GameMeta {
    let key: String
    let name: String
    /// 图标字（品 / ◉ / 2048 / 一）
    let glyph: String
    /// 图标渐变（145° 亮端 → 深端；原型 .gi-1~4）
    let iconTop: Color
    let iconBottom: Color
    let sub: String
    let stars: Int
    /// 继续游戏：关卡文本与成绩胶囊（原型 hero score-chips）
    let continueLevel: String
    let continueChips: [String]
}

// MARK: - 勋章定义（静态四枚 · 解锁条件实算）

struct BadgeDef {
    enum Kind { case plays, streak, maxstar }
    let id: String
    let name: String
    /// 勋章字（✓ / 7 / 棋 / ★；未解锁显示 ?）
    let glyph: String
    let desc: String
    let need: Int
    let kind: Kind
}

// MARK: - 静态表命名空间（游戏 / 勋章 · 不入库）

enum M4Static {
    static let games: [GameMeta] = [
        GameMeta(key: "hrd", name: "华容道", glyph: "品",
                 iconTop: Color(red: 1.0, green: 0.855, blue: 0.30),
                 iconBottom: DSToken.m4,
                 sub: "经典布局 12 式", stars: 3,
                 continueLevel: "经典第 9 式", continueChips: ["昨日 ★★★", "84 步"]),
        GameMeta(key: "maze", name: "迷宫滚球", glyph: "◉",
                 iconTop: Color(red: 0x5F / 255, green: 0xD8 / 255, blue: 0x78 / 255),
                 iconBottom: DSToken.m3,
                 sub: "倾斜手机操控 · 10 关", stars: 3,
                 continueLevel: "第 7 关", continueChips: ["昨日 ★★★", "用时 58s"]),
        GameMeta(key: "g2048", name: "2048", glyph: "2048",
                 iconTop: Color(red: 1.0, green: 0.68, blue: 0.30),
                 iconBottom: DSToken.m1,
                 sub: "合并到 1024 就很棒", stars: 1,
                 continueLevel: "续玩上盘", continueChips: ["最高 1024", "还差两步"]),
        GameMeta(key: "one", name: "一笔画", glyph: "一",
                 iconTop: Color(red: 0xC7 / 255, green: 0x7B / 255, blue: 0xF0 / 255),
                 iconBottom: DSToken.m2,
                 sub: "每日更新一图", stars: 2,
                 continueLevel: "今日一图", continueChips: ["昨日 1 笔", "已连 3 天"]),
    ]

    static let badges: [BadgeDef] = [
        BadgeDef(id: "b1", name: "初翻启程", glyph: "✓",
                 desc: "完成第一局游戏", need: 1, kind: .plays),
        BadgeDef(id: "b2", name: "七日之约", glyph: "7",
                 desc: "连续 7 天每天玩一局", need: 7, kind: .streak),
        BadgeDef(id: "b3", name: "棋逢对手", glyph: "棋",
                 desc: "累计游玩 30 局", need: 30, kind: .plays),
        BadgeDef(id: "b4", name: "满星玩家", glyph: "★",
                 desc: "任一游戏拿到 3 星", need: 3, kind: .maxstar),
    ]
}
