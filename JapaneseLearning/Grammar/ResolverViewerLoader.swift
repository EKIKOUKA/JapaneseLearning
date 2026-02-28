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
    case details(id: Int)
}

struct GrammarDetailLoader: View {
    let id: Int
    @ObservedObject var store: GrammarStore
    @State private var isReady = false

    var body: some View {

        Group {
            if let item = store.grammars.first(where: { $0.id == id }) {
                GrammarDetailsView(item: item, isReady: isReady, store: store)
            } else {
                Color.clear.frame(height: 100)
            }
        }
        .task {
            if store.grammars.isEmpty {
                await store.fetchAll()
                try? await Task.sleep(nanoseconds: 100_000_000)
                isReady = true
            } else {
                isReady = true
            }
        }
    }
}
