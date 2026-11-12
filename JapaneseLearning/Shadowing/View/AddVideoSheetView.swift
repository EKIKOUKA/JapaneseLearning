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

    private func videoSelector(_ id: String, _ title: String) -> some View {
        PlayListVideoSelectView(
            playlistID: id,
            listTitle: title,
            existingVideoListIDs: store.getExistingVideoIDs(),
            onAdd: { _, categoryID in
                onComplete(.addedVideoFromPlaylist(categoryID: categoryID))
            },
            onFinish: { dismiss() }
        )
    }

    private func channelRow(_ list: PlaylistListItem) -> some View {
        let channel = store.channelInfo(for: list.id)
        let channelID = channel?.id ?? "UC" + String(list.id.dropFirst(2))
        return HStack(spacing: 12) {
            AsyncImage(url: channel?.avatar) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(channel?.title ?? (list.author.isEmpty ? list.title : list.author))
                    .font(.headline)
                Text(channel?.handle ?? channelID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let count = channel?.videoCount {
                    Text("公開動画 \(count.formatted()) 本")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("YouTube リンク") {
                    TextField("YouTube 動画・再生リスト・チャンネルのリンク", text: $inputURL, axis: .vertical)
                        .lineLimit(2...3)
                }

                ForEach([true, false], id: \.self) { isChannel in
                    let lists = store.videoList.filter { list in
                        let uploads = store.channelInfo(for: list.id) != nil
                            || (list.id.hasPrefix("UU") && list.id.count == 24)
                        return uploads == isChannel
                    }

                    if !lists.isEmpty {
                        Section(isChannel ? "チャンネル" : "再生リスト") {
                            ForEach(lists) { videoList in
                                NavigationLink {
                                    if isChannel {
                                        ChannelVideoBrowser(
                                            channelID: store.channelInfo(for: videoList.id)?.id
                                                ?? "UC" + String(videoList.id.dropFirst(2)),
                                            uploadsID: videoList.id,
                                            title: store.channelInfo(for: videoList.id)?.title
                                                ?? (videoList.author.isEmpty ? videoList.title : videoList.author),
                                            header: { channelRow(videoList) },
                                            videos: videoSelector
                                        )
                                    } else {
                                        videoSelector(videoList.id, videoList.title)
                                    }
                                } label: {
                                    if isChannel {
                                        channelRow(videoList)
                                    } else {
                                        PlaylistListRow(videoList: videoList)
                                    }
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
                ) { language, playbackRate, videoTitle, categoryID in
                    let url = pendingSingleVideoURL

                    Task {
                        let result = await store.handleYouTubeURL(
                            url,
                            contentLanguage: language,
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
            case .playlist, .channel:
                Task {
                    let result = await store.handleYouTubeURL(
                        url,
                        contentLanguage: .ja
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

private struct ChannelVideoBrowser<Header: View, Videos: View>: View {
    let channelID: String
    let uploadsID: String
    let title: String
    @ViewBuilder let header: () -> Header
    let videos: (String, String) -> Videos

    @State private var showPlaylists = false
    @State private var playlists: [PlayListMetaItem] = []
    @State private var nextPageToken: String?
    @State private var hasLoaded = false
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                header()
                Picker("表示", selection: $showPlaylists) {
                    Text("動画").tag(false)
                    Text("再生リスト").tag(true)
                }
                .pickerStyle(.segmented)
            }
            .padding()

            if showPlaylists {
                List {
                    if hasLoaded && playlists.isEmpty {
                        Text("公開されている再生リストはありません")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(playlists, id: \.id) { playlist in
                        NavigationLink {
                            videos(playlist.id, playlist.snippet.title)
                        } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: (playlist.snippet.thumbnails?.medium).flatMap { URL(string: $0.url) }) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color.gray.opacity(0.2)
                                }
                                .frame(width: 88, height: 50)
                                .clipShape(.rect(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(playlist.snippet.title)
                                    Text("動画 \(playlist.contentDetails.itemCount.formatted()) 本")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if isLoading {
                        ProgressView()
                    } else if !hasLoaded || nextPageToken != nil {
                        Button(hasLoaded ? "もっと見る" : "再生リストを読み込む") {
                            Task { await loadPage() }
                        }
                    }
                }
                .task {
                    if !hasLoaded { await loadPage() }
                }
            } else {
                videos(uploadsID, title)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadPage() async {
        guard !isLoading, !hasLoaded || nextPageToken != nil else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await YouTubeService.fetchChannelPlaylists(channelID: channelID, pageToken: nextPageToken)
            try Task.checkCancellation()
            var ids = Set(playlists.map(\.id))
            playlists.append(contentsOf: page.items.filter { ids.insert($0.id).inserted })
            nextPageToken = page.nextPageToken
            hasLoaded = true
        } catch {
            // 通信エラーは共通のエラー表示で通知する。
        }
    }
}
