//
//  VideoModels.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/21.
//

import Foundation
import UIKit

struct PlaylistCategory: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let sortOrder: Int
    let playlistIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case sortOrder = "sort_order"
        case playlistIDs = "playlist_ids"
    }
}


// レスポンス
enum VideoContentLanguage: String, Codable, CaseIterable {
    case ja
    case en

    var displayName: String {
        switch self {
            case .ja: return "🇯🇵 日本語"
            case .en: return "🇺🇸 英語"
        }
    }
}
// リストアイテム構造
struct VideoItem: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    var durationSeconds: Double? = nil
    var currentTime: Double? = nil
    var rate: Float = 1.0
    var playlistID: String?
    var categoryID: String = "listening"
    var aspectRatio: CGFloat
    var contentLanguage: VideoContentLanguage = .ja
    var thumbnailRefreshID: String = UUID().uuidString

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case durationSeconds = "duration_seconds"
        case currentTime = "current_time"
        case rate
        case playlistID = "playlist_id"
        case categoryID = "category_id"
        case aspectRatio = "aspect_ratio"
        case contentLanguage = "content_language"
    }
}

struct PracticeSessionPayload: Codable {
    let id: String
    let contentLanguage: VideoContentLanguage
    let practiceDate: String
    let startedAt: String
    let endedAt: String
    let durationSeconds: Int

    enum CodingKeys: String, CodingKey {
        case id
        case contentLanguage = "content_language"
        case practiceDate = "practice_date"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
    }
}


struct VideoSubtitleSkipWords: Decodable {
    let skipWithPreviousLines: [String]
    let skipWithNextLines: [String]
    var skipOnlyCurrentLine: [String]
}
