//
//  VideoContentView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 5/4/R8.
//

import SwiftUI
import UIKit

struct VideoContentView: View {
    @Environment(AppNavigationStore.self) private var navigationStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(PlayerViewManager.self) private var playerVM
    @Environment(\.transitionNamespace) private var transitionNamespace

    @State private var videoPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $videoPath) {
            VideoListView { videoID in
                let sourceID = "list-\(videoID)"
                navigationStore.videoTransitionSourceID = sourceID
                navigationStore.presentedVideo = VideoSheetDestination(
                    id: videoID,
                    sourceID: sourceID,
                    dismissesToMiniPlayer: false
                )
            }
            .navigationDestination(for: QuickActionTarget.self) { target in
                if case .resumeVideo(let id) = target {
                    VideoDetailsFullScreenSheet(
                        videoID: id,
                        dismissesToMiniPlayer: false
                    ) {
                        guard !videoPath.isEmpty else { return }
                        let transitionSourceID = navigationStore.videoTransitionSourceID

                        videoPath.removeLast()

                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1))
                            if navigationStore.videoTransitionSourceID == transitionSourceID {
                                navigationStore.videoTransitionSourceID = nil
                            }
                        }
                    }
                    .navigationTransition(
                        .zoom(
                            sourceID: navigationStore.videoTransitionSourceID ?? "list-\(id)",
                            in: transitionNamespace!
                        )
                    )
                }
            }
        }
        .background(Color.black)
        .onChange(of: navigationStore.quickActionTarget) {_, target in
            guard let target else { return }

            if case .resumeVideo = target {
                if case .resumeVideo(let id) = target {
                    if navigationStore.videoTransitionSourceID?.hasPrefix("mini-") == true {
                        navigationStore.presentedVideo = VideoSheetDestination(
                            id: id,
                            sourceID: "mini-\(id)",
                            dismissesToMiniPlayer: true
                        )
                    } else {
                        navigationStore.videoTransitionSourceID = "list-\(id)"
                        videoPath.removeLast(videoPath.count)
                        videoPath.append(QuickActionTarget.resumeVideo(id: id))
                    }
                }

                navigationStore.clearTarget()
            }
        }
    }
}

struct VideoDetailsFullScreenSheet: View {
    @Environment(PlayerViewManager.self) private var playerVM
    let videoID: String
    let dismissesToMiniPlayer: Bool
    let onDismiss: () -> Void

    private let topCornerRadius: CGFloat = 48
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if dragOffset == 0 {
                    videoCoverView(playerVM: playerVM, sizeClass_regular: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                VStack(spacing: 0) {
                    Capsule()
                        .fill(.white.opacity(0.55))
                        .frame(width: 60, height: 4)
                        .frame(
                            maxHeight: .infinity,
                            alignment: .bottom
                        )
                        .frame(height: topSafeAreaInset + 11)
                        .contentShape(Rectangle())

                    VideoDetailsView(
                        videoID: videoID,
                        onDismissDragChanged: updateDrag,
                        onDismissDragEnded: { translation, predictedTranslation in
                            finishDrag(
                                translation: translation,
                                predictedTranslation: predictedTranslation,
                                screenSize: geometry.size
                            )
                        }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    videoCoverView(playerVM: playerVM, sizeClass_regular: false)
                        .ignoresSafeArea()
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: topCornerRadius,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: topCornerRadius
                    )
                )
                .offset(y: dragOffset)
                .simultaneousGesture(
                    topAreaDismissGesture(
                        screenSize: geometry.size,
                        maximumStartY: topSafeAreaInset + 84
                    )
                )
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(false)
        .persistentSystemOverlays(.visible)
    }

    private var topSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 0
    }

    private func topAreaDismissGesture(
        screenSize: CGSize,
        maximumStartY: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard value.startLocation.y <= maximumStartY else { return }
                updateDrag(value.translation.height)
            }
            .onEnded { value in
                guard value.startLocation.y <= maximumStartY else { return }
                finishDrag(
                    translation: value.translation.height,
                    predictedTranslation: value.predictedEndTranslation.height,
                    screenSize: screenSize
                )
            }
    }

    private func updateDrag(_ translation: CGFloat) {
        guard translation > 0 else { return }
        dragOffset = translation
    }

    private func finishDrag(
        translation: CGFloat,
        predictedTranslation: CGFloat,
        screenSize: CGSize
    ) {
        let dismissThreshold = screenSize.height * 0.4
        let shouldDismiss = translation > dismissThreshold || predictedTranslation > dismissThreshold

        if shouldDismiss {
            if dismissesToMiniPlayer {
                playerVM.isDetailVisible = false
            }

            onDismiss()
        } else {
            withAnimation(.spring(duration: 0.32, bounce: 0.15)) {
                dragOffset = 0
            }
        }
    }
}
