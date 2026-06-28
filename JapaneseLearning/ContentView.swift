//
//  ContentView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppNavigationStore.self) private var navigationStore

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
                    Label("学習記録", systemImage: "chart.bar.xaxis")
                }
                .tag(1)

            SomethingsView()
                .tabItem {
                    Label("その他", systemImage: "books.vertical")
                }
                .tag(2)

            GrammarContentView()
                .tabItem {
                    Label("文法", systemImage: "book.pages")
                }
                .tag(3)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
