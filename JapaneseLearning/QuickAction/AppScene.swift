//
//  AppScene.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/20.
//

import SwiftUI
import UserNotifications

let appNaviStoreShared = AppNavigationStore.shared

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            if shortcutItem.type == QuickActionType.resumeVideo.rawValue {
                appNaviStoreShared.selectedTab = 0
            } else if shortcutItem.type == QuickActionType.recentGrammar.rawValue {
                appNaviStoreShared.selectedTab = 2
            }
        }

        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }


    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // 🔔 使用者點擊通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let videoId = userInfo["video_id"] as? String {
            DispatchQueue.main.async {
                appNaviStoreShared.selectedTab = 0
                appNaviStoreShared.quickActionTarget = .resumeVideo(id: videoId)
            }
        }

        completionHandler()
    }

    // 🔔 前景時收到通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }


    // 🔹 推播成功取得 token
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("DEVICE TOKEN:")
        print(token)
        // TODO: 傳到你的 server
    }

    // 🔹 推播失敗
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Push 註冊失敗:", error)
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let shortcutItem = connectionOptions.shortcutItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                handleShortcut(shortcutItem)
            }
        }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleShortcut(shortcutItem)
        completionHandler(true)
    }
}

func handleShortcut(_ item: UIApplicationShortcutItem) {
    if item.type == QuickActionType.resumeVideo.rawValue,
       let videoID = item.userInfo?["videoID"] as? String {
           appNaviStoreShared.selectedTab = 0
           appNaviStoreShared.quickActionTarget = .resumeVideo(id: videoID)
    } else if item.type == QuickActionType.recentGrammar.rawValue,
        let grammarIDString = item.userInfo?["grammarID"] as? String,
        let grammarID = Int(grammarIDString),
        let level = item.userInfo?["level"] as? String {
            appNaviStoreShared.selectedTab = 2
            appNaviStoreShared.quickActionTarget = .lastGrammar(id: grammarID, level: level)
    }
}
