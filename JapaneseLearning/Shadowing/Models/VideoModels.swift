//
//  VideoModels.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/21.
//

import Foundation
import UIKit

enum PlaylistCategory: String, CaseIterable, Identifiable {
    case shadowing
    case `default`
    case drama

    var id: Self { self }

    var title: String {
        switch self {
            case .shadowing: return "シャドーイング"
            case .default: return "デフォルト"
            case .drama: return "ドラマシーン"
        }
    }

    var playlistID: String? {
        switch self {
            case .shadowing: return nil
            case .default: return "PLEC5UjKGbYI2TeWkpUE-RocpVhqXwwk-9"
            case .drama: return "PLEC5UjKGbYI0sAKuiEjWrH82PG_vxrLF0"
        }
    }
}


// レスポンス
struct PlaylistResponse: Decodable {
    let nextPageToken: String?
    let items: [PlaylistItem]
}
struct PlaylistItem: Decodable {
    let snippet: PlaylistSnippet
}
struct PlaylistSnippet: Decodable {
    let title: String
    let resourceId: ResourceId
    let thumbnails: Thumbnails? // 💡 非公開動画に対応するためオプショナルに変更
}
struct ResourceId: Decodable {
    let videoId: String?
}
struct Thumbnails: Decodable {
    let maxres: Thumbnail?
    let standard: Thumbnail?
    let high: Thumbnail?
    let medium: Thumbnail?
    let defaultThumbnail: Thumbnail?

    enum CodingKeys: String, CodingKey {
        case maxres
        case standard
        case high
        case medium
        case defaultThumbnail = "default"
    }

    func bestURL(videoID: String) -> URL {
        let candidates = [
            maxres?.url,
            standard?.url,
            high?.url,
            medium?.url,
            defaultThumbnail?.url
        ]

        if let firstValidString = candidates.compactMap({ $0 }).first,
           let url = URL(string: firstValidString) {
            return url
        }

        return URL(string: "https://i.ytimg.com/vi/\(videoID)/maxresdefault.jpg")!
    }
}
struct Thumbnail: Decodable {
    let url: String
}

// フラットに整理された YouTube ビデオ詳細レスポンスモデル
struct YouTubeVideoResponse: Decodable {
    let items: [YouTubeVideoItem]
}

struct YouTubeVideoItem: Decodable {
    let snippet: YouTubeVideoSnippet
}

struct YouTubeVideoSnippet: Decodable {
    let thumbnails: Thumbnails
}

struct PlaylistListResponse: Decodable {
    let items: [PlayListMetaItem]
}
struct PlayListMetaItem: Decodable {
    let id: String
    let snippet: PlayListMetaSnippet
    let contentDetails: PlayListContentDetails
}
struct PlayListMetaSnippet: Decodable {
    let title: String
    let channelTitle: String
    let thumbnails: Thumbnails?
}
struct PlayListContentDetails: Decodable {
    let itemCount: Int
}

enum VideoContentLanguage: String, Codable, CaseIterable {
    case ja
    case en

    var displayName: String {
        switch self {
            case .ja: return "日本語"
            case .en: return "英語"
        }
    }
}
// リストアイテム構造
struct VideoItem: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    var currentTime: Double? = nil
    var rate: Float = 1.0
    var playlistID: String?
    var aspectRatio: CGFloat
    var contentLanguage: VideoContentLanguage = .ja

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case currentTime = "current_time"
        case rate
        case playlistID = "playlist_id"
        case aspectRatio = "aspect_ratio"
        case contentLanguage = "content_language"
    }
}

enum YouTubeURLType {
    case single
    case playlist
    case unknown
}
enum AddYouTubeResult {
    case addedVideo(VideoItem)
    case addedPlaylist
    case addedVideoFromPlaylist(String)
    case invalid
}
struct PlayListVideoItem: Identifiable, Hashable {
    let id: String
    let title: String
    let thumbnailURL: URL?
}

//　再生リスト
struct PlaylistListItem: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let author: String
    let thumbnailURL: URL?
}

struct VideoItemAddRequest: Codable {
    let id: String
    let title: String
    let currentTime: Double?
    let rate: Float
    let playlistID: String?
    let aspectRatio: CGFloat
    let contentLanguage: VideoContentLanguage
    let createCaptionByAi: Bool
    let liveActivityToken: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case currentTime = "current_time"
        case rate
        case playlistID = "playlist_id"
        case aspectRatio = "aspect_ratio"
        case contentLanguage = "content_language"
        case createCaptionByAi = "create_caption_by_ai"
        case liveActivityToken = "live_activity_token"
    }

    init(video: VideoItem, createCaptionByAi: Bool, liveActivityToken: String?) {
        self.id = video.id
        self.title = video.title
        self.currentTime = video.currentTime
        self.rate = video.rate
        self.playlistID = video.playlistID
        self.aspectRatio = video.aspectRatio
        self.contentLanguage = video.contentLanguage
        self.createCaptionByAi = createCaptionByAi
        self.liveActivityToken = liveActivityToken
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
