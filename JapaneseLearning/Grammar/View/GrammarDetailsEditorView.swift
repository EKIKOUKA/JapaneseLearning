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
                    TextField("文型を入力…", text: $title)
                }
                Section(header: Text("説明")) {
                    TextField("説明を入力…", text: $meaning, axis: .vertical)
                        .lineLimit(2...)
                }
                Section(header: Text("接続")) {
                    TextField("接続を入力…", text: $connection, axis: .vertical)
                        .lineLimit(2...)
                }
                Section(header: Text("メモ")) {
                    TextField("メモを入力…", text: $notes, axis: .vertical)
                        .lineLimit(2...)
                }
                Section(header: Text("例文")) {
                    TextField("例文を入力…", text: $examples, axis: .vertical)
                        .lineLimit(5...)
                }
            }
        }
        .navigationTitle(isNew ? "新規追加" : item.title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveChanges()
                } label: {
                    Image(systemName: "checkmark")
                }
                .disabled(title.isWhitespaceOrNewLine || meaning.isWhitespaceOrNewLine || examples.isWhitespaceOrNewLine)
            }
        }
        .toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)
    }

    private func saveChanges() {
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
                await store.grammarUpdate(grammar_item)
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
