//
//  VideoListView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/23.
//

import SwiftUI

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

    @State private var selectedCategory: PlaylistCategory = .shadowing

    private var filteredVideos: [VideoItem] {
        let targetID = selectedCategory.playlistID
        let knownPlaylistIDs = PlaylistCategory.allCases.compactMap { $0.playlistID }

        return store.videos.filter { video in
            if let id = targetID {
                return video.playlistID == id
            } else {
                return !knownPlaylistIDs.contains(video.playlistID ?? "")
            }
        }
    }

    var body: some View {
        let sizeClass_regular = sizeClass == .regular

        Group {
            if !store.videosIsReady {
                ProgressLoadingView()
            } else {
                GeometryReader { geo in
                    let isLandscape = geo.size.width > geo.size.height

                    let columns: [GridItem] = {
                        if sizeClass_regular { // iPad
                            return Array(repeating: GridItem(.flexible(), spacing: 16), count: isLandscape ? 3 : 2)
                        } else { // iPhone
                            return Array(repeating: GridItem(.flexible(), spacing: 16), count: isLandscape ? 2 : 1)
                        }
                    }()

                    ScrollView {
                        if store.videos.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "folder")
                                    .font(.system(size: 100))
                                    .foregroundStyle(.secondary)
                                Text("内容が見つかりません")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 180)
                        } else {
                            VStack(spacing: 12) {
                                Picker("Category", selection: $selectedCategory) {
                                    ForEach(PlaylistCategory.allCases) { category in
                                        Text(category.title)
                                            .tag(category)
                                    }
                                }
                                .pickerStyle(.palette)
                                .controlSize(sizeClass_regular ? .large : .regular)
                                .padding(.horizontal, 16)
                                .padding(.vertical, sizeClass_regular ? 10 : 2)

                                ZStack {
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
                                    .id(selectedCategory.id)
                                    .transition(.opacity)
                                }
                                .animation(.easeInOut(duration: 0.3), value: selectedCategory)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            }
                            .opacity(store.videosIsReady ? 1 : 0)
                        }
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
        .sheet(isPresented: $showAddSheet) {
            YouTubeAddVideoSheetView { result in
                switch result {
                    case .addedVideo:
                        selectedCategory = .shadowing
                    case .addedVideosFromPlaylist(let playlistID):
                        selectedCategory = PlaylistCategory.allCases.first {
                            $0.playlistID == playlistID
                        } ?? .shadowing
                    default:
                        break
                }
            }
        }
        .sheet(isPresented: $showSettingSheet) {
            ShadowingSettingsSheetView()
                .presentationDetents([.medium, .large])
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
            sizeClass == .regular ? (16.0 / 9.0) : (330.0 / 160.0)
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
