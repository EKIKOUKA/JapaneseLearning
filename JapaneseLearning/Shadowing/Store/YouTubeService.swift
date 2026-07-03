//
//  YouTubeService.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/21.
//

import Foundation

struct YouTubeService {
    private static let apiKey = Config.YouTubeDataAPIKey

    // MARK: - YouTube URL 構造解析ツール
    static func youtubeURLType(from url: String) -> YouTubeURLType {
        guard let components = URLComponents(string: url) else { return .unknown }
        let queryItems = components.queryItems ?? []

        if queryItems.contains(where: { $0.name == "v" }) {
            return .single
        }
        if queryItems.contains(where: { $0.name == "list" }) {
            return .playlist
        }
        return .unknown
    }

    static func extractVideoID(from url: String) -> String? {
        if let comp = URLComponents(string: url),
           let items = comp.queryItems {
            return items.first(where: { $0.name == "v" })?.value
        }
        return nil
    }

    static func extractPlaylistID(from url: String) -> String? {
        guard let components = URLComponents(string: url) else { return nil }

        if components.path == "/playlist",
           let list = components.queryItems?.first(where: { $0.name == "list" })?.value {
            return list
        }
        if let list = components.queryItems?.first(where: { $0.name == "list" })?.value {
            return list
        }
        return nil
    }

    // MARK: - YouTube API 直接通信メソッド
    /// YouTube 埋め込み API からタイトルを取得
    static func fetchTitle(_ videoId: String) async -> String {
        let url = URL(string: "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(videoId)&format=json")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let title = json["title"] as? String {
                return title
            }
        } catch {}
        return "YouTube Video"
    }

    /// 最高画質のサムネイルURLをAPIから優先取得
    static func fetchBestThumbnailURL(for videoID: String) async -> URL {
        let urlString = "https://www.googleapis.com/youtube/v3/videos?part=snippet&id=\(videoID)&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            return URL(string: "https://i.ytimg.com/vi/\(videoID)/maxresdefault.jpg")!
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(YouTubeVideoResponse.self, from: data)
            if let thumbnails = response.items.first?.snippet.thumbnails {
                return thumbnails.bestURL(videoID: videoID)
            }
        } catch {}
        return URL(string: "https://i.ytimg.com/vi/\(videoID)/maxresdefault.jpg")!
    }

    /// 再生リスト内の動画ページを取得
    static func fetchPlaylistPage(playlistID: String, pageToken: String?) async throws -> PlaylistResponse {
        var comp = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlistItems")!
        comp.queryItems = [
            .init(name: "part", value: "snippet"),
            .init(name: "maxResults", value: "50"),
            .init(name: "playlistId", value: playlistID),
            .init(name: "fields", value: "nextPageToken,items(snippet(title,resourceId/videoId,thumbnails(maxres/url,standard/url,high/url,medium/url)))"),
            .init(name: "key", value: apiKey)
        ]

        if let token = pageToken {
            comp.queryItems?.append(.init(name: "pageToken", value: token))
        }

        let (data, _) = try await URLSession.shared.data(from: comp.url!)
        return try JSONDecoder().decode(PlaylistResponse.self, from: data)
    }

    /// 再生リストのメタ情報（タイトルや著者）を取得
    static func fetchPlaylistMeta(playlistID: String) async throws -> PlaylistListResponse {
        var comp = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlists")!
        comp.queryItems = [
            .init(name: "part", value: "snippet,contentDetails"),
            .init(name: "id", value: playlistID),
            .init(name: "fields", value: "items(snippet(title,channelTitle,thumbnails(maxres/url,standard/url,high/url,medium/url)))"),
            .init(name: "key", value: apiKey)
        ]

        let (data, _) = try await URLSession.shared.data(from: comp.url!)
        return try JSONDecoder().decode(PlaylistListResponse.self, from: data)
    }
}
