//
//  YouTubeAddVideoSheetView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/01/30.
//

import SwiftUI

struct YouTubeAddVideoSheetView: View {
    @Environment(VideoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var inputURL = "" // https://www.youtube.com/playlist?list=PLDLUFJdSF5xY1xsiYoWkkyp1k2GCGpcZP / https://www.youtube.com/watch?v=h3m5XnQce1k

    var body: some View {
        
        NavigationStack {

            List {

                Section("YouTube リンク") {
                    URLInputView(inputURL: $inputURL)
                }

                if !store.videoList.isEmpty {
                    Section("再生リスト") {
                        ForEach(store.videoList) { videoList in
                            NavigationLink {
                                YouTubePlayListVideoSelectView(
                                    playlistID: videoList.id,
                                    listTitle: videoList.title,
                                    existingVideoListIDs: store.getExistingVideoIDs(),
                                    onAdd: { selected in
                                        store.addPlaylistVideos(selected)
                                    }
                                )
                            } label: {
                                PlaylistListRow(videoList: videoList)
                            }
                            .swipeActions {
                                Button {
                                    store.deleteVideoFromPlayList(videoList.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("動画を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            let result = await store.handleYouTubeURL(inputURL)
                            inputURL = ""
                            if result == .addedVideo {
                                dismiss()
                            }
                        }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(inputURL.isEmpty)
                }
            }
        }
    }
}

struct URLInputView: View {
    @Binding var inputURL: String

    var body: some View {

        VStack {

            ZStack(alignment: .topLeading) {
                if inputURL.isEmpty {
                    Text("YouTube URL")
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        .padding(.top, 8)
                }
                TextEditor(text: $inputURL)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 83)
            }
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
            .frame(width: 100)
            .cornerRadius(8)

            VStack(alignment: .leading) {
                HStack {
                    Text(videoList.author)
                        .font(.caption)
                    Text("\(videoList.videoCount)件")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(videoList.title)
                    .lineLimit(2)
            }
        }
        .contentShape(Rectangle())
    }
}
