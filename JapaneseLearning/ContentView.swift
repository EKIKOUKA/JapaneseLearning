//
//  ContentView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import SwiftUI

struct ContentView: View {
    @Environment(VideoStore.self) private var videoStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppNavigationStore.self) private var navigationStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var playerVM = PlayerViewManager()
    @Namespace private var transitionNamespace

    var body: some View {
        @Bindable var nav = navigationStore

        TabView(selection: $nav.selectedTab) {
            VideoContentView()
                .tabItem {
                    Label("シャドーイング", systemImage: "shadow")
                }
                .tag(0)

            AchieveSystemView()
                .tabItem {
                    Label("　学習記録　", systemImage: "chart.bar.xaxis")
                }
                .tag(1)

            SomethingsView()
                .tabItem {
                    Label("　　その他　　", systemImage: "books.vertical")
                }
                .tag(2)

            GrammarContentView()
                .tabItem {
                    Label("　　文法　　", systemImage: "book.pages")
                }
                .tag(3)
        }
        .environment(playerVM)
        .environment(\.transitionNamespace, transitionNamespace)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: playerVM.hasActivePlayback && !playerVM.isDetailVisible) {
            ShadowingMiniPlayerView()
        }
        .onAppear {
            playerVM.inject(videoStore: videoStore, settingsStore: settingsStore)
        }
        .onChange(of: scenePhase, initial: false) {
            Task {
                if scenePhase == .background {
                    await playerVM.saveCurrentProgress()
                }
            }
        }
        .onOpenURL { url in
            guard url.scheme == "japaneselearning",
                  url.host == "video",
                  let videoID = url.pathComponents.dropFirst().first,
                  !videoID.isEmpty else {
                return
            }

            navigationStore.selectedTab = 0
            navigationStore.quickActionTarget = .resumeVideo(id: videoID)
        }
    }
}
