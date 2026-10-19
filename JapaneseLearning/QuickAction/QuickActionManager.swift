//
//  QuickActionManager.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/20.
//

import UIKit

enum QuickActionType: String {
    case resumeVideo = "com.japanese.resumeVideo"
    case recentGrammar = "com.japanese.recentGrammar"

    static let videoIDKey = "videoID"
}

@MainActor
final class QuickActionManager {
    static let shared = QuickActionManager()

    private init() {}

    /// 動画と文法の有効なショートカットを残し、不正・重複したアクションだけを除去する。
    func removeObsoleteActions() {
        var seen = Set<String>()
        UIApplication.shared.shortcutItems = (UIApplication.shared.shortcutItems ?? [])
            .filter { QuickActionTarget(shortcutItem: $0) != nil && seen.insert($0.type).inserted }
    }

    func currentResumeVideoID() -> String? {
        UIApplication.shared.shortcutItems?
            .compactMap { QuickActionTarget(shortcutItem: $0)?.videoID }
            .first
    }

    func updateResumeVideoAction(videoID: String, title: String, time: String) {
        guard !videoID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        updateAction(UIApplicationShortcutItem(
            type: QuickActionType.resumeVideo.rawValue,
            localizedTitle: "続きから再生",
            localizedSubtitle: "\(time) ・ \(title)",
            icon: UIApplicationShortcutIcon(systemImageName: "play.rectangle.fill"),
            userInfo: [QuickActionType.videoIDKey: videoID as NSString]
        ))
    }

    func updateRecentGrammarAction(grammarID: String, title: String, level: String) {
        let item = UIApplicationShortcutItem(
            type: QuickActionType.recentGrammar.rawValue,
            localizedTitle: "最近の文法",
            localizedSubtitle: title,
            icon: UIApplicationShortcutIcon(systemImageName: "text.book.closed.fill"),
            userInfo: ["grammarID": grammarID as NSString, "level": level as NSString]
        )
        guard QuickActionTarget(shortcutItem: item) != nil else { return }
        updateAction(item)
    }

    /// 片方の更新で、もう片方のアクションを消さない。
    private func updateAction(_ item: UIApplicationShortcutItem) {
        removeObsoleteActions()
        var items = UIApplication.shared.shortcutItems ?? []
        items.removeAll { $0.type == item.type }
        items.append(item)
        items.sort { $0.type == QuickActionType.recentGrammar.rawValue && $1.type != QuickActionType.recentGrammar.rawValue }
        UIApplication.shared.shortcutItems = items
    }

    func clearResumeVideo() {
        UIApplication.shared.shortcutItems?.removeAll { $0.type == QuickActionType.resumeVideo.rawValue }
    }
}
