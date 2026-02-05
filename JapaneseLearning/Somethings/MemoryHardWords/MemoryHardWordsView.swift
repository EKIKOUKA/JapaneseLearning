//
//  MemoryHardWordsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import SwiftUI

struct MemoryHardWordsItem: Codable, Identifiable {
    let id: UUID
    var word: String
    var ruby: String
    var meaning: String
}

struct MemoryHardWordsListView: View {
    let item: MemoryHardWordsItem
    let isExpanded: Bool
    let showRuby: Bool
    let store: MemoryHardWordsStore

    var body: some View {

        VStack(alignment: .leading, spacing: 0) {

            HStack {
                Text(item.word)
                    .font(.headline)
                if showRuby {
                    Text(item.ruby)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .zIndex(1)
            .contentShape(Rectangle())
            .onTapGesture {
                store.toggleExpand(item.id)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(item.meaning)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(height: isExpanded ? nil : 0, alignment: .top)
            .clipped()
        }
    }
}

struct MemoryHardWordsView: View {

    @Environment(SettingsStore.self) private var settingsStore
    @StateObject private var store = MemoryHardWordsStore()
    @State private var showRuby: Bool = false
    @State private var searchText: String = ""
    @State private var showSettingSheet = false

    var body: some View {

        ZStack {

            List {

                Section {

                    ForEach(filteredItems) { item in
                        MemoryHardWordsListView(
                            item: item,
                            isExpanded: store.expandedIDs.contains(item.id),
                            showRuby: showRuby,
                            store: store
                        )
                        .swipeActions {
                            NavigationLink {
                                MemoryHardWordsDetailsView(item: item, store: store)
                            } label: {
                                Image(systemName: "highlighter")
                            }
                            .tint(.blue)
                        }
                    }
                } footer: {
                    if settingsStore.settings.showMemoryHardWordsListCount {
                        Text("件数：\(filteredItems.count)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .animation(.snappy(duration: 0.2, extraBounce: 0), value: store.expandedIDs)
            .searchable(text: $searchText, prompt: "入力して検索")

            if store.isLoading {
                ProgressLoadingView()
            }
        }
        .navigationTitle("覚えにくい単語")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink {
                        MemoryHardWordsDetailsView(
                            item: MemoryHardWordsItem(
                                id: UUID(),
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
                        if store.expandedIDs.count == store.MemoryHardWordsList.count {
                            store.collapseAll()
                        } else {
                            store.expandAll()
                        }
                    } label: {
                        Label("全部展開・折りたたむ", systemImage: "chevron.up.chevron.down")
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
            if store.MemoryHardWordsList.isEmpty {
                await store.fetchAll()
            }
        }
    }

    var filteredItems: [MemoryHardWordsItem] {
        store.MemoryHardWordsList
            .filter { item in
                searchText.isEmpty || item.word.localizedCaseInsensitiveContains(searchText)
            }
    }
}


private struct SettingsSheetView: View {

    @Environment(SettingsStore.self) private var settingsStore
    @ObservedObject var store: MemoryHardWordsStore

    var body: some View {
        @Bindable var settingsStoreBindable = settingsStore

        NavigationStack {

            Form {

                Section(header: Text("表示設定")) {

                    Toggle(isOn: $settingsStoreBindable.settings.showMemoryHardWordsListCount) {
                        VStack(alignment: .leading) {
                            Text("件数を表示")
                            Text("覚えにくい単語リスト底に件数を表示する")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("覚えにくい単語設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MemoryHardWordsView()
}
