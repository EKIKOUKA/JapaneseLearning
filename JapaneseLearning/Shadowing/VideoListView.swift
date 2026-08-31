//
//  VideoListView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/23.
//

import SwiftUI

struct VideoListView: View {
    let onSelectVideo: (String) -> Void

    @Environment(VideoStore.self) private var store
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(PlayerViewManager.self) private var playerVM
    @Environment(\.transitionNamespace) private var transitionNamespace
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showAddSheet: Bool = false
    @State private var showSettingSheet: Bool = false
    @State private var showPlayListSheet: Bool = false
    @State private var selectedVideo: VideoItem?
    @State private var selectedCategoryID: String?

    init(onSelectVideo: @escaping (String) -> Void = { _ in }) {
        self.onSelectVideo = onSelectVideo
    }

    private var filteredVideos: [VideoItem] {
        guard let selectedCategory else { return [] }
        return store.videos.filter { store.belongsToCategory($0, category: selectedCategory) }
    }

    private var selectedCategory: PlaylistCategory? {
        if let selectedCategoryID,
           let category = store.playlistCategories.first(where: { $0.id == selectedCategoryID }) {
            return category
        }

        return store.playlistCategories.first
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
                if store.videos.isEmpty {
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
                    .swipeActionsContainer()
                    .reorderContainer(for: VideoItem.self) { difference in
                        var reordered = filteredVideos
                        reordered.apply(difference: difference)

                        if let selectedCategory {
                            store.reorderVideos(reordered, for: selectedCategory)
                        }
                    }
                    .contentMargins(.top, 56, for: .scrollIndicators)
                }
            }
        }
        .navigationTitle("シャドーイング")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) {
            categoryPicker
                .padding(.vertical, 8)
                .padding(.bottom, 4)
        }
        .toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)
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
            AddVideoSheetView { result in
                selectedCategoryID = store.handleCategory(result)?.id
            }
            .navigationTransition(.crossFade)
        }
        .sheet(isPresented: $showSettingSheet) {
            ShadowingSettingsSheetView(playerVM: nil)
                .presentationDetents([.medium, .large])
                .navigationTransition(.crossFade)
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(store.playlistCategories) { category in
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
            .buttonStyle(.glass)
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
            .buttonStyle(.glass)
            .foregroundStyle(.white)
            .controlSize(sizeClassIsRegular ? .large : .regular)
        }
    }

    private func videoItemGrid(columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(filteredVideos) { video in
                Button {
                    onSelectVideo(video.id)
                } label: {
                    videoListItemView(video)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button(role: .destructive) {
                        withAnimation(.spring(duration: 0.35)) {
                            store.videos.removeAll { $0.id == video.id }
                        }

                        Task {
                            await MainActor.run {
                                playerVM.handleDeletedVideo(id: video.id)
                            }
                            await store.deleteVideo(video.id)
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .reorderable()
        }
        .id(selectedCategory?.id)
        .transition(.opacity)
        .animation(.snappy(duration: 0.35), value: filteredVideoIDs)
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
                            .id(video.thumbnailRefreshID)
                    } else {
                        ZStack {
                            Color(.secondarySystemFill)
                            Image(systemName: "progress.indicator")
                        }
                    }
                }
                .matchedTransitionSource(
                    id: "list-\(video.id)",
                    in: transitionNamespace!
                )
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
