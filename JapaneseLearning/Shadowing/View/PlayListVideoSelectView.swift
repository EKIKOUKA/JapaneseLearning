//
//  PlayListVideoSelectView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/01/30.
//

import SwiftUI
import Foundation

struct PlayListVideoSelectView: View {
    let playlistID: String
    let listTitle: String
    let existingVideoListIDs: Set<String>
    let onAdd: ([PlayListVideoItem], String) -> Void
    let onFinish: () -> Void

    @Environment(VideoStore.self) private var store
    @State private var selectedVideoIDs = Set<String>()

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    if !addedVideos.isEmpty {
                        Section("追加済みの動画") {
                            ForEach(addedVideos) {
                                video in playlistRow(video)
                            }
                        }
                    }
                    
                    Section("動画") {
                        ForEach(store.videoListVideos) { video in
                            playlistRow(video)
                                .id(video.id)
                                .onAppear {
                                    guard store.videoListVideos.suffix(5).contains(where: { $0.id == video.id }) else { return }
                                    
                                    Task {
                                        await store.fetchPlaylistVideos(playlistID: playlistID, loadMore: true)
                                    }
                                }
                        }
                        
                        if store.playlistPageIsLoading && store.videoListVideosIsReady {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .navigationTitle(listTitle)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        NavigationLink {
                            let selectedVideos = store.videoListVideos.filter { selectedVideoIDs.contains($0.id) }
                            VideoUploadOptionsView(
                                initialVideoTitle: selectedVideos.count == 1 ? selectedVideos[0].title.cleanedVideoTitle : "",
                                initialCategoryID: store.resolvedCategoryID(playlistID: playlistID),
                                showTitleField: selectedVideos.count == 1
                            ) { language, playbackRate, videoTitle, categoryID in
                                guard !selectedVideos.isEmpty else { return }

                                let resolvedCategoryID = store.resolvedCategoryID(
                                    categoryID: categoryID,
                                    playlistID: playlistID
                                )

                                Task {
                                    for video in selectedVideos {
                                        await store.addVideoFromPlaylist(
                                            video,
                                            playlistID: playlistID,
                                            contentLanguage: language,
                                            playbackRate: playbackRate,
                                            videoTitle: videoTitle,
                                            categoryID: resolvedCategoryID
                                        )
                                    }

                                    onAdd(selectedVideos, resolvedCategoryID)
                                    onFinish()
                                }
                            }
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .disabled(selectedVideoIDs.isEmpty)
                    }
                }
                .overlay {
                    if !store.videoListVideosIsReady && addedVideos.isEmpty {
                        ProgressLoadingView()
                    }
                }
                .task {
                    await store.fetchPlaylistVideos(playlistID: playlistID)
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

    private var addedVideos: [PlayListVideoItem] {
        store.videos.filter { $0.playlistID == playlistID }.map {
            PlayListVideoItem(id: $0.youtubeID, title: $0.title,
                thumbnailURL: URL(string: "https://i.ytimg.com/vi/\($0.youtubeID)/mqdefault.jpg"))
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
