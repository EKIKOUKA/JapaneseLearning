//
//  AppScene.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/20.
//

import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        QuickActionManager.shared.removeObsoleteActions()
        UNUserNotificationCenter.current().delegate = self

        Task {
            await requestPushPermission()
        }

        return true
    }

    @MainActor
    private func requestPushPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            print("Permission:", granted)
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            print("Push authorization failed: \(error)")
        }
    }

    // 🔔 使用者點擊通知
    @MainActor
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let videoId = userInfo["video_id"] as? String {
            AppNavigationStore.shared.resumeVideo(id: videoId)
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

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let shortcutItem = connectionOptions.shortcutItem {
            // 画面生成前でも遷移先を保持する。View 側は初期値も受け取り、固定時間の待機を不要にする。
            handleShortcut(shortcutItem)
        }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(handleShortcut(shortcutItem))
    }

    @discardableResult
    private func handleShortcut(_ item: UIApplicationShortcutItem) -> Bool {
        guard let target = QuickActionTarget(shortcutItem: item) else { return false }
        AppNavigationStore.shared.resumeVideo(id: target.videoID)
        return true
    }
}
