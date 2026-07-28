//
//  VideoStatusLiveActivityManager.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 7/6/R8.
//

@preconcurrency import ActivityKit
import Foundation

struct LiveActivityTokenRequest: Encodable {
    let id: String
    let token: String
}

@MainActor
final class VideoStatusLiveActivityManager {
    static let shared = VideoStatusLiveActivityManager()
    private init() {}
    private var activities: [String: Activity<VideoStatusAttributes>] = [:]
    private var observedVideoIDs: Set<String> = []

    func start(video: VideoItem) async -> String? {
        if let activity = activities[video.id]
            ?? Activity<VideoStatusAttributes>.activities.first(where: {
                $0.attributes.videoId == video.id
            }) {
            activities[video.id] = activity
            return await firstPushToken(for: activity)
        }

        let attributes = VideoStatusAttributes(
            videoId: video.id,
            videoTitle: video.title
        )

        let state = VideoStatusAttributes.ContentState(
            progress: 0.0,
            status: "準備中",
            errorMessage: ""
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: .token
            )

            activities[video.id] = activity

            return await firstPushToken(for: activity)
        } catch {
            print(error)
            return nil
        }
    }

    private func firstPushToken(for activity: Activity<VideoStatusAttributes>) async -> String? {
        if let tokenData = activity.pushToken {
            return Self.hexString(from: tokenData)
        }

        for await tokenData in activity.pushTokenUpdates {
            return Self.hexString(from: tokenData)
        }

        return nil
    }

    func observeTokenChanges(
        videoID: String,
        initialToken: String?
    ) {
        guard let activity = activities[videoID],
              observedVideoIDs.insert(videoID).inserted else {
            return
        }

        Task { @MainActor in
            var lastToken = initialToken

            for await tokenData in activity.pushTokenUpdates {
                let token = Self.hexString(from: tokenData)
                guard token != lastToken else { continue }
                lastToken = token

                do {
                    try await WorkersAPI.post(
                        "video/live_activity_token",
                        body: LiveActivityTokenRequest(id: videoID, token: token)
                    )
                } catch {
                    print("❌ Live Activity token update failed: \(error)")
                }
            }

            observedVideoIDs.remove(videoID)
        }
    }

    private nonisolated static func hexString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
