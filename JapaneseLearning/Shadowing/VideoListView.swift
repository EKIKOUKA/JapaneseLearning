//
//  VideoListView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/23.
//

import SwiftUI

struct VideoListView: View {
    let onSelectVideo: (String) -> Void

    @Environment(VideoStore.self) private var videoStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(PlayerViewManager.self) private var playerVM
    @Environment(\.transitionNamespace) private var transitionNamespace
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showAddSheet: Bool = false
    @State private var showSettingSheet: Bool = false
    @State private var showPlayListSheet: Bool = false
    @State private var selectedVideo: VideoItem?
    @State private var selectedCategoryID: String?
    @State private var showingDeleteAlert: Bool = false
    @State private var videoToDelete: VideoItem?

    init(onSelectVideo: @escaping (String) -> Void = { _ in }) {
        self.onSelectVideo = onSelectVideo
    }

    private var filteredVideos: [VideoItem] {
        guard let selectedCategory else { return [] }
        return videoStore.videos.filter { videoStore.belongsToCategory($0, category: selectedCategory) }
    }

    private var selectedCategory: PlaylistCategory? {
        if let selectedCategoryID,
           let category = videoStore.playlistCategories.first(where: { $0.id == selectedCategoryID }) {
            return category
        }

        return videoStore.playlistCategories.first
    }

    private var filteredVideoIDs: [String] {
        filteredVideos.map(\.id)
    }

    private var sizeClassIsRegular: Bool {
        sizeClass == .regular
    }

    private func gridColumns(isLandscape: Bool) -> [GridItem] {
        let count: Int

        if sizeClassIsRegular {
            count = isLandscape ? 3 : 2
        } else {
            count = isLandscape ? 2 : 1
        }

        return Array(repeating: GridItem(.flexible(), spacing: 16), count: count)
    }

    var body: some View {
        Group {
            GeometryReader { geo in
                if videoStore.videos.isEmpty {
                    ContentUnavailableView(
                        "動画がありません",
                        systemImage: "video",
                        description: Text("右上の＋ボタンからリンクまたは再生リストに動画を追加してください")
                    )
                } else {
                    let columns = gridColumns(isLandscape: geo.size.width > geo.size.height)

                    ScrollView {
                        VStack {
                            videoItemGrid(columns: columns)
                        }
                        .animation(.easeInOut(duration: 0.35), value: selectedCategory?.id)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 20)
                    }
                    .swipeActionsContainer_IfAvailable()
                    .contentMargins(.top, 56, for: .scrollIndicators)
                }
            }
            .refreshable { await videoStore.fetchVideos() }
        }
        .navigationTitle("ホーム")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) {
            categoryPicker
                .padding(.vertical, 8)
                .padding(.bottom, 4)
        }
        .toolbarMinimizationBehaviorIfAvailable()
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
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddVideoSheetView { result in
                selectedCategoryID = videoStore.handleCategory(result)?.id
            }
            .navigationTransition_crossFade_IfAvailable()
        }
        .sheet(isPresented: $showSettingSheet) {
            ShadowingSettingsSheetView(playerVM: nil)
                .presentationDetents([.medium, .large])
                .navigationTransition_crossFade_IfAvailable()
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(videoStore.playlistCategories) { category in
                    categoryButton(category)
                }
            }
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func categoryButton(_ category: PlaylistCategory) -> some View {
        if category.id == selectedCategory?.id {
            Button {
                withAnimation(.snappy) {
                    selectedCategoryID = category.id
                }
            } label: {
                Text(category.title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .padding(.horizontal, sizeClassIsRegular ? 10 : 4)
                    .padding(.vertical, sizeClassIsRegular ? 8 : 2)
            }
            .buttonStyle_glass_IfAvailable()
            .foregroundStyle(.black)
            .background(.white.opacity(0.89), in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        } else {
            Button {
                withAnimation(.snappy) {
                    selectedCategoryID = category.id
                }
            } label: {
                Text(category.title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .padding(.horizontal, sizeClassIsRegular ? 10 : 4)
                    .padding(.vertical, sizeClassIsRegular ? 8 : 2)
                    .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
            }
            .buttonStyle_glass_IfAvailable()
            .foregroundStyle(.white)
        }
    }

    private func videoItemGrid(columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 24) {
            if filteredVideos.isEmpty {
                ContentUnavailableView(
                    "動画がありません",
                    systemImage: "video",
                    description: Text("右上の＋ボタンからリンクまたは再生リストに動画を追加してください")
                )
                .padding(.top, 200)
            } else {
                ForEach(filteredVideos) { video in
                    videoCard(video)
                }
                .LazyVGrid_reorderableIfAvailable()
            }
        }
        .id(selectedCategory?.id)
        .transition(.opacity)
        .animation(.snappy(duration: 0.35), value: filteredVideoIDs)
        .alert("動画を削除しますか？", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) {
                videoToDelete = nil
            }

            Button("削除", role: .destructive) {
                guard let video = videoToDelete else { return }
                videoToDelete = nil

                Task {
                    await MainActor.run {
                        playerVM.handleDeletedVideo(id: video.id)
                    }
                    await videoStore.deleteVideo(video.id)
                }
            }
        } message: {
            if let video = videoToDelete {
                Text(video.title.cleanedVideoTitle)
            }
            Text("動画を削除します。この操作は取り消せません。")
        }
    }

    @ViewBuilder
    private func videoCard(_ video: VideoItem) -> some View {
        let card = Button {
            onSelectVideo(video.id)
        } label: {
            videoListItemView(video)
        }
        .buttonStyle(.plain)

        if #available(iOS 27.0, *) {
            card.swipeActions {
                Button(role: .destructive) {
                    withAnimation(.spring(duration: 0.35)) {
                        videoStore.videos.removeAll { $0.id == video.id }
                    }
                    
                    Task {
                        playerVM.handleDeletedVideo(id: video.id)
                        await videoStore.deleteVideo(video.id)
                    }
                } label: {
                    Image(systemName: "trash")
                }
            }
        } else {
            card.highPriorityGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        videoToDelete = video
                        showingDeleteAlert = true
                    }
            )
        }
    }

    private func videoListItemView(_ video: VideoItem) -> some View {
        return VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay {
                    if let thumbnailURL = LocalThumbnailStorage.existingFileURL(for: video.id),
                       let data = try? Data(contentsOf: thumbnailURL),
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Color(.secondarySystemFill)
                            Image(systemName: "progress.indicator")
                        }
                    }
                }
                .matchedTransitionSourceIfAvailable(
                    id: "list-\(video.id)",
                    in: transitionNamespace!
                )
//                .matchedTransitionSource(
//                    id: "list-\(video.id)",
//                    in: transitionNamespace!
//                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(radius: 1)
                .contentShape(Rectangle())

            Text(video.title.cleanedVideoTitle)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
