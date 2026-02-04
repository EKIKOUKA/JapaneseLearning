//
//  GrammarNaviView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import SwiftUI

struct GrammarNaviView: View {

    @ObservedObject var store: GrammarStore
    @Environment(\.colorScheme) var colorScheme
    @State private var showSettingSheet = false
    @Environment(\.scenePhase) private var scenePhase

    var dynamicColors: [LinearGradient] {
        let colors: [[Color]] = colorScheme == .dark
            ? [[.indigo, .purple], [.teal, .green], [.orange, .red], [.yellow, .orange], [.cyan, .blue], [.gray, .black]]
            : [[.blue, .cyan], [.purple, .pink], [.green, .mint], [.orange, .yellow], [.red, .orange], [.gray, .black]]

        return colors.map { LinearGradient(colors: $0, startPoint: .topLeading, endPoint: .bottomTrailing) }
    }

    var body: some View {

        Group { // NavigationStack

            ZStack {

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {

                    ForEach(Array(GrammarAllLevels.grammarList.enumerated()), id: \.element.id) { index, item in

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
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .foregroundStyle(.white)
                            .background(dynamicColors[index % dynamicColors.count])
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(radius: 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 90)

                if store.isLoading {
                    ProgressLoadingView()
                }
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
                .presentationDetents([.height(490), .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            if store.grammars.isEmpty {
                await store.fetchAll()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            Task {
                if phase == .background {
                    await store.stopRealtime()
                }
            }
        }
    }
}

