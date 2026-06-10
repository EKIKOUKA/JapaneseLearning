//
//  MediaProductsDetailsEditorView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/14.
//

import SwiftUI

struct MediaProductsDetailsEditorView: View {
    let item: MediaProductsItem
    let isNew: Bool // edit or add
    @ObservedObject var store: MediaProductsStore
    @Environment(\.dismiss) var dismiss

    @State private var title: String
    @State private var category: MediaCategory
    @State private var status: WatchStatus
    @State private var detailsURL: String
    @State private var memo: String

    init(item: MediaProductsItem, store: MediaProductsStore, isNew: Bool = false) {
        self.item = item
        self.store = store
        self.isNew = isNew
        _title = State(initialValue: item.title)
        _category = State(initialValue: item.category)
        _status = State(initialValue: item.status)
        _detailsURL = State(initialValue: item.detailsURL ?? "")
        _memo = State(initialValue: item.memo ?? "")
    }

    var body: some View {
        List {
            Section(header: Text("映像作品")) {
                TextField("タイトルを入力…", text: $title, axis: .vertical)
            }

            Section(header: Text("作品分類")) {
                Picker("作品分類", selection: $category) {
                    ForEach(MediaCategory.allCases) { category in
                        Text(category.displayName)
                            .tag(category)
                    }
                }
            }

            Section(header: Text("観る状態")) {
                Picker("観る状態", selection: $status) {
                    ForEach(WatchStatus.allCases) { status in
                        Text(status.displayName)
                            .tag(status)
                    }
                }
            }

            Section(header: Text("詳細リンク")) {
                TextField("詳細リンクを入力…", text: $detailsURL, axis: .vertical)
                    .lineLimit(2...)
            }

            Section(header: Text("メモ")) {
                TextField("メモを入力…", text: $memo, axis: .vertical)
                    .lineLimit(1...)
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveChanges()
                } label: {
                    Image(systemName: "checkmark")
                }
                .disabled(title.isWhitespaceOrNewLine || detailsURL.isWhitespaceOrNewLine)
            }
        }
        .navigationTitle(isNew ? "新規追加" : item.title)
    }

    private func saveChanges() {
        Task {
            let item = MediaProductsItem(
                id: isNew ? nil : item.id,
                title: title,
                category: category,
                status: status,
                detailsURL: detailsURL,
                memo: memo
            )

            if isNew {
                await store.MediaProductsAdd(item)
            } else {
                await store.MediaProductsUpdate(item)
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
