//
//  SampleRubyWordsDetailsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import SwiftUI

struct SampleRubyWordsDetailsView: View {
    let item: SampleRubyWordsItem
    let isNew: Bool // edit or add
    @ObservedObject var store: SampleRubyWordsStore
    @Environment(\.dismiss) var dismiss

    @State private var word: String
    @State private var ruby: String
    @State private var meaning: String

    init(item: SampleRubyWordsItem, store: SampleRubyWordsStore, isNew: Bool = false) {
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
                    ZStack(alignment: .topLeading) {
                        if word.isEmpty {
                            Text("単語を入力…")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                        }

                        TextEditor(text: $word)
                            .frame(height: 39)
                    }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 2))

                Section(header: Text("発音")) {
                    ZStack(alignment: .topLeading) {
                        if ruby.isEmpty {
                            Text("発音を入力…")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $ruby)
                            .frame(height: 39)
                    }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 2))

                Section(header: Text("説明")) {
                    ZStack(alignment: .topLeading) {
                        if meaning.isEmpty {
                            Text("説明を入力…")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $meaning)
                            .frame(minHeight: 39)
                    }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 2))
            }
        }
        .navigationTitle(isNew ? "新規追加" : item.word)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
                await store.SampleRubyWordsAdd(
                    SampleRubyWordsItem(
                        word: word,
                        ruby: ruby,
                        meaning: meaning
                    )
                )
            } else {
                await store.SampleRubyWordsUpdate(
                    SampleRubyWordsItem(
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
