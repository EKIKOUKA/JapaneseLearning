//
//  AppNavigationStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/01/16.
//

import Foundation

@Observable
class AppNavigationStore {

    static let shared = AppNavigationStore()

    var quickActionTarget: QuickActionTarget?
    var selectedTab: Int = 0

    private init() {}

    func clearTarget() {
        quickActionTarget = nil
    }
}
