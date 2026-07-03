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

    @Environment(SettingsStore.self) private var settingsStore
    @ObservedObject var store: GrammarStore

    @State private var searchText: String = ""
    @State private var showImportantOnly: Bool = false

    var body: some View {
        ScrollViewReader { proxy in
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
                        .id(item.id)
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

                                        if (!item.isMarked) {
                                            QuickActionManager.shared.updateRecentGrammarAction(
                                                grammarID: String(item.id),
                                                title: item.title,
                                                level: item.level
                                            )
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if store.isReady, currentProgress != 0.0 {
                    HStack {
                        Spacer()

                        Button {
                        } label: {
                            Text(currentProgress, format: .percent.precision(.fractionLength(1)))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.accentColor)
                                .contentTransition(.numericText())
                        }
                        .buttonStyle(.glass)
                        .animation(.smooth(duration: 0.5), value: currentProgress)
                    }
                    .padding(.horizontal, 30)
                }
            }
            .toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)
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
                                    id: -1,
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
            .opacity(store.isReady ? 1 : 0)
            .navigationTitle(title)
            .task(id: level) {
                if store.currentLevel != level {
                    store.currentLevel = level
                    await store.fetchList(level: level)
                }
            }
            .task(id: store.isReady) {
                if store.isReady {
                    scrollToMarkedItem(using: proxy)
                }
            }
        }
    }

    private func scrollToMarkedItem(using proxy: ScrollViewProxy) {
        if let isMarkedItem: GrammarItem = filteredItems.last(where: { $0.isMarked }) {
            Task {
                try? await Task.sleep(for: .seconds(0.1))
                proxy.scrollTo(isMarkedItem.id, anchor: .center)
            }
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

    var currentProgress: Double {
        guard !filteredItems.isEmpty else { return 0.0 }

        if let targetIndex = filteredItems.lastIndex(where: { $0.isMarked }) {
            let itemPosition = targetIndex + 1
            return Double(itemPosition) / Double(filteredItems.count)
        }

        return 0.0
    }
}
