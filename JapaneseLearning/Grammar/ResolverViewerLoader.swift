//
//  ResolverViewerLoader.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/21.
//

import SwiftUI
import Foundation

enum GrammarNavDestination: Hashable {
    case list(level: String, title: String)
    case details(id: Int, level: String)
}

struct GrammarDetailLoader: View {
    let id: Int
    let level: String
    @ObservedObject var store: GrammarStore

    var body: some View {
        Group {
            if let item = store.grammars.first(where: { $0.id == id }) {
                GrammarDetailsView(item: item, store: store)
            } else {
                Color.clear.frame(height: 100)
            }
        }
        .task {
            if store.grammars.first(where: { $0.id == id }) == nil {
                await store.fetchList(level: level)
            }
        }
    }
}
