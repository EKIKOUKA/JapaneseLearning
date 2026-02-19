//
//  ProgressLoadingView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/29.
//

import SwiftUI

struct ProgressLoadingView: View {

    var body: some View {

        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.6)
            Text("読み込み中...")
                .font(.headline)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}
