//
//  GrammarDetailsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import SwiftUI

struct GrammarDetailsView: View {
    let item: GrammarItem
    @ObservedObject var store: GrammarStore
    @Environment(SettingsStore.self) private var settingsStore

    @State private var isReady = false

    @State private var meaningHeight: CGFloat = .zero
    @State private var connectionHeight: CGFloat = .zero
    @State private var notesHeight: CGFloat = .zero
    @State private var examplesHeight: CGFloat = .zero

    var body: some View {
        VStack {
            List {
                Section(header: Text("説明")) {
                    SelectableUITextView(text: item.meaning, height: $meaningHeight)
                        .frame(height: meaningHeight)
                }

                if item.connection != nil, item.connection != "" {
                    Section(header: Text("接続")) {
                        SelectableUITextView(text: item.connection ?? "", height: $connectionHeight)
                            .frame(height: connectionHeight)
                    }
                }

                if item.notes != nil, item.notes != "" {
                    Section(header: Text("メモ")) {
                        SelectableUITextView(text: item.notes ?? "", height: $notesHeight)
                            .frame(height: notesHeight)
                    }
                }

                Section(header: Text("例文")) {
                    SelectableUITextView(text: item.examples, height: $examplesHeight)
                        .frame(height: examplesHeight)
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
        .onAppear {
            isReady = false

            QuickActionManager.shared.updateRecentGrammarAction(
                grammarID: String(item.id),
                title: item.title,
                level: item.level
            )

            DispatchQueue.main.async {
                withAnimation(.easeIn(duration: 0.1)) {
                    isReady = true
                }
            }
        }
    }
}
