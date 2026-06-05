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
    @ObservedObject var store: ElegantSentenceStore
    @Environment(\.dismiss) var dismiss

    @State private var sentence: String
    @State private var sentenceHeight: CGFloat = .zero

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
                .listRowInsets(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 3))
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
            }
        }
    }

    private func saveChanges() {
        if sentence.isEmpty {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        Task {
            if isNew {
                await store.ElegantSentenceAdd(
                    ElegantSentenceItem(
                        sentence: sentence
                    )
                )
            } else {
                await store.ElegantSentenceUpdate(
                    ElegantSentenceItem(
                        id: item.id,
                        sentence: sentence
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
