//
//  GrammarContentView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 5/4/R8.
//

import SwiftUI

struct GrammarContentView: View {
    @Environment(AppNavigationStore.self) private var navigationStore
    @StateObject var grammarStore = GrammarStore()
    @State private var grammarPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $grammarPath) {
            GrammarNaviView(store: grammarStore)
                .navigationDestination(for: GrammarNavDestination.self) { destination in
                    switch destination {
                        case .list(let level, let title):
                            GrammarListView(level: level, title: title, store: grammarStore)
                        case .details(let id, let level):
                            GrammarDetailLoader(id: id, level: level, store: grammarStore)
                        }
                }
                .navigationDestination(for: QuickActionTarget.self) { target in
                    if case .lastGrammar(let id, let level) = target {
                        GrammarDetailLoader(id: id, level: level, store: grammarStore)
                    }
                }
        }
        .onChange(of: navigationStore.quickActionTarget) { _, target in
            guard let target = target else { return }

            if case .lastGrammar(let id, let level) = target {
                let item = GrammarAllLevels.grammarList.first(where: { $0.level == level })
                let title = item?.title ?? "\(level) 文法"
                grammarPath = NavigationPath()
                grammarPath.append(GrammarNavDestination.list(level: level, title: title))
                grammarPath.append(GrammarNavDestination.details(id: id, level: level))

                navigationStore.clearTarget()
            }
        }
    }
}
