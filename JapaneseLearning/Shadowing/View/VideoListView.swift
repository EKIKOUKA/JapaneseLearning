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
    @State private var pendingPodcastID: String?
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
                    NavigationLink {
                        PodcastEpisodeDetails(episode: episode) {
                            onSelectVideo(episode.id)
                        }
                    } label: {
                        PodcastEpisodeLabel(episode: episode)
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
        .sheet(isPresented: $showPodcastCatalog, onDismiss: {
            guard let pendingPodcastID else { return }
            self.pendingPodcastID = nil
            onSelectVideo(pendingPodcastID)
        }) {
            PodcastCatalogView { episode in
                do {
                    try podcastLibrary.add(episode)
                    pendingPodcastID = episode.id
                    showPodcastCatalog = false
                } catch {
                    podcastListError = error.localizedDescription
                }
            }
            .alert("Podcast", isPresented: podcastErrorPresented(inCatalog: true)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(podcastListError ?? "")
            }
        }
        .sheet(isPresented: $showSettingSheet) {
            ShadowingSettingsSheetView(playerVM: nil)
                .presentationDetents([.medium, .large])
        }
        .alert("Podcast", isPresented: podcastErrorPresented(inCatalog: false)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(podcastListError ?? "")
        }
    }

    private func podcastErrorPresented(inCatalog: Bool) -> Binding<Bool> {
        Binding(
            get: { showPodcastCatalog == inCatalog && podcastListError != nil },
            set: { if !$0 { podcastListError = nil } }
        )
    }
}
