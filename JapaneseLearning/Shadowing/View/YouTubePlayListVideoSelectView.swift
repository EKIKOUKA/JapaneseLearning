//
//  YouTubePlayListVideoSelectView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/01/30.
//

import SwiftUI
import Foundation

struct YouTubePlayListVideoSelectView: View {
    let playlistID: String
    let listTitle: String
    let existingVideoListIDs: Set<String>
    let onAdd: ([PlayListVideoItem]) -> Void
    let onFinish: () -> Void

    @Environment(VideoStore.self) private var store
    @State private var selectedVideoIDs = Set<String>()
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List(store.videoListVideos) { video in
                    playlistRow(video)
                        .id(video.id)
                }
                .navigationTitle(listTitle)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        NavigationLink {
                            ContentVideoUploadOptionsView { language, createCaptionByAi, playbackRate in
                                let selectedVideos = store.videoListVideos.filter { selectedVideoIDs.contains($0.id) }
                                guard !selectedVideos.isEmpty else { return }

                                Task {
                                    for video in selectedVideos {
                                        await store.addVideoFromPlaylist(
                                            video,
                                            playlistID: playlistID,
                                            contentLanguage: language,
                                            createCaptionByAi: createCaptionByAi,
                                            playbackRate: playbackRate
                                        )
                                    }

                                    onAdd(selectedVideos)
                                    onFinish()
                                }
                            }
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .disabled(selectedVideoIDs.isEmpty)
                    }
                }
                .opacity(store.videoListVideosIsReady ? 1 : 0)
                .task {
                    if !hasLoaded {
                        await store.fetchPlaylistVideos(playlistID: playlistID)
                        hasLoaded = true

                        scrollToLastExistingItem(using: proxy)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func playlistRow(_ video: PlayListVideoItem) -> some View {
        let isDisabled = existingVideoListIDs.contains(video.id)
        let isSelected = selectedVideoIDs.contains(video.id)

        HStack {
            if isDisabled {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.quaternary)
                    .font(.system(size: 22))
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 22))
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.quaternary)
                    .font(.system(size: 22))
            }

            AsyncImage(url: video.thumbnailURL) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 100, height: 57)
            .cornerRadius(8)

            Text(video.title.cleanedVideoTitle)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isDisabled else { return }
            toggle(video.id)
        }
    }

    private func scrollToLastExistingItem(using proxy: ScrollViewProxy) {
        if let isDisabledItem = store.videoListVideos.first(where: { existingVideoListIDs.contains($0.id) }) {
            proxy.scrollTo(isDisabledItem.id, anchor: .center)
        }
    }

    private func toggle(_ id: String) {
        if selectedVideoIDs.contains(id) {
            selectedVideoIDs.remove(id)
        } else {
            selectedVideoIDs.insert(id)
        }
    }
}
