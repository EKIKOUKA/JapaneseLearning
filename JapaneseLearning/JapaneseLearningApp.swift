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
        requestPushPermission()

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

    private func requestPushPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            print("Permission:", granted)
        }

        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
