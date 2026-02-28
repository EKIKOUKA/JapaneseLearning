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

            Section("映像作品") {
                ZStack(alignment: .topLeading) {
                    if title.isEmpty {
                        Text("タイトルを入力…")
                            .foregroundColor(.gray)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                    }

                    TextEditor(text: $title)
                }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 5))

            Section("作品分類") {
                Picker("作品分類", selection: $category) {
                    ForEach(MediaCategory.allCases) { category in
                        Text(category.displayName)
                            .tag(category)
                    }
                }
            }

            Section("観る状態") {
                Picker("観る状態", selection: $status) {
                    ForEach(WatchStatus.allCases) { status in
                        Text(status.displayName)
                            .tag(status)
                    }
                }
            }

            Section("詳細リンク") {
                ZStack(alignment: .topLeading) {
                    if detailsURL.isEmpty {
                        Text("詳細リンクを入力…")
                            .foregroundColor(.gray)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                    }

                    TextEditor(text: $detailsURL)
                        .frame(minHeight: 62)
                }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 5))

            Section("メモ") {
                ZStack(alignment: .topLeading) {
                    if memo.isEmpty {
                        Text("メモを入力…")
                            .foregroundColor(.gray)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                    }

                    TextEditor(text: $memo)
                }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 5))
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saveChanges()
                } label: {
                    Image(systemName: "checkmark")
                }
            }
        }
        .navigationTitle(isNew ? "新規追加" : item.title)
    }

    private func saveChanges() {
        if title.isEmpty {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        Task {
            if isNew {
                await store.MediaProductsAdd(
                    MediaProductsItem(
                        title: title,
                        category: category,
                        status: status,
                        detailsURL: detailsURL,
                        memo: memo
                    )
                )
            } else {
                await store.MediaProductsUpdate(
                    MediaProductsItem(
                        id: item.id,
                        title: title,
                        category: category,
                        status: status,
                        detailsURL: detailsURL,
                        memo: memo
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
