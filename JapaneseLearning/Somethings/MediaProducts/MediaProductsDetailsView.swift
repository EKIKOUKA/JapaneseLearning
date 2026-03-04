//
//  MediaProductsDetailsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/14.
//

import SwiftUI

struct MediaProductsDetailsView: View {
    let item: MediaProductsItem
    @ObservedObject var store: MediaProductsStore
    @State private var isWebLoading = true
    @State private var isReady = false

    var body: some View {

        ZStack {

            VStack {
                if let urlString = item.detailsURL, let url = URL(string: urlString) {
                    WebView(url: url, isLoading: $isWebLoading)
                        .ignoresSafeArea(.all)
                } else {
                    ContentUnavailableView(
                        "リンクなし",
                        systemImage: "link.slash",
                        description: Text("詳細リンクが設定されていません")
                    )
                }
            }
            .opacity(isReady ? 1 : 0)
            .animation(.easeIn(duration: 0.2), value: isReady)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isReady = true
                }
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
