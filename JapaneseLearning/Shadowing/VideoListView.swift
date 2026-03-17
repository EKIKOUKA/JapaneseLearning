//
//  VideoListView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/23.
//

import SwiftUI
import Foundation

struct VideoListView: View {
    @Environment(VideoStore.self) private var store
    @Environment(AppNavigationStore.self) private var navigationStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showAddSheet = false
    @State private var showSettingSheet = false
    @State private var showPlayListSheet = false
    @State private var selectedVideo: VideoItem?
    @State private var showDeleteAlert = false
    @State private var pendingDeleteVideo: VideoItem?
    @State private var retryImageLoad = UUID()

    private let defaultID = "PLEC5UjKGbYI2TeWkpUE-RocpVhqXwwk-9"
    private let othersID = "others"
    @State private var selectedPlaylistID: String? = "others"

    private var filteredVideos: [VideoItem] {
        if selectedPlaylistID == defaultID {
            return store.videos.filter { $0.playlistID == defaultID }
        } else {
            return store.videos.filter { $0.playlistID != defaultID } // != id1 && != id2
        }
    }
    private var playlistCategories: [String] {
        [othersID, defaultID]
    }
    private func shortTitle(for id: String?) -> String {

        if id == defaultID {
            return "デフォルト"
        } else {
            return "シャドーイング"
        }
    }

    var body: some View {
        let sizeClass_regular = sizeClass == .regular

        Group {
            if store.isLoading {
                ProgressLoadingView()
            } else {
                GeometryReader { geo in
                    let isLandscape = geo.size.width > geo.size.height

                    let columns: [GridItem] = {
                        if sizeClass_regular { // iPad
                            return Array(repeating: GridItem(.flexible(), spacing: 16),
                                         count: isLandscape ? 3 : 2)
                        } else { // iPhone
                            return Array(repeating: GridItem(.flexible(), spacing: 16),
                                         count: isLandscape ? 2 : 1)
                        }
                    }()

                    ScrollView {
//                        if store.videos.isEmpty {
//                            VStack(spacing: 16) {
//                                Image(systemName: "folder")
//                                    .font(.system(size: 100))
//                                    .foregroundStyle(.secondary)
//                                Text("内容が見つかりません")
//                                    .foregroundStyle(.secondary)
//                            }
//                            .frame(maxWidth: .infinity)
//                            .padding(.top, 180)
//                        } else {
                            VStack(spacing: 12) {

                                Picker("Category", selection: $selectedPlaylistID) {
                                    ForEach(playlistCategories, id: \.self) { id in
                                        Text(shortTitle(for: id))
                                            .tag(id as String?)
                                    }
                                }
                                .pickerStyle(.palette)
                                .controlSize(sizeClass_regular ? .large : .regular)
                                .padding(.horizontal, 16)
                                .padding(.vertical, sizeClass_regular ? 10 : 2)

                                ZStack {
                                    if let currentID = selectedPlaylistID {

                                        LazyVGrid(columns: columns) {

                                            ForEach(filteredVideos) { video in
                                                Button {
                                                    selectedVideo = video
                                                } label: {
                                                    videoListItemView(video)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .id(currentID)
                                        .transition(.opacity)
                                    }
                                }
                                .animation(.easeInOut(duration: 0.3), value: selectedCategory)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            }
                            .opacity(store.videosIsReady ? 1 : 0)
//                        }
                    }
                    .navigationDestination(item: $selectedVideo) { video in
                        VideoContentView(videoID: video.id)
                            .toolbarColorScheme(.dark, for: .navigationBar)
                    }
                }
            }
        }
        .navigationTitle("シャドーイング")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }

                Button {
                    showSettingSheet = true
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showSettingSheet) {
            ShadowingSettingsSheetView()
                .presentationDetents(sizeClass_regular ? [.large] : [.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddSheet) {
            YouTubeAddVideoSheetView { result in
                switch result {
                    case .addedVideo:
                        if selectedPlaylistID != othersID {
                            selectedPlaylistID = othersID
                        }

                    case .addedVideosFromPlaylist(let playlistID):
                        if playlistID == defaultID {
                            if selectedPlaylistID != defaultID {
                                selectedPlaylistID = defaultID
                            }
                        } else {
                            if selectedPlaylistID != othersID {
                                selectedPlaylistID = othersID
                            }
                        }

                    default:
                        break
                }
            }
            .presentationDetents(sizeClass_regular ? [.large] : [.medium, .large])
        }
        .alert("この動画を削除しますか？",
               isPresented: $showDeleteAlert,
               presenting: pendingDeleteVideo) { video in
            Button("削除", role: .destructive) {
                store.videos.removeAll { $0.id == video.id }

                Task {
                    await store.deleteVideo(video.id)
                }
            }
        }
    }

    private func videoListItemView(_ video: VideoItem) -> some View {
        var thumbnailRatio: CGFloat {
            sizeClass == .regular ? (16.0 / 9.0) : (341.0 / 160.0)
        }

        return VStack(alignment: .leading, spacing: 12) {
            Color.clear
                .aspectRatio(thumbnailRatio, contentMode: .fit)
                .overlay {
                    // 2️⃣ 圖片在 overlay 裡填滿容器
                    AsyncImage(url: video.thumbnailURL) { phase in
                        switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .transition(.opacity)
                                    .animation(.easeIn(duration: 0.5), value: video.thumbnailURL)
                            case .empty:
                                ZStack {
                                    Rectangle()
                                        .fill(Color(.tertiarySystemFill))
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                }
                            case .failure:
                                ZStack {
                                    Rectangle()
                                        .fill(Color(.tertiarySystemFill))
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                }
                                .onAppear {
                                    retryImageLoad = UUID()
                                }
                            @unknown default:
                                ZStack {
                                    Rectangle()
                                        .fill(Color(.tertiarySystemFill))
                                    ProgressView()
                                }
                        }
                    }
                    .id(retryImageLoad)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .contentShape(Rectangle())

            Text(video.title)
                .font(.body)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                .padding(.bottom, 2)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(25)
        .onLongPressGesture {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            pendingDeleteVideo = video
            showDeleteAlert = true
        }
    }
}
