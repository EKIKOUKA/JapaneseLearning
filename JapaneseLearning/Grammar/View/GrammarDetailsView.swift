//
//  GrammarDetailsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import SwiftUI

struct GrammarDetailsView: View {
    let item: GrammarItem
    @State var store: GrammarStore
    @Environment(SettingsStore.self) private var settingsStore
    @State private var isReady = false

    var body: some View {
        VStack {
            List {
                Section(header: Text("説明")) {
                    Text(item.meaning)
                        .textSelection(.enabled)
                        .font(.system(size: 19))
                }
                if item.connection != nil, item.connection != "" {
                    Section(header: Text("接続")) {
                        Text(item.connection ?? "")
                            .textSelection(.enabled)
                            .font(.system(size: 19))
                    }
                }
                if item.notes != nil, item.notes != "" {
                    Section(header: Text("メモ")) {
                        Text(item.notes ?? "")
                            .textSelection(.enabled)
                            .font(.system(size: 19))
                    }
                }
                Section(header: Text("例文")) {
                    Text(item.examples)
                        .textSelection(.enabled)
                        .font(.system(size: 19))
                }
            }
            .listStyle(.insetGrouped)
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .navigationTitle(item.title)
        .opacity(isReady ? 1 : 0)
        .animation(.easeIn(duration: 0.25), value: isReady)
        .toolbar {
            if settingsStore.showGrammarEditorButton {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        GrammarDetailsEditorView(item: item, store: store, isNew: false)
                    } label: {
                        Image(systemName: "highlighter")
                    }
                }
            }
        }
        .toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)
        .task {
            isReady = false

            QuickActionManager.shared.updateRecentGrammarAction(
                grammarID: String(item.id),
                title: item.title,
                level: item.level
            )

            withAnimation(.easeIn(duration: 0.15)) {
                isReady = true
            }
        }
    }
}
