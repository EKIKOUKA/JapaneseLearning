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
    @State private var categoryScrollPosition = ScrollPosition(idType: String.self)

    init(onSelectVideo: @escaping (String) -> Void = { _ in }) {
        self.onSelectVideo = onSelectVideo
    }

    private var selectedCategory: PlaylistCategory? {
        if let selectedCategoryID,
           let category = videoStore.playlistCategories.first(where: { $0.id == selectedCategoryID }) {
            return category
        }

        return videoStore.playlistCategories.first
    }

    private var selectedCategoryIndex: Int? {
        videoStore.playlistCategories.firstIndex { $0.id == selectedCategory?.id }
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

                    let category = selectedCategory
                    let videos = category.map { category in
                        videoStore.videos.filter { videoStore.belongsToCategory($0, category: category) }
                    } ?? []

                    ScrollView {
                        videoItemGrid(columns: columns, videos: videos)
                            .id(category?.id)
                            .transition(.opacity)
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                            .padding(.bottom, 20)
                    }
                    .swipeActionsContainerIfAvailable()
                    .contentMargins(.top, 60, for: .scrollIndicators)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                let horizontal = value.translation.width
                                guard abs(horizontal) >= 40,
                                      abs(horizontal) > abs(value.translation.height) * 1.5,
                                      let current = selectedCategoryIndex
                                else { return }

                                let categories = videoStore.playlistCategories
                                let next = current + (horizontal < 0 ? 1 : -1)
                                guard categories.indices.contains(next) else { return }

                                withAnimation(.snappy) {
                                    selectedCategoryID = categories[next].id
                                }
                            },
                        including: settingsStore.videoCategorySwipeEnabled ? .all : .subviews
                    )
                }
            }
            .refreshable { await videoStore.fetchVideos() }
        }
        .alert("動画を追加できませんでした", isPresented: Binding(
            get: { videoStore.uploadError != nil },
            set: { if !$0 { videoStore.uploadError = nil } }
        )) {
            Button("OK") { videoStore.uploadError = nil }
        } message: {
            Text(videoStore.uploadError ?? "")
        }
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
        .navigationTitle("ホーム")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) {
            categoryPicker
                .padding(.vertical, 4)
        }
        .toolbarMinimizeNavigationBarIfAvailable()
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
            .navigationTransitionCrossFadeIfAvailable()
        }
        .sheet(isPresented: $showSettingSheet) {
            ShadowingSettingsSheetView(playerVM: nil)
                .presentationDetents([.medium, .large])
                .navigationTransitionCrossFadeIfAvailable()
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(videoStore.playlistCategories) { category in
                    categoryButton(category)
                        .id(category.id)
                }
            }
            .padding(.horizontal, 14)
        }
        .scrollPosition($categoryScrollPosition, anchor: .center)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .onChange(of: selectedCategory?.id) { _, id in
            guard let id else { return }
            
            withAnimation(.snappy) {
                categoryScrollPosition.scrollTo(id: id, anchor: .center)
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }
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
            .buttonStyle(.glass)
            .foregroundStyle(.black)
            .background(.white, in: Capsule())
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
            .buttonStyle(.glass)
            .foregroundStyle(.white)
        }
    }

    private func videoItemGrid(columns: [GridItem], videos: [VideoItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 24) {
            if videos.isEmpty {
                ContentUnavailableView(
                    "動画がありません",
                    systemImage: "video",
                    description: Text("右上の＋ボタンからリンクまたは再生リストに動画を追加してください")
                )
                .padding(.top, 200)
            } else {
                ForEach(videos) { video in
                    videoCard(video)
                }
                .reorderableIfAvailable()
            }
        }
        .animation(.snappy(duration: 0.35), value: videos.map(\.id))
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
            videoListItemView(video)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelectVideo(video.id)
                }
                .onLongPressGesture(minimumDuration: 0.15) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    videoToDelete = video
                    showingDeleteAlert = true
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    onSelectVideo(video.id)
                }
                .accessibilityAction(named: Text("削除")) {
                    videoToDelete = video
                    showingDeleteAlert = true
                }
        }
    }

    private func videoListItemView(_ video: VideoItem) -> some View {
        return VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay {
                    if let thumbnailURL = AppGroupThumbnailStorage.existingFileURL(for: video.id),
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
                .id(video.thumbnailRefreshID)
                .matchedTransitionSource(
                    id: "list-\(video.id)",
                    in: transitionNamespace!
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
