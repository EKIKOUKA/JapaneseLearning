//
//  VideoStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/20.
//

import Observation
import Foundation

@Observable
class VideoStore {

    var videos: [VideoItem] = []
    var videoList: [PlaylistListItem] = []
    var currentResumeVideoID: String?
    var isLoading = true

    init() {
        Task { @MainActor in
            await fetchVideos()
        }
    }

    @MainActor
    func fetchVideos() async {
        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/fetch_videos")!
            let (data, _) = try await URLSession.shared.data(from: url)

            let videos = try JSONDecoder().decode([VideoItem].self, from: data)
            self.videos = videos
            isLoading = false
        } catch {
            print("❌ Fetch Error：\(error)")
        }
    }
    @MainActor
    func addVideo(_ video: VideoItem) async {
        guard let url = URL(string: "\(Cloudflare_Workers_URL)/add_video") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            request.httpBody = try JSONEncoder().encode(video)

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("❌ Server Save Failed")
                return
            }

            videos.insert(video, at: 0)
        } catch {
            print("❌ Save add Error: \(error)")
        }
    }
    // 更新狀態：播放進度同步
    @MainActor
    func updateVideo(_ video: VideoItem) async {
        guard let url = URL(string: "\(Cloudflare_Workers_URL)/update_video") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(video)

            _ = try await URLSession.shared.data(for: request)
            print("✅ Progress Sync Success")
            if let index = videos.firstIndex(where: { $0.id == video.id }) {
                videos[index] = video
            }
        } catch {
            print("❌ Update Error: \(error)")
        }
    }
    @MainActor
    func deleteVideo(_ id: String) async {
        guard let url = URL(string: "\(Cloudflare_Workers_URL)/del_video/\(id)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                await fetchVideos()

                if currentResumeVideoID == id {
                    currentResumeVideoID = nil
                    QuickActionManager.shared.clearResumeVideo()
                }
            }
        } catch {
            print("❌ 刪除錯誤:", error)
        }
    }

    // Playlist
    @MainActor
    func fetchVideoPlaylist() async {
        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/fetch_video_playlist")!
            let (data, _) = try await URLSession.shared.data(from: url)

            let response = try JSONDecoder().decode([PlaylistListItem].self, from: data)
            self.videoList = response
        } catch {
            print("❌ Fetch Error：\(error)")
        }
    }
    @MainActor
    func addVideoPlaylist(_ video: PlaylistListItem) async {
        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/add_video_playlist")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(video)
            _ = try await URLSession.shared.data(for: request)

            await fetchVideoPlaylist()
            print("✅ Insert Success: \(video.id)")
        } catch {
            print("❌ Insert Error: \(error)")
        }
    }
    @MainActor
    func deleteVideoPlaylist(_ id: String) async {
        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/delete_video_playlist/\(id)")!
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            _ = try await URLSession.shared.data(for: request)

            await fetchVideoPlaylist()
        } catch {
            print("❌ Delete Error:", error)
        }
    }

    // video url/captions
    func fetchVideoDataFromServer(_ videoID: String) async throws -> VideoData {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil

        let session = URLSession(configuration: config)

        let serverURL = "\(Cloudflare_Workers_URL)/get_video?id=\(videoID)"
        guard let url = URL(string: serverURL) else {
            print("❌ invalid url:", serverURL)
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url) // URLSession.shared

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let video_decoded = try JSONDecoder().decode(VideoResponse.self, from: data)

        guard let videoURL = URL(string: video_decoded.url),
              let captionsURL = URL(string: video_decoded.captions) else {
            throw URLError(.badURL)
        }

        async let (captionData, _) = try await session.data(from: captionsURL)
        let captions = try await JSONDecoder().decode([CaptionLine].self, from: captionData)

        return VideoData(
            url: videoURL,
            captions: captions
        )
    }


    func fetchTitle(_ videoId: String) async -> String {
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

    func addVideosFromPlaylist(
        _ items: [PlayListVideoItem],
        playlistID: String
    ) async {
        for item in items {
            await addVideo(
                VideoItem(
                    id: item.id,
                    title: item.title,
                    thumbnailURL: item.thumbnailURL,
                    playlistID: playlistID
                )
            )
        }
    }

    @MainActor
    func handleYouTubeURL(_ url: String) async -> AddYouTubeResult {
        let type = detectYouTubeURLType(from: url)

        switch type {
            case .single:
                guard let videoID = extractVideoID(from: url) else {
                    return .invalid
                }
                if videos.contains(where: { $0.id == videoID }) {
                    return .invalid
                }

                let title = await fetchTitle(videoID)
                let thumbURL = URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg")

                let newVideo = VideoItem(
                    id: videoID,
                    title: title,
                    thumbnailURL: thumbURL,
                    playlistID: nil
                )

                await addVideo(newVideo)

                return .addedVideo(newVideo)

            case .playlist:
                guard let listID = extractPlaylistID(from: url) else {
                    return .invalid
                }

                if videoList.contains(where: { $0.id == listID }) {
                    return .invalid
                }

                let meta = await fetchPlaylistMeta(playlistID: listID)
                await addVideoPlaylist(meta)
                await fetchVideoPlaylist()

                return .addedPlaylist

            case .unknown:
                return .invalid
        }
    }

    private func extractVideoID(from url: String) -> String? {
        if let comp = URLComponents(string: url),
           let items = comp.queryItems {
            return items.first(where: { $0.name == "v" })?.value
        }

        return nil
    }

    private func detectYouTubeURLType(from url: String) -> YouTubeURLType {
        guard let components = URLComponents(string: url),
              let host = components.host else {
            return .unknown
        }

        let queryItems = components.queryItems ?? []

        let videoID = queryItems.first(where: { $0.name == "v" })?.value
        let playListID = queryItems.first(where: { $0.name == "list" })?.value

        if let playListID {
            return .playlist
        }
        if let videoID {
            return .single
        }

        return .unknown
    }

    func getExistingVideoIDs() -> Set<String> {
        return Set(videos.map { $0.id })
    }

    private func extractPlaylistID(from url: String) -> String? {
        guard let components = URLComponents(string: url) else {
            return nil
        }

        if components.path == "/playlist",
           let list = components.queryItems?.first(where: { $0.name == "list" })?.value {
            return list
        }

        if let list = components.queryItems?.first(where: { $0.name == "list" })?.value {
            return list
        }

        return nil
    }
    @MainActor
    func fetchPlaylistVideos(playlistID: String) async -> [PlayListVideoItem] {

        var allVideos: [PlayListVideoItem] = []
        var nextPageToken: String? = nil

        do {
            repeat {
                let url = makePlaylistVideoURL(
                    playlistId: playlistID,
                    pageToken: nextPageToken
                )

                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(PlaylistResponse.self, from: data)

                let pageVideos = response.items.compactMap { item -> PlayListVideoItem? in
                    guard
                        let id = item.snippet.resourceId.videoId,
                        let thumbURL = item.snippet.thumbnails.medium?.url
                    else { return nil }

                    return PlayListVideoItem(
                        id: id,
                        title: item.snippet.title,
                        thumbnailURL: URL(string: thumbURL)
                    )
                }

                allVideos.append(contentsOf: pageVideos)
                nextPageToken = response.nextPageToken

            } while nextPageToken != nil

        } catch {
            print("❌ fetchPlaylistVideos error:", error)
        }

        return allVideos
    }
    private func makePlaylistVideoURL(
        playlistId: String,
        pageToken: String?
    ) -> URL {

        var comp = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlistItems")!
        comp.queryItems = [
            .init(name: "part", value: "snippet"),
            .init(name: "maxResults", value: "50"),
            .init(name: "playlistId", value: playlistId),
            .init(name: "key", value: Config.YouTubeDataAPIKey)
        ]

        if let token = pageToken {
            comp.queryItems?.append(.init(name: "pageToken", value: token))
        }

        return comp.url!
    }
    func getExistingVideoListIDs() -> Set<String> {
        return Set(videoList.map { $0.id })
    }

    private func makePlaylistMetaURL(playlistID: String) -> URL {

        var comp = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlists")!
        comp.queryItems = [
            .init(name: "part", value: "snippet,contentDetails"),
            .init(name: "id", value: playlistID),
            .init(name: "key", value: Config.YouTubeDataAPIKey)
        ]

        return comp.url!
    }
    @MainActor
    func fetchPlaylistMeta(playlistID: String) async -> PlaylistListItem {

        let url = makePlaylistMetaURL(playlistID: playlistID)

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(PlaylistListResponse.self, from: data)

            guard let item = response.items.first,
              let thumb = item.snippet.thumbnails.medium?.url
            else {
                throw URLError(.badServerResponse)
            }

            return PlaylistListItem(
                id: playlistID,
                title: item.snippet.title,
                author: item.snippet.channelTitle,
                thumbnailURL: URL(string: thumb)
            )
        } catch {
            print("❌ fetchPlaylistMeta error:", error)
            return PlaylistListItem(
                id: playlistID,
                title: "Unknown Playlist",
                author: "",
                thumbnailURL: nil
            )
        }
    }
}
