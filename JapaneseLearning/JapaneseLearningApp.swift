//
//  JapaneseLearningApp.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import SwiftUI
import AVFoundation

@main
struct JapaneseLearningApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var navigationStore = AppNavigationStore.shared
    @State private var videoStore = VideoStore()
    @State private var settingsStore = SettingsStore()
    @State private var appleAccountStore = AppleAccountStore()
    @State private var apnsTokenStore = APNsTokenStore.shared

    init() {
        if #available(iOS 26.0, *) {
            AVPlayer.isObservationEnabled = true
        }
        URLCache.shared.diskCapacity = 0
        URLCache.shared.memoryCapacity = 0
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settingsStore)
                .environment(navigationStore)
                .environment(videoStore)
                .environment(appleAccountStore)
                .task(id: appleAccountStore.userID) {
                    await videoStore.accountChanged(to: appleAccountStore.userID)
                }
                .task(id: apnsTokenStore.token) {
                    await appleAccountStore.syncAPNsDeviceToken()
                }
        }
    }
}
