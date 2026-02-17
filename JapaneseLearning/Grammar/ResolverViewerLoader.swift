//
//  Resolver.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/21.
//

import SwiftUI
import Foundation

enum GrammarNavDestination: Hashable {
    case list(level: String, title: String)
    case details(id: UUID)
}


struct GrammarDetailLoader: View {
    let id: UUID
    @ObservedObject var store: GrammarStore
    @State private var isFetching = true

    var body: some View {

        Group {
            if let item = store.grammars.first(where: { $0.id == id }) {
                GrammarDetailsView(item: item, store: store)
            } else if isFetching {
                ProgressLoadingView()
            }
        }
        .task {
            if store.grammars.isEmpty {
                await store.fetchAll()
                isFetching = false
            }
        }
    }
}
