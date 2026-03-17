//
//  VideoModels.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/21.
//

import Foundation

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
    let thumbnails: Thumbnails
}
struct ResourceId: Decodable {
    let videoId: String?
}
struct Thumbnails: Decodable {
    let medium: Thumbnail?
}
struct Thumbnail: Decodable {
    let url: String
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
    let thumbnails: Thumbnails
}
struct PlayListContentDetails: Decodable {
    let itemCount: Int
}


// リストアイテム構造
struct VideoItem: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    var currentTime: Double? = nil
    var rate: Float? = nil
    let thumbnailURL: URL?
    var playlistID: String?
    var videoAspectRatio: CGFloat

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case currentTime = "current_time"
        case rate
        case thumbnailURL = "thumbnail"
        case playlistID = "playlist_id"
        case videoAspectRatio = "video_aspectr_atio"
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
    case addedVideosFromPlaylist(String)
    case invalid
}
struct PlayListVideoItem: Identifiable, Hashable {
    let id: String
    let title: String
    let thumbnailURL: URL?
}

struct PlaylistListItem: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let author: String
    let thumbnailURL: URL?
}
