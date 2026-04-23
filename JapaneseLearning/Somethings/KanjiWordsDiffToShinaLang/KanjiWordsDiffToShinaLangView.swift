//
//  KanjiWordsDiffToShinaLangView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import SwiftUI

struct KanjiWordsDiffToShinaLangView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @StateObject private var store = KanjiWordsStore()
    @State private var showRuby: Bool = false
    @State private var searchText: String = ""
    @State private var showSettingSheet = false

    var body: some View {
        ZStack {
            List {
                Section {
                    ForEach(filteredItems) { item in
                        WordListView(
                            item: item,
                            isExpanded: store.expandedIDs.contains(item.id ?? -1),
                            showRuby: showRuby,
                            store: store
                        )
                        .swipeActions {
                            NavigationLink {
                                KanjiWordsDiffToShinaLangDetailsView(item: item, store: store)
                            } label: {
                                Image(systemName: "highlighter")
                            }
                            .tint(.blue)
                        }
                    }
                } footer: {
                    if settingsStore.showKanjiWordsDiffToShinaLangListCount {
                        Text("件数：\(filteredItems.count)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "入力して検索")
            .animation(.snappy(duration: 0.2, extraBounce: 0), value: store.expandedIDs)
            .opacity(store.isReady ? 1 : 0)

            if store.isLoading {
                ProgressLoadingView()
            }
        }
        .navigationTitle("支那語に無い漢字")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink {
                        KanjiWordsDiffToShinaLangDetailsView(
                            item: KanjiWordsItem(
                                word: "",
                                ruby: "",
                                meaning: ""
                            ),
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
                    Divider()

                    Button {
                        showRuby.toggle()
                    } label: {
                        Label("発音を表示・隠す", systemImage: "eye")
                    }
                    Button {
                        if store.expandedIDs.count == store.KanjiWordsList.count {
                            store.collapseAll()
                        } else {
                            store.expandAll()
                        }
                    } label: {
                        Label("全て展開・折り畳む", systemImage: "chevron.up.chevron.down")
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
            if store.KanjiWordsList.isEmpty {
                await store.fetchAll()
            }
        }
    }

    var filteredItems: [KanjiWordsItem] {
        store.KanjiWordsList
            .filter { item in
                searchText.isEmpty || item.word.localizedCaseInsensitiveContains(searchText)
            }
    }
}

struct WordListView: View {
    let item: KanjiWordsItem
    let isExpanded: Bool
    let showRuby: Bool
    let store: KanjiWordsStore

    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: {
                    store.expandedIDs.contains(item.id ?? -1)
                },
                set: { _ in
                    store.toggleExpand(item.id ?? 8964)
                }
            )
        ) {
            Text(item.meaning)
                .font(.body)
                .foregroundStyle(.secondary)
        } label: {
            HStack {
                Text(item.word)
                    .font(.headline)
                
                if showRuby {
                    Text(item.ruby)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
    }
}


private struct SettingsSheetView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @ObservedObject var store: KanjiWordsStore

    var body: some View {
        @Bindable var settingsStoreBindable = settingsStore

        NavigationStack {
            Form {
                Section(header: Text("表示設定")) {
                    Toggle(isOn: $settingsStoreBindable.showKanjiWordsDiffToShinaLangListCount) {
                        VStack(alignment: .leading) {
                            Text("件数を表示")
                            Text("漢字単語リスト底に件数を表示する")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("漢字単語設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
