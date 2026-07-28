//
//  ElegantSentenceDetailsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import SwiftUI

struct ElegantSentenceDetailsView: View {
    let item: ElegantSentenceItem
    let isNew: Bool // edit or add
    @Environment(\.dismiss) var dismiss
    @State var store: ElegantSentenceStore

    @State private var sentence: String

    init(item: ElegantSentenceItem, store: ElegantSentenceStore, isNew: Bool = false) {
        self.item = item
        self.store = store
        self.isNew = isNew
        _sentence = State(initialValue: item.sentence)
    }

    var body: some View {
        VStack {
            List {
                Section {
                    TextField("文を入力…", text: $sentence, axis: .vertical)
                        .lineLimit(2...)
                }
            }
        }
        .navigationTitle(isNew ? "新規追加" : "編集")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    saveChanges()
                }) {
                    Image(systemName: "checkmark")
                }
                .disabled(sentence.isWhitespaceOrNewLine)
            }
        }
    }

    private func saveChanges() {
        Task {
            await MainActor.run {
                withAnimation {
                    dismiss()
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }

            let item = ElegantSentenceItem(
                id: isNew ? nil : item.id,
                sentence: sentence
            )

            if isNew {
                await store.ElegantSentenceAdd(item)
            } else {
                await store.ElegantSentenceUpdate(item)
            }

        }
    }
}
