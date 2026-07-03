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
            List(videos) { video in
                playlistRow(video)
            }
            .navigationTitle(listTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let selected = videos.filter {
                            selectedIDs.contains($0.id)
                        }
                        onAdd(selected)
                        dismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
            .opacity(isReady ? 1 : 0)
        }
        .task {
            videos = await store.fetchPlaylistVideos(playlistID: playlistID)
            withAnimation(.easeIn(duration: 0.15)) {
                isReady = true
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
