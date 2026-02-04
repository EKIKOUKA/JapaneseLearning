//
//  AppScene.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/20.
//

import SwiftUI

let appNaviStoreShared = AppNavigationStore.shared

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
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
        let grammarID = item.userInfo?["grammarID"] as? String,
        let uuid = UUID(uuidString: grammarID),
        let level = item.userInfo?["level"] as? String {
            appNaviStoreShared.selectedTab = 2
            appNaviStoreShared.quickActionTarget = .lastGrammar(id: uuid, level: level)
    }
}
