//
//  QuickActionManager.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/20.
//

import UIKit

enum QuickActionType: String {
    case resumeVideo = "com.japanese.resumeVideo"

    static let videoIDKey = "videoID"
}

@MainActor
final class QuickActionManager {
    static let shared = QuickActionManager()

    private init() {}

    /// 旧版がシステムへ登録した文法アクションや、不正な動画アクションを起動時に除去する。
    func removeObsoleteActions() {
        UIApplication.shared.shortcutItems = Array((UIApplication.shared.shortcutItems ?? [])
            .filter { QuickActionTarget(shortcutItem: $0) != nil }
            .prefix(1))
    }

    func currentResumeVideoID() -> String? {
        UIApplication.shared.shortcutItems?
            .compactMap { QuickActionTarget(shortcutItem: $0)?.videoID }
            .first
    }

    func updateResumeVideoAction(videoID: String, title: String, time: String) {
        guard !videoID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        UIApplication.shared.shortcutItems = [UIApplicationShortcutItem(
            type: QuickActionType.resumeVideo.rawValue,
            localizedTitle: "続きから再生",
            localizedSubtitle: "\(time) ・ \(title)",
            icon: UIApplicationShortcutIcon(systemImageName: "play.rectangle.fill"),
            userInfo: [QuickActionType.videoIDKey: videoID as NSString]
        )]
    }

    func clearResumeVideo() {
        UIApplication.shared.shortcutItems = []
    }
}
