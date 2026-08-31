//
//  VideoStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/20.
//

import SwiftUI
import Observation
import Foundation

@Observable
class VideoStore {
    var videos: [VideoItem] = []
    var isLoading: Bool = false

    var videoSubtitleSkipWords: VideoSubtitleSkipWords?
    var videoList: [PlaylistListItem] = []
    var videoListIsReady: Bool = false

    var videoListVideos: [PlayListVideoItem] = []
    var videoListVideosIsReady: Bool = false

    private let videoCacheKey: String = "cached_videos"

    init() {
        loadVideoCache() // Load local cache first

        Task { @MainActor in
            await fetchVideos()
        }
    }

    // MARK: - Local Cache (UserDefaults)
    private func loadVideoCache() {
        if let data = UserDefaults.standard.data(forKey: videoCacheKey),
           let cachedVideos = try? JSONDecoder().decode([VideoItem].self, from: data) {
            self.videos = cachedVideos
        }
    }

    func saveVideoCache() {
        if let encoded = try? JSONEncoder().encode(videos) {
            UserDefaults.standard.set(encoded, forKey: videoCacheKey)
        }
    }

    @MainActor
    private func upsertVideoLocally(_ video: VideoItem, animated: Bool = true) {
        let updateAction = {
            if let index = self.videos.firstIndex(where: { $0.id == video.id }) {
                self.videos[index] = video
            } else {
                self.videos.insert(video, at: 0)
            }
        }

        if animated {
            withAnimation(.spring(duration: 0.5)) {
                updateAction()
            }
        } else {
            updateAction()
        }

        saveVideoCache()
    }

    private func syncAddedVideoToServer(
        _ video: VideoItem,
        createCaptionByAi: Bool,
        liveActivityToken: String?
    ) async -> Bool {
        do {
            try await WorkersAPI.post(
                "add_video",
                body: VideoItemAddRequest(
                    video: video,
                    createCaptionByAi: createCaptionByAi,
                    liveActivityToken: liveActivityToken
                )
            )

            return true
        } catch {
            print("❌ Save add Error: \(error)")
            return false
        }
    }

    // MARK: - Video CRUD Operations (Server Sync with WorkersAPI)
    @MainActor
    func fetchVideos() async {
        do {
            self.videoSubtitleSkipWords = try await WorkersAPI.get("config/video_subtitle_skip_words")

            let freshVideos: [VideoItem] = try await WorkersAPI.get("fetch_videos")
            withAnimation(.easeIn(duration: 0.5)) {
                self.videos = freshVideos
            }

            AppGroupThumbnailStorage.removeOrphanedThumbnails(
                keeping: Set(freshVideos.map(\.id))
            )

            if let currentResumeVideoID = QuickActionManager.shared.currentResumeVideoID(),
               !freshVideos.contains(where: { $0.id == currentResumeVideoID }) {
                QuickActionManager.shared.clearResumeVideo()
            }

            saveVideoCache()

            Task(priority: .utility) {
                await Self.cacheMissingThumbnails(for: freshVideos)
            }
        } catch {
            if !videos.isEmpty {
                print("❌ Fetch Error (using cache)：\(error)")
            } else {
                isLoading = true
                print("❌ Fetch Error：\(error)")
            }
        }
    }

    @MainActor
    func addVideo(_ video: VideoItem, thumbnailURL: URL, createCaptionByAi: Bool = true) {
        Task(priority: .utility) {
            var thumbnailSaved = false

            do {
                let data = try await WorkersAPI.getData(from: thumbnailURL)
                try AppGroupThumbnailStorage.save(data, for: video.id)
                thumbnailSaved = true
            } catch {
                print("❌ Thumbnail download failed: \(error)")
            }

            if thumbnailSaved {
                await MainActor.run {
                    self.upsertVideoLocally(video)
                }
            }

            let liveActivityToken = await VideoStatusLiveActivityManager.shared.start(video: video)
            let didCreateServerRecord = await self.syncAddedVideoToServer(
                video,
                createCaptionByAi: createCaptionByAi,
                liveActivityToken: liveActivityToken
            )

            if didCreateServerRecord {
                VideoStatusLiveActivityManager.shared.observeTokenChanges(
                    videoID: video.id,
                    initialToken: liveActivityToken
                )
            }

        }
    }

    @MainActor
    func updateVideo(_ video: VideoItem) async {
        do {
            try await WorkersAPI.post("update_video", body: video)
            upsertVideoLocally(video, animated: false)
        } catch {
            print("❌ Update Error: \(error)")
        }
    }

    @MainActor
    func updateVideoAspectRatio(_ video: VideoItem) {
        Task {
            do {
                try await WorkersAPI.post("update_video_aspect_ratio", body: video)
                print("✅ aspectRatio Update Success")
                if let index = videos.firstIndex(where: { $0.id == video.id }) {
                    videos[index] = video
                }

                saveVideoCache()
            } catch {
                print("❌ Update Error: \(error)")
            }
        }
    }

    @MainActor
    func deleteVideo(_ id: String) async {
        do {
            try await WorkersAPI.post("delete_video", body: ["id": id])

            if let index = videos.firstIndex(where: { $0.id == id }) {
                videos.remove(at: index)
                saveVideoCache()
            }

            if QuickActionManager.shared.currentResumeVideoID() == id {
                QuickActionManager.shared.clearResumeVideo()
            }

            AppGroupThumbnailStorage.remove(for: id)
        } catch {
            print("❌ 刪除エラー:", error)
        }
    }

    // MARK: - Playlist Operations (Server Sync with WorkersAPI)
    @MainActor
    func fetchVideoPlaylist() async {
        videoListIsReady = false

        do {
            self.videoList = try await WorkersAPI.get("fetch_video_playlist")
            try? await Task.sleep(for: .seconds(0.1))
            withAnimation(.easeIn(duration: 0.25)) {
                videoListIsReady = true
            }
        } catch {
            print("❌ Fetch Error：\(error)")
        }
    }

    @MainActor
    func addVideoPlaylist(_ video: PlaylistListItem) async {
        do {
            try await WorkersAPI.post("add_video_playlist", body: video)
            await fetchVideoPlaylist()
            print("✅ Insert Success: \(video.id)")
        } catch {
            print("❌ Insert Error: \(error)")
        }
    }

    @MainActor
    func deleteVideoPlaylist(_ id: String) async {
        do {
            try await WorkersAPI.post("delete_video_playlist", body: ["id": id])
            await fetchVideoPlaylist()
        } catch {
            print("❌ Delete Error:", error)
        }
    }

    @MainActor
    func reorderVideos(_ reorderedVideos: [VideoItem], for category: PlaylistCategory) {
        var iterator = reorderedVideos.makeIterator()

        videos = videos.map { video in
            if belongsToCategory(video, category: category) {
                return iterator.next() ?? video
            }

            return video
        }

        saveVideoCache()
    }

    // MARK: - Video Details & Captions Fetching
    func fetchVideoSources(_ videoID: String) async throws -> VideoData {
        let video_decoded: VideoResponse = try await WorkersAPI.get(
            "get_video",
            queryItems: [
                URLQueryItem(
                    name: "id",
                    value: videoID
                )
            ]
        )

        guard let videoURL = URL(string: video_decoded.url),
              let captionsURL = URL(string: video_decoded.captions) else {
            throw URLError(.badURL)
        }

        return VideoData(
            url: videoURL,
            captionsUrl: captionsURL
        )
    }

    func fetchCaptions(from url: URL) async throws -> [CaptionLine] {
        let (captionData, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([CaptionLine].self, from: captionData)
    }

    // MARK: - Business Logic: Adding Videos with High Quality Thumbnails
    /// 1. 再生リスト選択画面から追加
    func addVideoFromPlaylist(
        _ item: PlayListVideoItem,
        playlistID: String,
        contentLanguage: VideoContentLanguage,
        createCaptionByAi: Bool = true,
        playbackRate: Float
    ) async {
        let immediateVideo = VideoItem(
            id: item.id,
            title: title,
            rate: playbackRate,
            playlistID: playlistID,
            aspectRatio: -1,
            contentLanguage: contentLanguage
        )
        upsertVideoLocally(immediateVideo)

        let highQualityThumbURL = await YouTubeService.fetchBestThumbnailURL(for: item.id)

        let syncedVideo = VideoItem(
            id: item.id,
            title: title,
            rate: playbackRate,
            playlistID: playlistID,
            aspectRatio: -1,
            contentLanguage: contentLanguage
        )
        addVideo(syncedVideo, thumbnailURL: highQualityThumbURL, createCaptionByAi: createCaptionByAi)
    }

    /// 2. リンクから直接追加
    @MainActor
    func handleYouTubeURL(
        _ url: String,
        contentLanguage: VideoContentLanguage,
        createCaptionByAi: Bool = true,
        playbackRate: Float = 1.0
    ) async -> AddYouTubeResult {
        let type = youtubeURLType(from: url)

        switch type {
            case .single:
                guard let videoID = extractVideoID(from: url) else {
                    return .invalid
                }
                if videos.contains(where: { $0.id == videoID }) {
                    return .invalid
                }

                let immediateVideo = VideoItem(
                    id: videoID,
                    title: videoID,
                    rate: playbackRate,
                    playlistID: nil,
                    aspectRatio: -1,
                    contentLanguage: contentLanguage
                )
                upsertVideoLocally(immediateVideo)

                Task {
                    let fetchedTitle = await YouTubeService.fetchTitle(videoID)
                    let title = videoTitle.isWhitespaceOrNewLine
                        ? fetchedTitle.cleanedVideoTitle
                        : videoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let highQualityThumbURL = await YouTubeService.fetchBestThumbnailURL(for: videoID)

                    let syncedVideo = VideoItem(
                        id: videoID,
                        title: title,
                        rate: playbackRate,
                        playlistID: nil,
                        aspectRatio: -1,
                        contentLanguage: contentLanguage
                    )
                    addVideo(syncedVideo, thumbnailURL: highQualityThumbURL, createCaptionByAi: createCaptionByAi)
                }

                return .addedVideo(immediateVideo)
            case .playlist:
                guard let listID = extractPlaylistID(from: url) else {
                    return .invalid
                }
                if videoList.contains(where: { $0.id == listID }) {
                    return .invalid
                }

                let immediatePlaylist = await fetchPlaylistMeta(playlistID: listID)
                await addVideoPlaylist(immediatePlaylist)

                Task {
                    await fetchVideoPlaylist()
                }

                return .addedPlaylist
            case .unknown:
                return .invalid
        }
    }

    // MARK: - Progressive UI Loading: YouTube Playlist Selection View
    func fetchPlaylistVideos(playlistID: String) async {
        videoListVideos.removeAll()
        videoListVideosIsReady = false

        var nextPageToken: String? = nil

        do {
            repeat {
                // YouTubeService から対象ページの全情報を取得
                let response = try await YouTubeService.fetchPlaylistPage(playlistID: playlistID, pageToken: nextPageToken)

                let pageVideos = response.items.compactMap { item -> PlayListVideoItem? in
                    guard let id = item.snippet.resourceId.videoId else { return nil }

                    let title = item.snippet.title
                    // 非公開動画(Private video)や、削除済み動画(Deleted video)は表示させないため除外
                    guard title != "Private video", title != "Deleted video", !title.isEmpty else {
                        return nil
                    }

                    // サムネイル群が存在しない無効なデータも除外
                    guard let thumbnails = item.snippet.thumbnails else {
                        return nil
                    }

                    // 一覧表示用（YouTubePlayListVideoSelectView）には標準画質（medium）を使用
                    let thumbURL: URL?
                    if let thumbString = thumbnails.medium?.url {
                        thumbURL = URL(string: thumbString)
                    } else {
                        thumbURL = URL(string: "https://i.ytimg.com/vi/\(id)/mqdefault.jpg")
                    }

                    return PlayListVideoItem(
                        id: id,
                        title: title,
                        thumbnailURL: thumbURL
                    )
                }

                await MainActor.run {
                    videoListVideos.append(contentsOf: pageVideos)

                    if !videoListVideosIsReady {
                        videoListVideosIsReady = true
                    }
                }

                nextPageToken = response.nextPageToken
            } while nextPageToken != nil
        } catch {
            print("❌ fetchPlaylistVideos error:", error)
        }
    }

    @MainActor
    func fetchPlaylistMeta(playlistID: String) async -> PlaylistListItem {
        do {
            let response = try await YouTubeService.fetchPlaylistMeta(playlistID: playlistID)
            guard let item = response.items.first else {
                throw URLError(.badServerResponse)
            }

            let thumbURL: URL?
            if let thumbString = item.snippet.thumbnails?.medium?.url {
                thumbURL = URL(string: thumbString)
            } else {
                thumbURL = nil
            }

            return PlaylistListItem(
                id: playlistID,
                title: item.snippet.title,
                author: item.snippet.channelTitle,
                thumbnailURL: thumbURL
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

    // MARK: - YouTube Service Forwarders (Helper Facades)
    // 外部のビューが直接 Store のメソッドを叩いている場合に備え、YouTubeService へのエイリアスとして残します
    func youtubeURLType(from url: String) -> YouTubeURLType {
        return YouTubeService.youtubeURLType(from: url)
    }

    private func extractVideoID(from url: String) -> String? {
        return YouTubeService.extractVideoID(from: url)
    }

    private func extractPlaylistID(from url: String) -> String? {
        return YouTubeService.extractPlaylistID(from: url)
    }

    func getExistingVideoIDs() -> Set<String> {
        return Set(videos.map { $0.id })
    }

    func getExistingVideoListIDs() -> Set<String> {
        return Set(videoList.map { $0.id })
    }

    private func belongsToCategory(_ video: VideoItem, category: PlaylistCategory) -> Bool {
        let knownPlaylistIDs = PlaylistCategory.allCases.compactMap { $0.playlistID }

        if let playlistID = category.playlistID {
            return video.playlistID == playlistID
        }

        return !knownPlaylistIDs.contains(video.playlistID ?? "")
    }

    func handleCategory(_ result: AddYouTubeResult) -> PlaylistCategory {
        switch result {
            case .addedVideo:
                return .shadowing
            case .addedVideoFromPlaylist(let playlistID):
                return PlaylistCategory.allCases.first {
                    $0.playlistID == playlistID
                } ?? .shadowing
            default:
                return .shadowing
        }
    }

    // MARK: - AppGroupThumbnailStorage Thumbnail
    private static func thumbnailSourceURL(for video: VideoItem) async -> URL {
        await YouTubeService.fetchBestThumbnailURL(for: video.id)
    }
    private static func cacheThumbnail(for video: VideoItem) async {
        guard AppGroupThumbnailStorage.existingFileURL(for: video.id) == nil else {
            return
        }

        let sourceURL = await thumbnailSourceURL(for: video)

        do {
            let data = try await WorkersAPI.getData(from: sourceURL)
            try AppGroupThumbnailStorage.save(data, for: video.id)
        } catch {
            print("❌ Thumbnail download failed (\(video.id)): \(error)")
        }
    }
    private static func cacheMissingThumbnails(for videos: [VideoItem]) async {
        await withTaskGroup(of: Void.self) { group in
            for video in videos {
                group.addTask {
                    await Self.cacheThumbnail(for: video)
                }
            }
        }
    }

    // MARK: - Analytics & Study Practice Session Sync
    @MainActor
    func reportPracticeSession(
        contentLanguage: VideoContentLanguage,
        practiceDate: String,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int
    ) async {
        let payload = PracticeSessionPayload(
            id: UUID().uuidString,
            contentLanguage: contentLanguage,
            practiceDate: practiceDate,
            startedAt: sqliteDateTimeString(from: startedAt),
            endedAt: sqliteDateTimeString(from: endedAt),
            durationSeconds: durationSeconds
        )

        do {
            try await WorkersAPI.post("update_practice_session", body: payload)
        } catch {
            print("❌ practice session sync failed:", error)
        }
    }
}
