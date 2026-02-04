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
}

class QuickActionManager {
    static let shared = QuickActionManager()

    func updateResumeVideoAction(videoID: String, title: String, time: String) {
        updateShortcutItem(
            type: .resumeVideo,
            title: "続きから再生",
            subtitle: "\(time) ・ \(title)",
            iconName: "play.rectangle.fill",
            userInfo: ["videoID": videoID]
        )
    }

    func updateRecentGrammarAction(grammarID: String, title: String, level: String) {
        updateShortcutItem(
            type: .recentGrammar,
            title: "最近の文法",
            subtitle: title,
            iconName: "text.book.closed.fill",
            userInfo: ["grammarID": grammarID, "level": level]
        )
    }

    private func updateShortcutItem(type: QuickActionType, title: String, subtitle: String?, iconName: String, userInfo: [String: String]) {

        var existingItems = UIApplication.shared.shortcutItems ?? []

        let secureUserInfo: [String: NSSecureCoding] = userInfo.reduce(into: [:]) { result, element in
            result[element.key] = element.value as NSString
        }

        let icon = UIApplicationShortcutIcon(systemImageName: iconName)
        let newItem = UIMutableApplicationShortcutItem(
            type: type.rawValue,
            localizedTitle: title,
            localizedSubtitle: subtitle,
            icon: icon,
            userInfo: secureUserInfo
        )

        existingItems.removeAll { $0.type == type.rawValue }
        existingItems.append(newItem)

        // order
        existingItems.sort { (item1, item2) -> Bool in
            let priority: [String: Int] = [
                QuickActionType.recentGrammar.rawValue: 0,
                QuickActionType.resumeVideo.rawValue: 1
            ]
            return (priority[item1.type] ?? 0) < (priority[item2.type] ?? 0)
        }

        if existingItems.count > 4 {
            existingItems = Array(existingItems.prefix(4))
        }

        UIApplication.shared.shortcutItems = existingItems
    }

    func clearResumeVideo() {
        var items = UIApplication.shared.shortcutItems ?? []
            items.removeAll { $0.type == QuickActionType.resumeVideo.rawValue }
            UIApplication.shared.shortcutItems = items
    }
}
