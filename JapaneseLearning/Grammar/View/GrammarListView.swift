//
//  GrammarListView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import SwiftUI

struct GrammarListView: View {

    let level: String
    let title: String

    @State private var searchText = ""
    @State private var showImportantOnly = false

    @Environment(SettingsStore.self) private var settingsStore
    @ObservedObject var store: GrammarStore

    var body: some View {

        VStack {

            List {

                Section {

                    ForEach(filteredItems) { item in

                        NavigationLink(value: GrammarNavDestination.details(id: item.id)) {
                            Text(item.title)
                            if settingsStore.settings.showGrammarListItemImportantImage {
                                if item.isImportant {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.yellow)
                                        .padding(4)
                                        .background(Color.yellow.opacity(0.2))
                                        .cornerRadius(6)
                                }
                            }
                            if item.isMarked {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 7)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                            if settingsStore.settings.showGrammarListAllItemTag, level == "All" {
                                Text(item.level)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if settingsStore.settings.showGrammarListItemSwipeActions {
                                Button {
                                    Task {
                                        await store.toggleImportant(item.id)
                                        await MainActor.run {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                    }
                                } label: {
                                    Label("", systemImage: "star.fill")
                                }
                                .tint(.yellow)

                                Button {
                                    Task {
                                        await store.toggleMarked(item.id)
                                        await MainActor.run {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                    }
                                } label: {
                                    Label("", systemImage: "bookmark.fill")
                                }
                                .tint(.red)
                            }
                        }
                    }
                } footer: {
                    if settingsStore.settings.showGrammarListCount {
                        Text("件数：\(filteredItems.count)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
//                    Menu {
                        Button {
                            withAnimation {
                                showImportantOnly.toggle()
                            }
                        } label: {
//                            Text("重要のみ")
                            Image(systemName: showImportantOnly ? "star.fill" : "line.3.horizontal.decrease") // star
                                .foregroundStyle(showImportantOnly ? .yellow : .primary)
                        }

                        /* if level != "All" {
                            NavigationLink {
                                GrammarDetailsEditorView()
                            } label: {
                                Label("新規追加", systemImage: "plus")
                            }
                        } */
//                    } label: {
                            Image(systemName: "line.3.horizontal.decrease")
//                    }
                }

                if settingsStore.settings.showGrammarListAddButton && level != "All" {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Spacer()

                        NavigationLink {
                            GrammarDetailsEditorView(
                                item: GrammarItem(
                                    id: UUID(),
                                    title: "",
                                    level: level,
                                    meaning: "",
                                    connection: "",
                                    notes: "",
                                    examples: "",
                                    isImportant: false,
                                    isMarked: false
                                ),
                                store: store,
                                isNew: true
                            )
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "文法を検索")
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(title)
    }

    var filteredItems: [GrammarItem] {
        store.grammars
            .filter { item in
                item.level == level || level == "All"
            }
            .filter { item in
                !showImportantOnly || item.isImportant
            }
            .filter { item in
                searchText.isEmpty || item.title.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.title < $1.title }
            /* if searchText.isEmpty {
                switch level {
                    case "N1": return store.grammars.filter { $0.level == "N1" }.sorted { $0.title < $1.title }
                    case "N2": return store.grammars.filter { $0.level == "N2" }.sorted { $0.title < $1.title }
                    case "N3": return store.grammars.filter { $0.level == "N3" }.sorted { $0.title < $1.title }
                    case "N4": return store.grammars.filter { $0.level == "N4" }.sorted { $0.title < $1.title }
                    case "N5": return store.grammars.filter { $0.level == "N5" }.sorted { $0.title < $1.title }
                    case "Others": return store.grammars.filter { $0.level == "Others" }.sorted { $0.title < $1.title }
                    case "日本語": return store.grammars.sorted { $0.title < $1.title }
                    default: return []
                }
            } else {
                switch level {
                    case "N1": return store.grammars.filter { $0.level == "N1" && $0.title.localizedCaseInsensitiveContains(searchText) }.sorted { $0.title < $1.title }
                    case "N2": return store.grammars.filter { $0.level == "N2" && $0.title.localizedCaseInsensitiveContains(searchText) }.sorted { $0.title < $1.title }
                    case "N3": return store.grammars.filter { $0.level == "N3" && $0.title.localizedCaseInsensitiveContains(searchText) }.sorted { $0.title < $1.title }
                    case "N4": return store.grammars.filter { $0.level == "N4" && $0.title.localizedCaseInsensitiveContains(searchText) }.sorted { $0.title < $1.title }
                    case "N5": return store.grammars.filter { $0.level == "N5" && $0.title.localizedCaseInsensitiveContains(searchText) }.sorted { $0.title < $1.title }
                    case "Others": return store.grammars.filter { $0.level == "Others" && $0.title.localizedCaseInsensitiveContains(searchText) }.sorted { $0.title < $1.title }
                    case "日本語": return store.grammars.filter { $0.title.localizedCaseInsensitiveContains(searchText) }.sorted { $0.title < $1.title }
                    default: return []
                }
            } */
    }
}
