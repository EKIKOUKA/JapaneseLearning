//
//  MediaProductsDetailsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/14.
//

import SwiftUI

struct MediaProductsDetailsView: View {
    let item: MediaProductsItem
    @State private var isWebLoading = true
    @ObservedObject var store: MediaProductsStore

    var body: some View {

        ZStack {

            VStack {
                if let urlString = item.detailsURL, let url = URL(string: urlString) {
                    WebView(url: url, isLoading: $isWebLoading)
                        .ignoresSafeArea(.container, edges: .bottom)
                } else {
                    ContentUnavailableView(
                        "リンクなし",
                        systemImage: "link.slash",
                        description: Text("詳細リンクが設定されていません")
                    )
                }
            }

            if isWebLoading {
//                ProgressLoadingView()
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
