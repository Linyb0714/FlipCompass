import Foundation
import SwiftData

// MARK: - M4 益智小游戏
/// 含 snapshot JSON 盘面态（R8 游戏切走自动存、回来续玩）
@Model
final class GameProgress {
    @Attribute(.unique) var id: UUID
    var gameKey: String             // klotski / maze / 2048 / oneline
    var bestScore: Int
    var totalPlays: Int
    var lastSnapshotJSON: String?   // 盘面态序列化
    var lastPlayedAt: Date
    var dailySeed: Int?             // 每日随机种子

    init(id: UUID = UUID(), gameKey: String, bestScore: Int = 0,
         totalPlays: Int = 0, lastSnapshotJSON: String? = nil,
         lastPlayedAt: Date = .now, dailySeed: Int? = nil) {
        self.id = id
        self.gameKey = gameKey
        self.bestScore = bestScore
        self.totalPlays = totalPlays
        self.lastSnapshotJSON = lastSnapshotJSON
        self.lastPlayedAt = lastPlayedAt
        self.dailySeed = dailySeed
    }
}

/// V0.4.4 单局战绩记录
@Model
final class GameRecord {
    @Attribute(.unique) var id: UUID
    var gameKey: String
    var score: Int
    var stars: Int                  // 0-3
    var durationSec: Int
    var playedAt: Date

    init(id: UUID = UUID(), gameKey: String, score: Int, stars: Int = 0,
         durationSec: Int = 0, playedAt: Date = .now) {
        self.id = id
        self.gameKey = gameKey
        self.score = score
        self.stars = stars
        self.durationSec = durationSec
        self.playedAt = playedAt
    }
}

/// V0.4.4 勋章（d12 勋章详情）
@Model
final class GameBadge {
    @Attribute(.unique) var id: UUID
    var key: String                 // 唯一键 first_win / streak7 / master2048
    var title: String
    var detail: String              // 解锁条件描述
    var unlockedAt: Date?
    var progress: Int               // 当前进度
    var target: Int                 // 解锁目标值

    init(id: UUID = UUID(), key: String, title: String, detail: String,
         unlockedAt: Date? = nil, progress: Int = 0, target: Int = 1) {
        self.id = id
        self.key = key
        self.title = title
        self.detail = detail
        self.unlockedAt = unlockedAt
        self.progress = progress
        self.target = target
    }

    var isUnlocked: Bool { unlockedAt != nil || progress >= target }
}

/// V0.4.4 设置项（d13 设置）
@Model
final class GameSettings {
    @Attribute(.unique) var id: UUID
    var soundOn: Bool
    var hapticOn: Bool
    var timerOn: Bool

    init(id: UUID = UUID(), soundOn: Bool = true, hapticOn: Bool = true, timerOn: Bool = true) {
        self.id = id
        self.soundOn = soundOn
        self.hapticOn = hapticOn
        self.timerOn = timerOn
    }
}
