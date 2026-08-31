//
//  AddVideoSheetView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/01/30.
//

import SwiftUI

struct AddVideoSheetView: View {
    @Environment(VideoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var inputURL = ""
    @State private var showVideoUploadOptions = false
    @State private var pendingSingleVideoURL = ""
    @State private var pendingSingleVideoTitle = ""
    let onComplete: (AddYouTubeResult) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("YouTube リンク") {
                    TextField("YouTube動画または再生リストのリンク", text: $inputURL, axis: .vertical)
                        .lineLimit(2...3)
                }

                if !store.videoList.isEmpty {
                    Section("再生リスト") {
                        ForEach(store.videoList) { videoList in
                            NavigationLink {
                                PlayListVideoSelectView(
                                    playlistID: videoList.id,
                                    listTitle: videoList.title,
                                    existingVideoListIDs: store.getExistingVideoIDs(),
                                    onAdd: { _, categoryID in
                                        onComplete(.addedVideoFromPlaylist(categoryID: categoryID))
                                    },
                                    onFinish: {
                                        dismiss()
                                    }
                                )
                            } label: {
                                PlaylistListRow(videoList: videoList)
                            }
                            .swipeActions {
                                Button {
                                    Task {
                                        await store.deleteVideoPlaylist(videoList.id)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .tint(.red)
                            }
                        }
                        .opacity(store.videoListIsReady ? 1 : 0)
                    }
                }
            }
            .navigationTitle("動画を追加")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        handlePrimaryAction()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(inputURL.isWhitespaceOrNewLine)
                }
            }
            .navigationDestination(isPresented: $showVideoUploadOptions) {
                VideoUploadOptionsView(
                    initialVideoTitle: pendingSingleVideoTitle
                ) { language, createCaptionByAi, playbackRate, videoTitle, categoryID in
                    let url = pendingSingleVideoURL

                    Task {
                        let result = await store.handleYouTubeURL(
                            url,
                            contentLanguage: language,
                            createCaptionByAi: createCaptionByAi,
                            playbackRate: playbackRate,
                            videoTitle: videoTitle,
                            categoryID: categoryID
                        )
                        onComplete(result)

                        if case .addedVideo = result {
                            dismiss()
                        }

                        inputURL = ""
                        pendingSingleVideoURL = ""
                        pendingSingleVideoTitle = ""
                    }
                }
            }
            .task {
                if store.videoList.isEmpty {
                    await store.fetchVideoPlaylist()
                }
            }
        }
    }

    private func handlePrimaryAction() {
        let url = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        switch store.youtubeURLType(from: url) {
            case .single:
                Task {
                    guard let videoID = YouTubeService.extractVideoID(from: url) else { return }
                    pendingSingleVideoURL = url
                    pendingSingleVideoTitle = (await YouTubeService.fetchTitle(videoID)).cleanedVideoTitle
                    showVideoUploadOptions = true
                }
            case .playlist:
                Task {
                    let result = await store.handleYouTubeURL(
                        url,
                        contentLanguage: .ja,
                        createCaptionByAi: true
                    )
                    onComplete(result)

                    if case .addedPlaylist = result {
                        inputURL = ""
                    }
                }
            case .unknown:
                break
        }
    }
}

struct PlaylistListRow: View {
    let videoList: PlaylistListItem

    var body: some View {
        HStack {
            AsyncImage(url: videoList.thumbnailURL) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 100, height: 56)
            .cornerRadius(8)

            VStack(alignment: .leading) {
                Text(videoList.author)
                    .font(.caption)
                Text(videoList.title)
                    .lineLimit(2)
            }
        }
        .contentShape(Rectangle())
    }
}
