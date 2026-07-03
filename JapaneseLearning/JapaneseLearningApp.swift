//
//  JapaneseLearningApp.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import SwiftUI

@main
struct JapaneseLearningApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var navigationStore = AppNavigationStore.shared
    @State private var videoStore = VideoStore()
    @State private var settingsStore = SettingsStore()

    init() {
        URLCache.shared.diskCapacity = 0
        URLCache.shared.memoryCapacity = 0
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settingsStore)
                .environment(navigationStore)
                .environment(videoStore)
        }
    }
}
