//
//  GrammarNaviView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import SwiftUI

struct GrammarNaviView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ObservedObject var store: GrammarStore
    @State private var showSettingSheet = false

    var dynamicColors: [LinearGradient] {
        let colors: [[Color]] = colorScheme == .dark
            ? [[.indigo, .purple], [.teal, .green], [.orange, .red], [.yellow, .orange], [.cyan, .blue], [.gray, .black]]
            : [[.blue, .cyan], [.purple, .pink], [.green, .mint], [.orange, .yellow], [.red, .orange], [.gray, .black]]

        return colors.map { LinearGradient(colors: $0, startPoint: .topLeading, endPoint: .bottomTrailing) }
    }

    var body: some View {
        let sizeClass_regular = sizeClass == .regular

        Group { // NavigationStack

            ZStack {

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {

                    ForEach(GrammarAllLevels.grammarList.indices, id: \.self) { index in
                        let item = GrammarAllLevels.grammarList[index]

                        NavigationLink(
                            value: GrammarNavDestination.list(level: item.level, title: item.title)
                        ) {
                            VStack(spacing: 10) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 32))
                                Text(item.title)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, minHeight: sizeClass_regular ? 220 : 120)
                            .foregroundStyle(.white)
                            .background(dynamicColors[index % dynamicColors.count])
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(radius: 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 90)
            }
            .padding()
            .navigationTitle("日本語文法")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink(value:
                        GrammarNavDestination.list(level: "All", title: "日本語 文法")) {
                        Image(systemName: "magnifyingglass")
                    }

                    Button {
                        showSettingSheet = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .sheet(isPresented: $showSettingSheet) {
            SettingsSheetGrammarView(store: store)
                .presentationDetents(sizeClass_regular ? [.large] : [.height(490), .large])
                .presentationDragIndicator(.visible)
        }
    }
}
