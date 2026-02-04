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

    @State private var meaningHeight: CGFloat = .zero
    @State private var connectionHeight: CGFloat = .zero
    @State private var notesHeight: CGFloat = .zero
    @State private var examplesHeight: CGFloat = .zero

    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {

        VStack {

            List {

                Section(header: Text("説明")) {
                    //                Text("意味")
                    //                    .padding(.horizontal, 15)
                    //                    .padding(.vertical, 2)
                    //                    .background(Color.orange)
                    //                    .cornerRadius(5)
                    SelectableUITextView(text: item.meaning, height: $meaningHeight)
                        .frame(height: meaningHeight)
//                        .padding(.bottom, 20)
                }

                if item.connection != nil, item.connection != "" {
                    Section(header: Text("接続")) {
//                        Text("接続")
//                            .padding(.horizontal, 15)
//                            .padding(.vertical, 2)
//                            .background(Color.orange)
//                            .cornerRadius(5)
                        SelectableUITextView(text: item.connection ?? "", height: $connectionHeight)
                            .frame(height: connectionHeight)
//                            .padding(.bottom, 20)
                    }
                }

                if item.notes != nil, item.notes != "" {
                    Section(header: Text("メモ")) {
//                            Text("メモ")
//                                .padding(.horizontal, 15)
//                                .padding(.vertical, 2)
//                                .background(Color.orange)
//                                .cornerRadius(5)
                        SelectableUITextView(text: item.notes ?? "", height: $notesHeight)
                            .frame(height: notesHeight)
//                            .padding(.bottom, 20)
                    }
                }

                Section(header: Text("例文")) {
//                        Text("例文")
//                            .padding(.horizontal, 15)
//                            .padding(.vertical, 2)
//                            .background(Color.orange)
//                            .cornerRadius(5)
                    SelectableUITextView(text: item.examples, height: $examplesHeight)
                        .frame(height: examplesHeight)
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle(item.title)
        .toolbar {
            if settingsStore.settings.showGrammarEditorButton {
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
            QuickActionManager.shared.updateRecentGrammarAction(grammarID: item.id.uuidString, title: item.title, level: item.level)
        }
    }
}
