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
    @State private var isReady: Bool = false

    @Environment(SettingsStore.self) private var settingsStore
    @ObservedObject var store: GrammarStore

    var body: some View {
        VStack {
            List {
                Section {
                    ForEach(filteredItems) { item in
                        NavigationLink(value: GrammarNavDestination.details(id: item.id, level: level)) {
                            Text(item.title)
                            if settingsStore.showGrammarListItemImportantImage {
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

                            if settingsStore.showGrammarListAllItemTag, level == "All" {
                                Text(item.level)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if settingsStore.showGrammarListItemSwipeActions {
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
                    if settingsStore.showGrammarListCount {
                        Text("件数：\(filteredItems.count)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            showImportantOnly.toggle()
                        }
                    } label: {
                        Image(systemName: showImportantOnly ? "star.fill" : "line.3.horizontal.decrease")
                            .foregroundStyle(showImportantOnly ? .yellow : .primary)
                    }
                }

                if settingsStore.showGrammarListAddButton && level != "All" {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Spacer()

                        NavigationLink {
                            GrammarDetailsEditorView(
                                item: GrammarItem(
                                    id: 8964,
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
            .opacity(store.isReady ? 1 : 0)
            .animation(.easeIn(duration: 0.15), value: store.isReady)
            .searchable(text: $searchText, prompt: "文法を検索")
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(title)
        .task(id: level) {
            await store.fetchList(level: level)
        }
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
    }
}
