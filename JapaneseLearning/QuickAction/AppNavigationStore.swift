//
//  AppNavigationStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/01/16.
//

import Foundation

struct VideoSheetDestination: Identifiable {
    let id: String
    let sourceID: String
    let dismissesToMiniPlayer: Bool
}

@MainActor
@Observable
final class AppNavigationStore {
    static let shared = AppNavigationStore()

    var quickActionTarget: QuickActionTarget?
    var selectedTab: Int = 0
    var videoTransitionSourceID: String?
    var presentedVideo: VideoSheetDestination?

    private init() {}

    /// 外部からの動画遷移はミニプレイヤーの遷移元を引き継がない。
    func resumeVideo(id: String) {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        selectedTab = 0
        videoTransitionSourceID = nil
        quickActionTarget = .resumeVideo(id: id)
    }

    func clearTarget() {
        quickActionTarget = nil
    }

}
