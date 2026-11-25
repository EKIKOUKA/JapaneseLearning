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
    var playlistCategories: [PlaylistCategory] = []
    var videoSubtitleSkipWords: VideoSubtitleSkipWords?

    private var cacheOwnerID: String?
    private var videoCacheKey: String { "cached_videos.\(cacheOwnerID ?? "signed-out")" }
    private var playlistCategoriesCacheKey: String { "cached_playlist_categories.\(cacheOwnerID ?? "signed-out")" }

    @MainActor
    func accountChanged(to userID: String?) async {
        if cacheOwnerID != nil && cacheOwnerID != userID {
            UserDefaults.standard.removeObject(forKey: videoCacheKey)
            UserDefaults.standard.removeObject(forKey: playlistCategoriesCacheKey)
        }
        cacheOwnerID = userID
        videos = []
        playlistCategories = []
        videoSubtitleSkipWords = nil
        QuickActionManager.shared.clearResumeVideo()
        guard userID != nil else { return }
        loadVideoCache()
        loadPlaylistCategoriesCache()
//        await fetchVideos()
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

    private func loadPlaylistCategoriesCache() {
        if let data = UserDefaults.standard.data(forKey: playlistCategoriesCacheKey),
           let cachedCategories = try? JSONDecoder().decode([PlaylistCategory].self, from: data) {
            playlistCategories = cachedCategories.sorted { $0.sortOrder < $1.sortOrder }
        }
    }

    private func savePlaylistCategoriesCache() {
        if let encoded = try? JSONEncoder().encode(playlistCategories) {
            UserDefaults.standard.set(encoded, forKey: playlistCategoriesCacheKey)
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

    // MARK: - Video CRUD Operations (Server Sync with WorkersAPI)
    @MainActor
    func fetchVideos() async {
        let owner = cacheOwnerID
        guard owner != nil, let sessionToken = AppleAccountStore.savedSessionToken else { return }
        do {
            let fetchedCategories: [PlaylistCategory] = try await WorkersAPI.get("fetch_playlist_categories", authorizationToken: sessionToken, requiresAuthentication: true)
            guard cacheOwnerID == owner, !Task.isCancelled else { return }
            self.playlistCategories = fetchedCategories.sorted {
                $0.sortOrder < $1.sortOrder
            }
            savePlaylistCategoriesCache()

            let skipWords: VideoSubtitleSkipWords = try await WorkersAPI.get("config/video_subtitle_skip_words", authorizationToken: sessionToken, requiresAuthentication: true)

            guard cacheOwnerID == owner, !Task.isCancelled else { return }
            self.videoSubtitleSkipWords = skipWords
            let freshVideos: [VideoItem] = try await WorkersAPI.get("fetch_videos", authorizationToken: sessionToken, requiresAuthentication: true)
            guard cacheOwnerID == owner, !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.5)) {
                self.videos = freshVideos
            }

            AppGroupThumbnailStorage.removeOrphanedThumbnails(
                keeping: Set(self.videos.map(\.id))
            )

            if let currentResumeVideoID = QuickActionManager.shared.currentResumeVideoID(),
               !freshVideos.contains(where: { $0.id == currentResumeVideoID }) {
                QuickActionManager.shared.clearResumeVideo()
            }

            saveVideoCache()

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
    func updateVideo(_ video: VideoItem) async {
        let owner = cacheOwnerID
        do {
            try await WorkersAPI.post("update_video", body: video, requiresAuthentication: true)
            guard cacheOwnerID == owner else { return }
            upsertVideoLocally(video, animated: false)
        } catch {
            print("❌ Update Error: \(error)")
        }
    }

    @MainActor
    func updateVideoAspectRatio(_ video: VideoItem) {
        Task {
            do {
                try await WorkersAPI.post("update_video_aspect_ratio", body: video, requiresAuthentication: true)
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

    // MARK: - Video Details & Captions Fetching
    func fetchVideoSources(_ videoID: String) async throws -> VideoData {
        let video_decoded: VideoResponse = try await WorkersAPI.get(
            "get_video",
            queryItems: [
                URLQueryItem(
                    name: "id",
                    value: videoID
                )
            ],
            requiresAuthentication: true
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
        try await WorkersAPI.getExternalJSON(from: url, failureMessage: "字幕を読み込めませんでした。")
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
        guard let sessionToken = AppleAccountStore.savedSessionToken else { return }

        let payload = PracticeSessionPayload(
            id: UUID().uuidString,
            contentLanguage: contentLanguage,
            practiceDate: practiceDate,
            startedAt: sqliteUTCDateTimeString(from: startedAt),
            endedAt: sqliteUTCDateTimeString(from: endedAt),
            durationSeconds: durationSeconds
        )

        do {
            try await WorkersAPI.post("update_practice_session", body: payload, authorizationToken: sessionToken)
        } catch {
            print("❌ practice session sync failed:", error)
        }
    }
}
