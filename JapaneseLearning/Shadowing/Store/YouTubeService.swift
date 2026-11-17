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
        return channelFilter(from: url) == nil ? .unknown : .channel
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

    private static func channelFilter(from url: String) -> URLQueryItem? {
        guard let components = URLComponents(string: url),
              let host = components.host?.lowercased(),
              host == "youtube.com" || host.hasSuffix(".youtube.com") else { return nil }
        let parts = components.path.split(separator: "/")
        guard let first = parts.first else { return nil }

        if first.hasPrefix("@"), first.count > 1 {
            return URLQueryItem(name: "forHandle", value: String(first))
        }
        guard parts.count >= 2 else { return nil }

        switch first {
            case "channel": return URLQueryItem(name: "id", value: String(parts[1]))
            case "user": return URLQueryItem(name: "forUsername", value: String(parts[1]))
            default: return nil
        }
    }

    static func fetchChannel(channelURL: String) async throws -> ChannelInfo {
        guard let filter = channelFilter(from: channelURL) else { throw URLError(.badURL) }
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/channels")!
        components.queryItems = [
            .init(name: "part", value: "contentDetails,snippet,statistics"),
            .init(name: "fields", value: "items(id,contentDetails/relatedPlaylists/uploads,snippet(title,customUrl,thumbnails/default/url),statistics/videoCount)"),
            .init(name: "key", value: apiKey),
            filter
        ]

        let result: UploadsPlaylistResponse = try await WorkersAPI.getExternalJSON(
            from: components.url!,
            failureMessage: "YouTube チャンネルの動画一覧を取得できませんでした。"
        )

        return result.channel
    }

    private struct UploadsPlaylistResponse: Decodable {
        struct Item: Decodable {
            struct ContentDetails: Decodable {
                struct RelatedPlaylists: Decodable { let uploads: String }
                let relatedPlaylists: RelatedPlaylists
            }
            let contentDetails: ContentDetails
            let id: String
            let snippet: Snippet
            let statistics: Statistics?

            struct Snippet: Decodable {
                struct Thumbnail: Decodable { let url: URL }
                let title: String
                let customUrl: String?
                let thumbnails: [String: Thumbnail]?
            }

            struct Statistics: Decodable { let videoCount: String? }
        }

        let channel: ChannelInfo

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let items = try container.decode([Item].self, forKey: .items)
            guard let item = items.first, !item.contentDetails.relatedPlaylists.uploads.isEmpty else {
                throw URLError(.resourceUnavailable)
            }
            channel = ChannelInfo(
                id: item.id,
                uploadsID: item.contentDetails.relatedPlaylists.uploads,
                title: item.snippet.title,
                handle: item.snippet.customUrl.flatMap { $0.hasPrefix("@") ? $0 : nil },
                avatar: item.snippet.thumbnails?["default"]?.url,
                videoCount: item.statistics?.videoCount.flatMap { Int($0) }
            )
        }

        private enum CodingKeys: String, CodingKey { case items }
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

    private static func r2CoverURL(for videoID: String) -> URL {
        URL(string: "https://video.shadowing.makoto.lol")!
            .appendingPathComponent(videoID)
            .appendingPathComponent("cover.jpg")
    }
    /// 最高画質のサムネイルURLをAPIから優先取得
    static func fetchBestThumbnailURL(for videoID: String) async -> URL {
        let fallbackURL = r2CoverURL(for: videoID)

        let urlString = "https://www.googleapis.com/youtube/v3/videos" +
            "?part=snippet" +
            "&id=\(videoID)" +
            "&key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            return fallbackURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return fallbackURL
            }

            let decoded = try JSONDecoder().decode(
                YouTubeVideoResponse.self,
                from: data
            )

            guard let thumbnails = decoded.items.first?.snippet.thumbnails else {
                return fallbackURL
            }

            return thumbnails.bestURL(videoID: videoID)
        } catch {
            return fallbackURL
        }
    }

    /// 再生リスト内の動画ページを取得
    static func fetchPlaylistPage(playlistID: String, pageToken: String?) async throws -> PlaylistResponse {
        var comp = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlistItems")!
        comp.queryItems = [
            .init(name: "part", value: "snippet"),
            .init(name: "maxResults", value: "100"),
            .init(name: "playlistId", value: playlistID),
            .init(name: "fields", value: "nextPageToken,items(snippet(title,resourceId/videoId,thumbnails(maxres/url,standard/url,high/url,medium/url)))"),
            .init(name: "key", value: apiKey)
        ]

        if let token = pageToken {
            comp.queryItems?.append(.init(name: "pageToken", value: token))
        }

        return try await WorkersAPI.getExternalJSON(
            from: comp.url!,
            failureMessage: "YouTube の再生リストを取得できませんでした。"
        )
    }

    /// 再生リストのメタ情報（タイトルや著者）を取得
    static func fetchPlaylistMeta(playlistID: String) async throws -> PlaylistListResponse {
        try await fetchPlaylists(filter: .init(name: "id", value: playlistID))
    }

    static func fetchChannelPlaylists(channelID: String, pageToken: String?) async throws -> PlaylistListResponse {
        try await fetchPlaylists(filter: .init(name: "channelId", value: channelID), pageToken: pageToken)
    }

    private static func fetchPlaylists(filter: URLQueryItem, pageToken: String? = nil) async throws -> PlaylistListResponse {
        var comp = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlists")!
        comp.queryItems = [
            .init(name: "part", value: "snippet,contentDetails"),
            filter,
            .init(name: "maxResults", value: "50"),
            .init(name: "fields", value: "nextPageToken,items(id,snippet(title,channelTitle,thumbnails(maxres/url,standard/url,high/url,medium/url)),contentDetails(itemCount))"),
            .init(name: "key", value: apiKey)
        ]

        if let pageToken {
            comp.queryItems?.append(.init(name: "pageToken", value: pageToken))
        }

        return try await WorkersAPI.getExternalJSON(
            from: comp.url!,
            failureMessage: "YouTube の再生リストを取得できませんでした。"
        )
    }
}
