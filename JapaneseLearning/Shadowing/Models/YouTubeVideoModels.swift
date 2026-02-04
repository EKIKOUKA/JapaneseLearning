//
//  YouTubeVideoModels.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/21.
//

import Foundation

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
    let url: String
    let title: String
    let thumbnailURL: URL?

    var firstLoad: Bool = true
    var currentTime: Double? = nil
    var rate: Float? = nil
}

enum YouTubeURLType {
    case single
    case playlist
    case unknown
}
enum AddYouTubeResult {
    case addedVideo
    case addedPlaylist
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
    let videoCount: Int
}
