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
    @ObservedObject var store: IdiomsStore
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
            }
        }
    }

    private func saveChanges() {
        if word.isEmpty {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        Task {
            if isNew {
                await store.IdiomsAdd(
                    IdiomsItem(
                        word: word,
                        ruby: ruby,
                        meaning: meaning
                    )
                )
            } else {
                await store.IdiomsUpdate(
                    IdiomsItem(
                        id: item.id,
                        word: word,
                        ruby: ruby,
                        meaning: meaning
                    )
                )
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
