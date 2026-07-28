//
//  VideoDetailsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/22.
//

import SwiftUI
import AVKit

struct VideoDetailsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(VideoStore.self) private var videoStore
    @Environment(PlayerViewManager.self) private var playerVM
    @Environment(\.horizontalSizeClass) var sizeClass

    let videoID: String
    var video: VideoItem? {
        videoStore.videos.first { $0.id == videoID }
    }
    @State private var showSettingSheet = false
    @State private var drawerOffset: CGFloat = 0
    @State private var lastDragOffset: CGFloat = 0

    private var displayAspectRatio: CGFloat {
        guard let ratio = video?.aspectRatio, ratio > 0 else {
            return 16.0 / 9.0
        }

        return ratio
    }

    var body: some View {
        @Bindable var playerVM = playerVM
        let sizeClassRegular = sizeClass == .regular

        GeometryReader { geo in
            let fullWidth = geo.size.width
            let isLandscape = geo.size.width > geo.size.height
            let videoWidth = isLandscape ? fullWidth * 0.5 : fullWidth
            let currentVideoHeight = videoWidth / displayAspectRatio
            let layout = isLandscape
                ? AnyLayout(HStackLayout(spacing: 0))
                : AnyLayout(VStackLayout(spacing: 0))

            Group {
                if video == nil {
                    Color.clear.frame(height: 10)
                } else {
                    ZStack(alignment: .top) {
                        layout {
                            VideoContentArea(
                                playerVM: playerVM,
                                videoID: videoID,
                                drawerOffset: $drawerOffset,
                                lastDragOffset: $lastDragOffset,
                                maxDrawerOffset: currentVideoHeight,
                                containerWidth: fullWidth,
                                videoAspectRatio: displayVideoAspectRatio,
                                isLandscape: isLandscape
                            )

                            if playerVM.isProgressing {
                                Spacer()
                                ProgressLoadingView()
                                Spacer()
                            } else if playerVM.currentLineID != nil {
                                SubtitlesContentView(playerVM: playerVM)
                            } else {
                                Color.clear
                            }
                        }

                        if !isLandscape, drawerOffset >= currentVideoHeight {
                            playResumeVideoView(
                                drawerOffset: $drawerOffset,
                                lastDragOffset: $lastDragOffset,
                                maxDrawerOffset: currentVideoHeight
                            )
                        }
                    }
                    .background(
                        videoCoverView(playerVM: playerVM, sizeClass_regular: sizeClass_regular)
                    )
                }
            }
        }
        .navigationTitle(sizeClass_regular ? "" : (video?.title.cleanedVideoTitle ?? "読み込み中..."))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if sizeClass_regular && !playerVM.isVideoLoading {
                ToolbarItem(placement: .principal) {
                    Text(video?.title.cleanedVideoTitle ?? "読み込み中...")
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showSettingSheet = true
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        .task(id: video?.id) {
            guard let video else { return }
            playerVM.prepareVideo(video)
        }
        .sheet(item: $playerVM.activeLookUpWordIdentifiable,
               onDismiss: {
            playerVM.activeLookUpWordIdentifiable = nil
            playerVM.playPlayer()
        }) { item in
            DictionaryView(word: item.word)
                .ignoresSafeArea()
                .presentationDetents(sizeClassRegular ? [.large] : [.medium, .large])
                .presentationDragIndicator(sizeClassRegular ? .hidden : .visible)
                .navigationTransition(.crossFade)
        }
        .sheet(isPresented: $showSettingSheet) {
            ShadowingSettingsSheetView(playerVM: playerVM)
                .presentationDetents(sizeClassRegular ? [.large] : [.medium, .large])
                .presentationDragIndicator(.visible)
                .navigationTransition(.crossFade)
        }
        .onAppear {
            playerVM.isDetailVisible = true
            playerVM.syncCaptionToCurrentPlayback()
            playerVM.startPracticeTimingIfNeeded()
        }
        .onDisappear {
            playerVM.isDetailVisible = false
            let currentTime = playerVM.currentPlaybackTime()

            Task {
                await playerVM.saveCurrentProgress(currentTimeOverride: currentTime)
                await playerVM.stopPracticeTimingAndSync()
            }
        }
    }
}

struct videoCoverView: View {
    let playerVM: PlayerViewManager
    let sizeClass_regular: Bool

    var body: some View {
        if let image = playerVM.nowPlayingArtwork {
            Canvas { context, size in
                context.draw(
                    Image(uiImage: image)
                        .resizable(),
                    in: CGRect(origin: .zero, size: size)
                )
            }
            .ignoresSafeArea()
            .blur(radius: sizeClass_regular ? 100 : 64, opaque: true)
            .overlay(Color.black.opacity(0.2))
        } else {
            Color.black.opacity(0.1)
        }
    }
}

struct VideoContentArea: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(SettingsStore.self) private var settingsStore
    let playerVM: PlayerViewManager
    let videoID: String
    @Binding var drawerOffset: CGFloat
    @Binding var lastDragOffset: CGFloat
    let maxDrawerOffset: CGFloat
    let containerWidth: CGFloat
    let aspectRatio: CGFloat
    let isLandscape: Bool

    var body: some View {
        let videoWidth = max(0, isLandscape ? containerWidth * 0.5 : containerWidth)
        let baseHeight = max(0, videoWidth / aspectRatio)

        VStack(spacing: 0) {
            if isLandscape {
                Spacer()
            }

            ZStack {
                if let image = playerVM.playerNowPlaying.nowPlayingArtwork {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .opacity(drawerOffset >= maxDrawerOffset ? 0 : 1)
                } else {
                    Color.black.opacity(0.1)
                }

                AVPlayerControllerView(player: playerVM.player)
                    .id(videoID)
                    .opacity(!isPlayerReady || drawerOffset >= maxDrawerOffset ? 0 : 1)
            }
            .animation(.easeInOut(duration: 1.0), value: isPlayerReady)
            .frame(width: videoWidth, height: baseHeight)
            .frame(
                height: isLandscape ? baseHeight : max(0, baseHeight - drawerOffset),
                alignment: .bottom
            )
            .clipped()

            if isLandscape {
                Spacer()
            }
        }
        .background(Color.clear)
        .padding(.bottom, 2)
        .highPriorityGesture(
            isLandscape ? nil :
                DragGesture()
                .onChanged { value in
                    let offset = lastDragOffset - value.translation.height
                    drawerOffset = min(max(offset, 0), baseHeight)
                }
                .onEnded { _ in
                    let shouldCollapse = drawerOffset > baseHeight * 0.25

                    if shouldCollapse {
                        withAnimation(.snappy(duration: 0.25, extraBounce: 0.0)) {
                            drawerOffset = baseHeight
                        }
                    } else {
                        withAnimation(.snappy(duration: 0.25, extraBounce: 0.15)) {
                            drawerOffset = 0
                        }
                    }

                    lastDragOffset = drawerOffset
                }
        )
    }
}

struct SubtitlesContentView: View {
    private struct VisibleCaptionRow: Identifiable {
        let index: Int
        let line: CaptionLine

        var id: String { line.id }
    }

    let playerVM: PlayerViewManager
    @Environment(SettingsStore.self) private var settingsStore
    @State private var scrollTargetID: String?
    @State private var containerHeight: CGFloat = 0
    @State private var lastHeight: CGFloat = 0
    @State private var heightStableTimer: Timer?

    var body: some View {
        let showShadowingSubtitlesRuby = settingsStore.showShadowingSubtitlesRuby
        let fontSizeScale = settingsStore.videoSubtitleFontSizeScale
        let fontStyle = settingsStore.videoSubtitleFontStyle
        let fontColor = settingsStore.videoSubtitleFontUIColor
        let blurInactiveLines = settingsStore.videoSubtitleDimInactiveLines
        let lineAnimation = settingsStore.videoSubtitleLineWithAnimation
        let visibleCaptions = playerVM.visiableCaptions
        let visibleRows = visibleCaptions.map { VisibleCaptionRow(index: $0.0, line: $0.1) }

        GeometryReader { geo in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 2)
                    ForEach(visibleRows) { row in
                        SubtitlesRowView(
                            playerVM: playerVM,
                            line: row.line,
                            isActive: playerVM.currentLineID == row.line.id,
                            rubyRanges: showShadowingSubtitlesRuby ? row.line.rubyRanges : [],
                            fontSizeScale: fontSizeScale,
                            fontStyle: fontStyle,
                            fontColor: fontColor,
                            blurInactiveLines: blurInactiveLines,
                            onTapLine: {
                                Task {
                                    await playerVM.playLine(row.line, row.index)
                                }
                            }
                        )
                        .equatable()
                    }
                    Color.clear.frame(height: 250)
                }
                .scrollTargetLayout()
                .scrollIndicatorStyle(.white)
            }
            .transaction { transaction in
                transaction.animation = nil
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .scrollPosition(id: $scrollTargetID, anchor: .subtitleAnchor)
            .task {
                if let currentLineID = playerVM.currentLineID {
                    scrollTargetID = currentLineID
                }
            }
            .onChange(of: playerVM.currentLineID) { _, new in
                guard let newID = new else { return }

                if lineAnimation == .easeInOut {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        scrollTargetID = newID
                    }
                } else {
                    withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.5)) {
                        scrollTargetID = newID
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollToCurrentLine)) { _ in
                guard let currentLineId = playerVM.currentLineID else { return }

                if abs(containerHeight - lastHeight) < 1 {
                    if lineAnimation == .easeInOut {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            scrollTargetID = currentLineId
                        }
                    } else {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            scrollTargetID = currentLineId
                        }
                    }
                } else {
                    heightStableTimer?.invalidate()
                    heightStableTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                        Task { @MainActor in
                            if lineAnimation == .easeInOut {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    scrollTargetID = currentLineId
                                }
                            } else {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                    scrollTargetID = currentLineId
                                }
                            }
                        }
                    }
                }
            }
            .onChange(of: geo.size.height) { _, newHeight in
                lastHeight = containerHeight
                containerHeight = newHeight
            }
        }
    }
}

struct SubtitlesRowView: View, Equatable {
    static func == (lhs: SubtitlesRowView, rhs: SubtitlesRowView) -> Bool {
        lhs.line == rhs.line &&
        lhs.isActive == rhs.isActive &&
        lhs.rubyRanges == rhs.rubyRanges &&
        lhs.fontSizeScale == rhs.fontSizeScale &&
        lhs.fontStyle == rhs.fontStyle &&
        lhs.fontColor == rhs.fontColor &&
        lhs.blurInactiveLines == rhs.blurInactiveLines
    }

    let playerVM: PlayerViewManager
    let line: CaptionLine
    let isActive: Bool
    let rubyRanges: [RubyWordRange]
    let fontSizeScale: Double
    let fontStyle: VideoSubtitleRubyFontStyle
    let fontColor: UIColor
    let blurInactiveLines: Bool
    let onTapLine: () -> Void

    @State private var tapHighlight = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(tapHighlight ? 0.15 : 0))
                .padding(.horizontal, 10)

            RubyLabel(
                text: line.text,
                rubyRanges: rubyRanges,
                cachedAttributedString: line.cachedAttributedString,
                fontSizeScale: fontSizeScale,
                fontStyle: fontStyle,
                fontColor: fontColor,
                onTapWord: { word in
                    if isActive {
                        playerVM.handleWordLookup(word)
                    } else {
                        triggerHighlight()
                        onTapLine()
                    }
                },
                onTapLine: {
                    triggerHighlight()
                    onTapLine()
                }
            )
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .blur(radius: isActive || !blurInactiveLines ? 0 : 1.5)
            .opacity(!isActive || (tapHighlight && isActive) ? 0.5 : 1.0)
            .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)
            .scaleEffect(tapHighlight ? 0.96 : 1.0, anchor: .center)
            .animation(tapHighlight ? .easeOut(duration: 0.1) : .spring(response: 0.4, dampingFraction: 0.6), value: tapHighlight)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    private func triggerHighlight() {
        withAnimation(.easeOut(duration: 0.08)) {
            tapHighlight = true
        }

        Task {
            try? await Task.sleep(for: .seconds(0.2))

            withAnimation(.easeInOut(duration: 0.5)) {
                tapHighlight = false
            }
            .padding(.horizontal, 0)
        } else {
            VStack(spacing: 0) { content() }
        }
    }
}

struct AVPlayerControllerView: UIViewControllerRepresentable {
    let player: AVPlayer
    @Environment(SettingsStore.self) private var settingsStore

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        player.allowsExternalPlayback = true
        vc.showsPlaybackControls = true
        vc.allowsPictureInPicturePlayback = settingsStore.videoAllowsPictureInPicturePlayback ? true : false
        vc.canStartPictureInPictureAutomaticallyFromInline = false
        vc.updatesNowPlayingInfoCenter = false
        vc.videoGravity = .resizeAspect

        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if vc.player !== player {
            vc.player = player
        }

        vc.allowsPictureInPicturePlayback = settingsStore.videoAllowsPictureInPicturePlayback
        vc.canStartPictureInPictureAutomaticallyFromInline = false
        vc.updatesNowPlayingInfoCenter = false
        vc.videoGravity = .resizeAspect
    }
}
