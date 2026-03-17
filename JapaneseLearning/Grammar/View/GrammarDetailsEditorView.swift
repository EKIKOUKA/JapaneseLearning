//
//  GrammarDetailsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import SwiftUI

struct GrammarDetailsEditorView: View {
    let item: GrammarItem
    let isNew: Bool // edit or add
    @ObservedObject var store: GrammarStore
    @Environment(\.dismiss) var dismiss

    @State private var meaning: String
    @State private var connection: String
    @State private var notes: String
    @State private var examples: String
    @State private var title: String

    init(item: GrammarItem, store: GrammarStore, isNew: Bool = false) {
        self.item = item
        self.store = store
        self.isNew = isNew
        _meaning = State(initialValue: item.meaning)
        _connection = State(initialValue: item.connection ?? "")
        _notes = State(initialValue: item.notes ?? "")
        _examples = State(initialValue: item.examples)
        _title = State(initialValue: item.title)
    }
    
    var body: some View {
        VStack {
            List {
                Section(header: Text("文型")) {
                    ZStack(alignment: .topLeading) {
                        if title.isEmpty {
                            Text("文型を入力…")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                        }

                        TextEditor(text: $title)
                            .frame(minHeight: 39)
                    }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 2))

                Section(header: Text("説明")) {
//                        TextEditor(text: $meaning)
//                            .frame(minHeight: 54)
//                            .padding(5)
//                            .background(Color(.red))
//                            .cornerRadius(8)
//                            .padding(.bottom, 15)
                    ZStack(alignment: .topLeading) {
                        if meaning.isEmpty {
                            Text("説明を入力…")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $meaning)
                            .frame(minHeight: 54)
                    }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 2))

                Section(header: Text("接続")) {
//                        TextEditor(text: $connection)
//                            .frame(minHeight: 54)
//                            .padding(5)
//                            .background(Color(.systemGray6))
//                            .cornerRadius(8)
//                            .padding(.bottom, 15)
                    ZStack(alignment: .topLeading) {
                        if connection.isEmpty {
                            Text("接続を入力…")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $connection)
                            .frame(minHeight: 54)
                    }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 2))

                Section(header: Text("メモ")) {
//                        TextEditor(text: $notes)
//                            .frame(minHeight: 54)
//                            .padding(5)
//                            .background(Color(.systemGray6))
//                            .cornerRadius(8)
//                            .padding(.bottom, 15)
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("メモを入力…")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $notes)
                            .frame(minHeight: 62)
                    }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 2))

                Section(header: Text("例文")) {
//                        TextEditor(text: $examples)
//                            .frame(minHeight: 150)
//                            .padding(5)
//                            .background(Color(.systemGray6))
//                            .cornerRadius(8)

                    ZStack(alignment: .topLeading) {
                        if examples.isEmpty {
                            Text("例文を入力…")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $examples)
                            .frame(minHeight: 150)
                    }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 2))
            }
        }
        .navigationTitle(isNew ? "新規追加" : item.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saveChanges()
                } label: {
                    Image(systemName: "checkmark") // checkmark.seal checkmark.circle
//                            .font(.title2)
//                        Image(systemName: "checkmark.app")
//                        Image(systemName: "checkmark.shield")
                }
            }
        }
    }

    private func saveChanges() {
        if title.isEmpty {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        let grammar_item = GrammarItem(
            id: item.id,
            title: title,
            level: item.level,
            meaning: meaning.isEmpty ? "" : meaning,
            connection: connection.isEmpty ? "" : connection,
            notes: notes.isEmpty ? "" : notes,
            examples: examples.isEmpty ? "" : examples,
            isImportant: item.isImportant,
            isMarked: item.isMarked
        )

        Task {
            if isNew {
                await store.grammarAdd(grammar_item)
            } else {
                await store.grammarUpdate(item.id, updatedItem: grammar_item)
            }

            await MainActor.run {
                withAnimation {
                    dismiss()
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}
