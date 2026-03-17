//
//  MediaProductsListView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/14.
//

import SwiftUI

struct MediaProductsListView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @StateObject var store = MediaProductsStore()

    @State private var searchText = ""
    @State private var selectedCategory: MediaCategory = .drama
    @State private var showSettingSheet = false

    @State private var sortOrder: MediaProductsSortOrder = .createdAt
    @State private var selectedStatus: WatchStatus = .watched
    var isSearching: Bool {
        !searchText.isEmpty
    }

    var body: some View {
        VStack {
            if store.isLoading {
                ProgressLoadingView()
            } else {
                NavigationStack {

                    VStack {

                        List {

                            Section {

                                ForEach(filteredItems) { item in

                                    NavigationLink(destination: MediaProductsDetailsView(item: item, store: store)) {
                                        Text(item.title)
                                    }
                                    .swipeActions {
                                        NavigationLink {
                                            MediaProductsDetailsEditorView(item: item, store: store)
                                        } label: {
                                            Image(systemName: "highlighter")
                                        }
                                        .tint(.blue)
                                    }
                                }
                                if filteredItems.isEmpty {
                                    Text("空っぽい")
                                        .foregroundStyle(.secondary)
                                }
                            } header: {
                                if searchText.isEmpty {
                                    Picker("Category", selection: $selectedCategory) {
                                        ForEach(MediaCategory.allCases) { category in
                                            Text(category.displayName)
                                                .tag(category)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .listRowInsets(EdgeInsets(
                                        top: 10,
                                        leading: 0,
                                        bottom: 15,
                                        trailing: 0
                                    ))
                                }
                            } footer: {
                                if settingsStore.showMediaProductsListCount {
                                    Text("件数：\(filteredItems.count)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .opacity(store.isLoading ? 0 : 1)
                        .opacity(store.isReady ? 1 : 0)
                        .animation(.default, value: selectedStatus)
                        .animation(.default, value: sortOrder)
                        .animation(.easeIn(duration: 0.15), value: store.isReady)
                        .searchable(text: $searchText, prompt: "入力して検索")
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            NavigationLink {
                                MediaProductsDetailsEditorView(
                                    item: MediaProductsItem(
                                        title: "",
                                        category: selectedCategory,
                                        status: selectedStatus,
                                        detailsURL: "",
                                        memo: ""
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

                            Menu {
                                Picker("表示順序", selection: $sortOrder) {
                                    ForEach(MediaProductsSortOrder.allCases) { order in
                                        Text(order.displayName)
                                            .tag(order)
                                    }
                                }
                            } label: {
                                Label("表示順序", systemImage: "arrow.up.arrow.down")
                            }

                            Menu {
                                Picker("", selection: $selectedStatus) {
                                    ForEach(WatchStatus.allCases) { status in
                                        Text(status.displayName)
                                            .tag(status)
                                    }
                                }
                            } label: {
                                Label("表示状態", systemImage: "line.3.horizontal.decrease.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
                .onChange(of: searchText) { _, newValue in
                    guard !newValue.isEmpty else { return }

                    if let first = store.MediaProductsList.first(where: {
                        $0.title.localizedCaseInsensitiveContains(newValue)
                    }) {
                        selectedCategory = first.category
                    }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showSettingSheet) {
            SettingsSheetView(store: store)
                .presentationDetents([.medium])
        }
        .navigationTitle("映像作品リスト")
        .task {
            if store.MediaProductsList.isEmpty {
                await store.fetchAll()
            }
        }
    }

    var filteredItems: [MediaProductsItem] {
        let filtered = store.MediaProductsList
            .filter { item in
                item.status == selectedStatus
            }
            .filter { item in
                searchText.isEmpty || item.title.localizedCaseInsensitiveContains(searchText)
            }

        let categoryFiltered = isSearching ? filtered : filtered.filter {
            $0.category == selectedCategory
        }

        switch sortOrder {
            case .createdAt:
                return categoryFiltered.sorted { $0.createdAt ?? "" < $1.createdAt ?? "" }
            case .title:
                return categoryFiltered.sorted { $0.title < $1.title }
        }
    }
}


private struct SettingsSheetView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @ObservedObject var store: MediaProductsStore

    var body: some View {
        @Bindable var settingsStoreBindable = settingsStore

        NavigationStack {

            Form {

                Section(header: Text("表示設定")) {

                    Toggle(isOn: $settingsStoreBindable.showMediaProductsListCount) {
                        VStack(alignment: .leading) {
                            Text("件数を表示")
                            Text("映像作品リスト底に件数を表示する")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("映像作品設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
