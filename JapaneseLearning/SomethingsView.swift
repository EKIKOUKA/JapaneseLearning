//
//  SomethingsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import SwiftUI

struct SomethingsView: View {
    @State private var settingsStore = SettingsStore()
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationStack {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                btnTextView("支那語に無い漢字") {
                    KanjiWordsDiffToShinaLangView()
                }

                btnTextView("覚えにくい単語") {
                    MemoryHardWordsView()
                }

                btnTextView("国語美文") {
                    ElegantSentenceView()
                }

                btnTextView("慣用句") {
                    IdiomsListView()
                }

                btnTextView("同じ発音の言葉") {
                    SampleRubyWordsView()
                }

                btnTextView("映像作品リスト") {
                    MediaProductsListView()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 90)
            .navigationTitle("その他")
        }
    }

    func btnTextView<Destination: View>(
        _ title: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        let sizeClass_regular = sizeClass == .regular
        let btnMinHeight: CGFloat = sizeClass_regular ? 220 : 120

        return NavigationLink(
            destination: destination()
        ) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, minHeight: btnMinHeight)
                .foregroundStyle(.primary)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 4)
        }
        .buttonStyle(.plain)
    }
}
