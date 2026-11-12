//
//  IdiomsDetailsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import SwiftUI

struct IdiomsDetailsView: View {
    let item: IdiomsItem
    let isNew: Bool // edit or add
    @State var store: IdiomsStore
    @Environment(\.dismiss) var dismiss

    @State private var word: String
    @State private var ruby: String
    @State private var meaning: String

    init(item: IdiomsItem, store: IdiomsStore, isNew: Bool = false) {
        self.item = item
        self.store = store
        self.isNew = isNew
        _word = State(initialValue: item.word)
        _ruby = State(initialValue: item.ruby)
        _meaning = State(initialValue: item.meaning)
    }

    var body: some View {
        VStack {
            List {
                Section(header: Text("句")) {
                    TextField("句を入力…", text: $word)
                }
                Section(header: Text("発音")) {
                    TextField("発音を入力…", text: $ruby)
                }
                Section(header: Text("説明")) {
                    TextField("説明を入力…", text: $meaning, axis: .vertical)
                        .lineLimit(2...)
                }
            }
        }
        .navigationTitle(isNew ? "新規追加" : item.word)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    saveChanges()
                }) {
                    Image(systemName: "checkmark")
                }
                .disabled(word.isWhitespaceOrNewLine || ruby.isWhitespaceOrNewLine)
            }
        }
    }

    private func saveChanges() {
        Task {
            let item = IdiomsItem(
                id: isNew ? nil : item.id,
                word: word,
                ruby: ruby,
                meaning: meaning
            )

            if isNew {
                await store.IdiomsAdd(item)
            } else {
                await store.IdiomsUpdate(item)
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
