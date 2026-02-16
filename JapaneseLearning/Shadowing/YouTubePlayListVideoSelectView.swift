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

    @Environment(\.dismiss) private var dismiss
    @Environment(VideoStore.self) private var store
    @State private var videos: [PlayListVideoItem] = []
    @State private var selectedIDs = Set<String>()

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
        }
        .task {
            videos = await store.fetchPlaylistVideos(playlistID: playlistID)
        }
    }

    @ViewBuilder
    private func playlistRow(_ video: PlayListVideoItem) -> some View {

        let isDisabled = existingVideoListIDs.contains(video.id)
        let isSelected = selectedIDs.contains(video.id)

        HStack {
            if isDisabled {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.separator)
                    .font(.system(size: 20))
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 20))
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.separator)
                    .font(.system(size: 20))
            }

            AsyncImage(url: video.thumbnailURL) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 100, height: 57)
            .cornerRadius(8)

            Text(video.title)
                .lineLimit(3)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isDisabled else { return }
            toggle(video.id)
        }
    }

    private func toggle(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}
