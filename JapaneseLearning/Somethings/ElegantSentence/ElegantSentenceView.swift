//
//  ElegantSentenceView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import SwiftUI

struct ElegantSentenceView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @StateObject var store = ElegantSentenceStore()
    @State private var searchText = ""
    @State private var showSettingSheet = false

    var body: some View {
        VStack {
            if store.isLoading {
                ProgressLoadingView()
            } else {
                List {
                    Section {
                        ForEach(filteredItems, id: \.self) { index in
                            let item = $store.ElegantSentenceList[index]

                            HStack {
                                SelectableUITextView(
                                    text: store.ElegantSentenceList[index].sentence,
                                    height: item.height
                                )
                                .frame(height: store.ElegantSentenceList[index].height)
                            }
                            .swipeActions {
                                NavigationLink {
                                    ElegantSentenceDetailsView(item: store.ElegantSentenceList[index], store: store)
                                } label: {
                                    Image(systemName: "highlighter")
                                }
                                .tint(.blue)
                            }
                        }
                    } footer: {
                        if settingsStore.showElegantSentenceListCount {
                            Text("件数：\(filteredItems.count)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "入力して検索")
                .opacity(store.isLoading ? 0 : 1)
                .opacity(store.isReady ? 1 : 0)
            }
        }
        .navigationTitle("国語美文")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink {
                        ElegantSentenceDetailsView(
                            item: ElegantSentenceItem(sentence: ""),
                            store: store,
                            isNew: true
                        )
                    } label: {
                        Label("新規追加", systemImage: "plus")
                    }
                    Divider()

                    Button {
                        showSettingSheet = true
                    } label: {
                        Label("表示設定", systemImage: "gear")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showSettingSheet) {
            SettingsSheetView(store: store)
                .presentationDetents([.medium])
        }
        .task {
            if store.ElegantSentenceList.isEmpty {
                await store.fetchAll()
            }
        }
    }

    var filteredItems: [Int] {
        store.ElegantSentenceList.indices.filter { index in
            searchText.isEmpty || store.ElegantSentenceList[index].sentence.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private struct SettingsSheetView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @ObservedObject var store: ElegantSentenceStore

    var body: some View {
        @Bindable var settingsStoreBindable = settingsStore
        NavigationStack {
            Form {
                Section(header: Text("表示設定")) {
                    Toggle(isOn: $settingsStoreBindable.showElegantSentenceListCount) {
                        VStack(alignment: .leading) {
                            Text("件数を表示")
                            Text("国語美文リスト底に件数を表示する")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("国語美文設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
