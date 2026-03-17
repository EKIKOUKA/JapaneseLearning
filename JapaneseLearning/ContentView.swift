//
//  ContentView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppNavigationStore.self) private var navigationStore
    @Environment(VideoStore.self) private var videoStore
    @StateObject var grammarStore = GrammarStore()
    @State private var videoPath = NavigationPath()
    @State private var grammarPath = NavigationPath()
    @State private var resolvedVideo: VideoItem?

    var body: some View {
        @Bindable var nav = navigationStore

        TabView(selection: $nav.selectedTab) {
            NavigationStack(path: $videoPath) {
                VideoListView()
                .navigationDestination(for: QuickActionTarget.self) { target in
                    if case .resumeVideo(let id) = target {
                        VideoContentView(videoID: id)
                    }
                }
            }
            .tabItem {
                Label("　シャドーイング　", systemImage: "shadow")
            }
            .tag(0)

            SomethingsView()
            .tabItem {
                Label("　その他　", systemImage: "books.vertical")
            }
            .tag(1)

            NavigationStack(path: $grammarPath) {
                GrammarNaviView(store: grammarStore)
                    .navigationDestination(for: GrammarNavDestination.self) { destination in
                        switch destination {
                            case .list(let level, let title):
                                GrammarListView(level: level, title: title, store: grammarStore)
                            case .details(let id, let level):
                                GrammarDetailLoader(id: id, level: level, store: grammarStore)
                            }
                    }
                    .navigationDestination(for: QuickActionTarget.self) { target in
                        if case .lastGrammar(let id, let level) = target {
                            GrammarDetailLoader(id: id, level: level, store: grammarStore)
                        }
                    }
            }
            .tabItem {
                Label("　文法　", systemImage: "book.pages") //は米国有事
            }
            .tag(2)
        }
        .onChange(of: navigationStore.quickActionTarget) { _, target in
            guard let target = target else { return }

            if case .lastGrammar(let id, let level) = target {
                let item = GrammarAllLevels.grammarList.first(where: { $0.level == level })
                let title = item?.title ?? "\(level) 文法"
                grammarPath = NavigationPath()
                grammarPath.append(GrammarNavDestination.list(level: level, title: title))
                grammarPath.append(GrammarNavDestination.details(id: id, level: level))
            } else if case .resumeVideo = target {
                videoPath.removeLast(videoPath.count)
                videoPath.append(target)
            }

            navigationStore.clearTarget()
        }
    }
}
