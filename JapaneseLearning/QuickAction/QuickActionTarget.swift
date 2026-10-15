//
//  QuickActionTarget.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/01/16.
//

import UIKit

enum QuickActionTarget: Hashable {
    case resumeVideo(id: String)

    var videoID: String {
        switch self {
            case .resumeVideo(let id): return id
        }
    }

    /// 削除済みのアクション種別や空 ID を、成功した操作として扱わない。
    init?(shortcutItem: UIApplicationShortcutItem) {
        guard shortcutItem.type == QuickActionType.resumeVideo.rawValue,
              let id = shortcutItem.userInfo?[QuickActionType.videoIDKey] as? String,
              !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        self = .resumeVideo(id: id)
    }
}
