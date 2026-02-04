//
//  SomethingsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import SwiftUI

struct SomethingsView: View {

    @State private var settingsStore = SettingsStore()

    var body: some View {

        NavigationStack {

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {

                NavigationLink(
                    destination: KanjiWordsDiffToShinaLangView()
                ) {
                    Text("支那語に無い漢字")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .foregroundStyle(.primary)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 4)
                }
                .buttonStyle(.plain)

                NavigationLink(
                    destination: MemoryHardWordsView()
                ) {
                    Text("覚えにくい単語")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .foregroundStyle(.primary)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 4)
                }
                .buttonStyle(.plain)

                NavigationLink(
                    destination: ElegantSentenceView()
                ) {
                    Text("国語美文")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .foregroundStyle(.primary)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 4)
                }
                .buttonStyle(.plain)

                NavigationLink(
                    destination: IdiomsListView()
                ) {
                    Text("慣用句")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .foregroundStyle(.primary)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 4)
                }
                .buttonStyle(.plain)

                NavigationLink(
                    destination: SampleRubyWordsView()
                ) {
                    Text("同じ発音の言葉")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .foregroundStyle(.primary)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 4)
                }
                .buttonStyle(.plain)

                NavigationLink(
                    destination: MediaProductsListView()
                ) {
                    Text("映像作品リスト")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .foregroundStyle(.primary)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 4)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 90)
            .navigationTitle("その他")
        }
    }
}

#Preview {
    SomethingsView()
}
