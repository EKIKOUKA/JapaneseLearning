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
    @State private var showAddSheet = false
    @State private var showSettingSheet = false
    @State private var showPlayListSheet = false
    @State private var selectedVideo: VideoItem?
    @State private var showDeleteAlert = false
    @State private var pendingDeleteVideo: VideoItem?

    var body: some View {

        Group { // NavigationStack

            List {

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
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {

                    ForEach(store.videos) { video in

                        Button {
                            selectedVideo = video
                        } label: {
                            videoListItemView(video)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(
                            top: 6,
                            leading: 15,
                            bottom: 6,
                            trailing: 15
                        ))
                    }
                }
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 22)
            }
            .navigationDestination(item: $selectedVideo) { video in
                VideoContentView(videoID: video.id)
            }
            .onChange(of: store.videos) {
                store.saveVideo()
            }
        }
        .navigationTitle("シャドーイング")
        .navigationBarTitleDisplayMode(.automatic)
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
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddSheet) {
            YouTubeAddVideoSheetView()
                .presentationDetents([.medium, .large])
        }
        .alert("この動画を削除しますか？",
               isPresented: $showDeleteAlert,
               presenting: pendingDeleteVideo) { video in
            Button("削除", role: .destructive) {
                store.deleteVideo(video.id)
            }
        }
    }

    private func videoListItemView(_ video: VideoItem) -> some View {
        VStack(spacing: 8) {
            AsyncImage(url: video.thumbnailURL) { img in
                img.resizable()
                   .scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .cornerRadius(20)
            .clipped()

            Text(video.title)
                .font(.body)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                .padding(.bottom, 2)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(25)
        .onLongPressGesture {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            pendingDeleteVideo = video
            showDeleteAlert = true
        }
    }
}
