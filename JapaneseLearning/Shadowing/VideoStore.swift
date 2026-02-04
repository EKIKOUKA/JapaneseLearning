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

    init() {
        if let dataVideo = UserDefaults.standard.data(forKey: "saved_videos"),
           let decodedVideo = try? JSONDecoder().decode([VideoItem].self, from: dataVideo) {
            self.videos = decodedVideo
            print("videos: \(decodedVideo.map { "\($0.id): \($0.title): \($0.firstLoad)" })")
        }

        if let dataVideoList = UserDefaults.standard.data(forKey: "saved_video_list"),
           let decodedVideoList = try? JSONDecoder().decode([PlaylistListItem].self, from: dataVideoList) {
            self.videoList = decodedVideoList
            print("video list: \(decodedVideoList.map { "\($0.id): \($0.author): \($0.title): \($0.videoCount)件" })")
        }
    }

    func saveVideo() {
        if let encoded = try? JSONEncoder().encode(videos) {
            UserDefaults.standard.set(encoded, forKey: "saved_videos")
        }
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

    func addPlaylistVideos(_ items: [PlayListVideoItem]) {
        for item in items {
            if videos.contains(where: { $0.id == item.id }) { continue }

            videos.append(
                VideoItem(
                    id: item.id,
                    url: "https://www.youtube.com/watch?v=\(item.id)",
                    title: item.title,
                    thumbnailURL: item.thumbnailURL,
                    firstLoad: true
                )
            )
        }
        saveVideo()
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

                videos.append(
                    VideoItem(
                        id: videoID,
                        url: "https://www.youtube.com/watch?v=\(videoID)",
                        title: title,
                        thumbnailURL: thumbURL,
                        firstLoad: true
                    )
                )
                saveVideo()
                return .addedVideo

            case .playlist:
                guard let listID = extractPlaylistID(from: url) else {
                    return .invalid
                }

                if videoList.contains(where: { $0.id == listID }) {
                    return .invalid
                }

                let meta = await fetchPlaylistMeta(playlistID: listID)
                videoList.append(meta)
                saveVideoList()

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

    func deleteVideo(_ id: String) {
        videos.removeAll { $0.id == id }

        if currentResumeVideoID == id {
            currentResumeVideoID = nil
            QuickActionManager.shared.clearResumeVideo()
        }

        saveVideo()
    }

    func getExistingVideoIDs() -> Set<String> {
        return Set(videos.map { $0.id })
    }


    func saveVideoList() {
        if let encoded = try? JSONEncoder().encode(videoList) {
            UserDefaults.standard.set(encoded, forKey: "saved_video_list")
        }
    }
    func addVideoList(_ playlistVideoList: [PlaylistListItem]) {
        for video_list in playlistVideoList {
            if !videoList.contains(where: { $0.id == video_list.id }) {
                videoList.append(
                    PlaylistListItem(
                        id: video_list.id,
                        title: video_list.title,
                        author: video_list.author,
                        thumbnailURL: video_list.thumbnailURL,
                        videoCount: video_list.videoCount
                    )
                )
            }
        }
        saveVideoList()
    }
    func deleteVideoFromPlayList(_ id: String) {
        videoList.removeAll { $0.id == id}
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
    func deleteVideoList(_ id: String) {
        videoList.removeAll { $0.id == id }
        saveVideoList()
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
                thumbnailURL: URL(string: thumb),
                videoCount: item.contentDetails.itemCount
            )

        } catch {
            print("❌ fetchPlaylistMeta error:", error)
            return PlaylistListItem(
                id: playlistID,
                title: "Unknown Playlist",
                author: "",
                thumbnailURL: nil,
                videoCount: 0
            )
        }
    }
}
