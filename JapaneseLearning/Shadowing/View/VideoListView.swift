//
//  VideoListView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/23.
//

import SwiftUI

struct VideoListView: View {
    let onSelectVideo: (String) -> Void

    @Environment(\.transitionNamespace) private var transitionNamespace
    @State private var showSettingSheet = false
    @State private var podcastLibrary = PodcastLibrary.shared
    @State private var showPodcastCatalog = false
    @State private var podcastListError: String?

    @ViewBuilder
    private var podcastList: some View {
        if let error = podcastLibrary.readError {
            Text("Podcast 一覧を読み込めませんでした。\n\(error)")
                .font(.caption)
        }

        if !podcastLibrary.episodes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(podcastLibrary.episodes) { episode in
                    Button {
                        onSelectVideo(episode.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "waveform")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(episode.title)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(episode.show) · \(episode.language.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSourceIfAvailable(id: "list-\(episode.id)", in: transitionNamespace)
                    .contextMenu {
                        Button("一覧から削除", systemImage: "trash", role: .destructive) {
                            do { try podcastLibrary.remove(episode) }
                            catch { podcastListError = error.localizedDescription }
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        Group {
            if podcastLibrary.episodes.isEmpty && podcastLibrary.readError == nil {
                ContentUnavailableView(
                    "Podcast がありません",
                    systemImage: "waveform",
                    description: Text("右上のボタンから Podcast を探してください。")
                )
            } else {
                ScrollView {
                    podcastList
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
            }
        }
        .navigationTitle("ホーム")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarMinimizeNavigationBarIfAvailable()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showPodcastCatalog = true
                } label: {
                    Label("Podcast を探す", systemImage: "waveform")
                }
                Button {
                    showSettingSheet = true
                } label: {
                    Label("シャドーイング設定", systemImage: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showPodcastCatalog) {
            PodcastCatalogView { showPodcastCatalog = false }
        }
        .sheet(isPresented: $showSettingSheet) {
            ShadowingSettingsSheetView(playerVM: nil)
                .presentationDetents([.medium, .large])
        }
        .alert("Podcast", isPresented: Binding(
            get: { podcastListError != nil },
            set: { if !$0 { podcastListError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(podcastListError ?? "")
        }
    }
}
