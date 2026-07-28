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

@Observable
class AppNavigationStore {
    static let shared = AppNavigationStore()

    var quickActionTarget: QuickActionTarget?
    var selectedTab: Int = 0
    var videoTransitionSourceID: String?
    var presentedVideo: VideoSheetDestination?

    private init() {}

    func clearTarget() {
        quickActionTarget = nil
    }

}
