//
//  QuickActionTarget.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/01/16.
//

import UIKit

enum QuickActionTarget: Hashable {
    case lastGrammar(id: Int, level: String)
    case resumeVideo(id: String)

    var videoID: String? {
        switch self {
            case .resumeVideo(let id): return id
            case .lastGrammar: return nil
        }
    }

    /// 対応するアクションだけを受け付け、壊れた識別子は遷移に使用しない。
    init?(shortcutItem: UIApplicationShortcutItem) {
        switch shortcutItem.type {
            case QuickActionType.resumeVideo.rawValue:
                guard let id = shortcutItem.userInfo?[QuickActionType.videoIDKey] as? String,
                      !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                self = .resumeVideo(id: id)
            case QuickActionType.recentGrammar.rawValue:
                guard let rawID = shortcutItem.userInfo?["grammarID"] as? String,
                      let id = Int(rawID),
                      let level = shortcutItem.userInfo?["level"] as? String,
                      !level.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                self = .lastGrammar(id: id, level: level)
            default: return nil
        }
    }
}
