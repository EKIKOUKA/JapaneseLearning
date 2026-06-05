//
//  MemoryHardWordsDetailsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import SwiftUI

struct MemoryHardWordsDetailsView: View {
    let item: MemoryHardWordsItem
    let isNew: Bool // edit or add
    @ObservedObject var store: MemoryHardWordsStore
    @Environment(\.dismiss) var dismiss

    @State private var word: String
    @State private var ruby: String
    @State private var meaning: String

    init(item: MemoryHardWordsItem, store: MemoryHardWordsStore, isNew: Bool = false) {
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
                Section(header: Text("単語")) {
                    TextField("単語を入力…", text: $word)
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
                await store.MemoryHardWordsAdd(
                    MemoryHardWordsItem(
                        word: word,
                        ruby: ruby,
                        meaning: meaning
                    )
                )
            } else {
                await store.MemoryHardWordsUpdate(
                    MemoryHardWordsItem(
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
