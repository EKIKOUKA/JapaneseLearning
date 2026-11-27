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
                        Task { await playerVM.endVideo(videoID: id) }

                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1))
                            if navigationStore.videoTransitionSourceID == transitionSourceID {
                                navigationStore.videoTransitionSourceID = nil
                            }
                        }
                    }
                    .navigationTransition_Zoom_IfAvailable(sourceID: navigationStore.videoTransitionSourceID ?? "list-\(id)", in: transitionNamespace!)
                }
            }
        }
        .background(Color.black)
        .onChange(of: navigationStore.quickActionTarget, initial: true) { _, target in
            guard let target, case .resumeVideo(let id) = target else { return }

            if navigationStore.videoTransitionSourceID == "mini-\(id)" {
                navigationStore.presentedVideo = VideoSheetDestination(
                    id: id,
                    sourceID: "mini-\(id)",
                    dismissesToMiniPlayer: true
                )
            } else {
                navigationStore.videoTransitionSourceID = "list-\(id)"
                videoPath = NavigationPath()
                videoPath.append(target)
            }

            navigationStore.clearTarget()
        }
    }
}

struct VideoDetailsFullScreenSheet: View {
    @Environment(PlayerViewManager.self) private var playerVM
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let videoID: String
    let dismissesToMiniPlayer: Bool
    let onDismiss: () -> Void

    let podcastCover: UIImage?
    @State private var dragOffset: CGFloat = 0

    init(videoID: String, dismissesToMiniPlayer: Bool, onDismiss: @escaping () -> Void) {
        self.videoID = videoID
        self.dismissesToMiniPlayer = dismissesToMiniPlayer
        self.onDismiss = onDismiss
        if let episode = PodcastLibrary.shared.episode(id: videoID) {
            podcastCover = LocalThumbnailStorage.existingFileURL(for: videoID)
                .flatMap { UIImage(contentsOfFile: $0.path) }
                ?? LocalThumbnailStorage.podcastArtwork(url: episode.artworkURL, fallbackURL: episode.showArtworkURL)
        } else {
            podcastCover = nil
        }
    }

    private var isMac: Bool {
        ProcessInfo.processInfo.isiOSAppOnMac
    }

    private var isRegular: Bool {
        horizontalSizeClass == .regular || isMac
    }

    private var topCornerRadius: CGFloat {
        if isMac {
            return 0
        }

        switch UIDevice.current.userInterfaceIdiom {
            case .pad:
                return 16
            case .phone:
                return 48
            default:
                return 16
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let safeTop = max(geometry.safeAreaInsets.top, topSafeAreaInset)

            let isPodcast = PodcastLibrary.shared.episode(id: videoID) != nil

            ZStack {
                VStack(spacing: 0) {
                    if !isPodcast {
                        dragHandle(safeTop: safeTop)
                    }

                    VideoDetailsView(
                        videoID: videoID,
                        podcastStatusBarHeight: safeTop,
                        podcastCover: podcastCover,
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
                .overlay(alignment: .top) {
                    if isPodcast {
                        dragHandle(safeTop: safeTop)
                            .allowsHitTesting(false)
                    }
                }
                .background {
                    videoCoverView(
                        artwork: isPodcast ? podcastCover : playerVM.playerNowPlaying.nowPlayingArtwork,
                        sizeClass_regular: isRegular,
                        usesNeutralFallback: isPodcast
                    )
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
                .overlay {
                    if playerVM.practiceStartedAt != nil {
                        ShadowingPracticeBorder(cornerRadius: topCornerRadius)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .offset(y: dragOffset)
                .simultaneousGesture(
                    topAreaDismissGesture(
                        screenSize: geometry.size,
                        maximumStartY: safeTop + 84
                    )
                )
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(false)
        .persistentSystemOverlays(.visible)
    }

    private func dragHandle(safeTop: CGFloat) -> some View {
        Capsule()
            .fill(.white.opacity(0.55))
            .frame(width: 60, height: 4)
            .frame(height: safeTop + 11, alignment: .bottom)
            .contentShape(Rectangle())
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

private struct ShadowingPracticeBorder: View {
    let cornerRadius: CGFloat
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bright = false

    private var breathes: Bool {
        scenePhase == .active && !reduceMotion
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
        .strokeBorder(Color.accentColor, lineWidth: 6)
        .opacity(bright ? 0.85 : 0.3)
        .animation(
            breathes ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : nil,
            value: bright
        )
        .onChange(of: breathes, initial: true) { _, active in
            bright = active
        }
    }
}
