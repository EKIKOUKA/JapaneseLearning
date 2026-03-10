//
//  VideoContentView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/22.
//

import SwiftUI
import AVKit
import WebKit

struct VideoContentView: View {
    let videoID: String
    var video: VideoItem? {
        videoStore.videos.first { $0.id == videoID }
    }
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(VideoStore.self) private var videoStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) var sizeClass
    @StateObject private var playerVM = PlayerViewModel()
    @State private var showSettingSheet = false
    @State private var drawerOffset: CGFloat = 0
    @State private var lastDragOffset: CGFloat = 0
    @State private var buttonAppearOffset: CGFloat = -15
    let maxDrawerOffset: CGFloat = 201

    var body: some View {
        @State var sizeClass_regular = sizeClass == .regular

        GeometryReader { geo in

            let fullWidth = geo.size.width
            let isLandscape = geo.size.width > geo.size.height

            let videoWidth = isLandscape ? fullWidth * 0.5 : (fullWidth - 36)
            let currentVideoHeight = videoWidth * 9 / 16

            Group {

                if video == nil {
                    // ProgressLoadingView()
                    Color.clear.frame(height: 10)
                } else {

                    ZStack {

                        AdaptiveStack(isSideBySide: isLandscape) {

                            videoContentArea(
                                playerVM: playerVM,
                                drawerOffset: $drawerOffset,
                                lastDragOffset: $lastDragOffset,
                                maxDrawerOffset: maxDrawerOffset,
                                containerWidth: fullWidth,
                                isLandscape: isLandscape
                            )

                            if playerVM.isProgressing {
                                Spacer()
                                ProgressLoadingView()
                                Spacer()
                            } else {
                                SubtitlesContentView(playerVM: playerVM)
                            }
                        }

                        if !isLandscape {
                            playResumeVideoView(
                                drawerOffset: $drawerOffset,
                                lastDragOffset: $lastDragOffset,
                                buttonAppearOffset: $buttonAppearOffset,
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
        .navigationTitle(sizeClass_regular ? "" : (video?.title ?? "読み込み中..."))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if sizeClass_regular && !playerVM.isVideoLoading {
                ToolbarItem(placement: .principal) {
                    Text(video?.title ?? "読み込み中...")
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
                .presentationDetents(sizeClass_regular ? [.large] : [.medium, .large])
                .presentationDragIndicator(sizeClass_regular ? .hidden : .visible)
        }
        .sheet(isPresented: $showSettingSheet) {
            ShadowingSettingsSheetView(playerVM: playerVM)
                .presentationDetents(sizeClass_regular ? [.large] : [.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            playerVM.inject(
                videoStore: videoStore,
                settingsStore: settingsStore
            )
        }
        .onDisappear {
            Task { @MainActor in
                await playerVM.saveCurrentProgress()
                playerVM.resetPlayer()
            }
        }
        .onChange(of: scenePhase, initial: false) {
            Task {
                if scenePhase == .background {
                    await playerVM.saveCurrentProgress()
                }
            }
        }
    }
}

struct videoCoverView: View {
    @ObservedObject var playerVM: PlayerViewModel
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

struct videoContentArea: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @ObservedObject var playerVM: PlayerViewModel
    @Binding var drawerOffset: CGFloat
    @Binding var lastDragOffset: CGFloat
    let maxDrawerOffset: CGFloat
    let containerWidth: CGFloat
    let isLandscape: Bool

    var body: some View {

        let videoWidth = max(0, isLandscape ? containerWidth * 0.5 : (containerWidth - 36))
        let baseHeight = max(0, videoWidth * 9 / 16)

        VStack(spacing: 0) {
            if isLandscape {
                Spacer()
            }

            ZStack {

                if playerVM.isVideoLoading, let image = playerVM.nowPlayingArtwork {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .opacity(playerVM.isVideoLoading ? 1 : 0)
                }

                AVPlayerControllerView(player: playerVM.player)
                    .opacity(playerVM.isVideoLoading ? 0 : 1)
            }
            .animation(.easeInOut(duration: 0.75), value: playerVM.isVideoLoading)
            .frame(width: videoWidth, height: baseHeight)
            .cornerRadius(30)
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
        .padding(.horizontal, 18)
        .highPriorityGesture(
            isLandscape ? nil :
                DragGesture()
                .onChanged { value in
                    let offset = lastDragOffset - value.translation.height
                    drawerOffset = min(max(offset, 0), baseHeight)
                }
                .onEnded { _ in
                    let shouldCollapse = drawerOffset > baseHeight * 0.35

                    if shouldCollapse {
                        withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                            drawerOffset = baseHeight
                        }
                    } else {
                        withAnimation(.interpolatingSpring(stiffness: 120, damping: 13)) {
                            drawerOffset = 0
                        }
                    }

                    lastDragOffset = drawerOffset
                }
        )
    }
}

struct playResumeVideoView: View {
    @Binding var drawerOffset: CGFloat
    @Binding var lastDragOffset: CGFloat
    @Binding var buttonAppearOffset: CGFloat
    let maxDrawerOffset: CGFloat

    private var isCollapsed: Bool {
        drawerOffset >= maxDrawerOffset
    }

    var body: some View {

        Button {
            withAnimation(.interpolatingSpring(stiffness: 120, damping: 13)) {
                drawerOffset = 0
                lastDragOffset = 0
            }
        } label: {
            Label {
                Text("ビデオを表示")
                    .font(.system(size: 15, weight: .medium))
            } icon: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.primary)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 5)
        .offset(y: buttonAppearOffset)
        .opacity(isCollapsed ? 0.9 : 0)
        .allowsHitTesting(isCollapsed)
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .onChange(of: isCollapsed) { _, isVisible in
            if isVisible {
                buttonAppearOffset = -15
                withAnimation(.interpolatingSpring(stiffness: 260, damping: 18)) {
                    buttonAppearOffset = 0
                }
            }
        }
    }
}

struct SubtitlesContentView: View {
    @ObservedObject var playerVM: PlayerViewModel
    @Environment(SettingsStore.self) private var settingsStore
    @State private var scrollTargetID: String?

    var body: some View {

        ScrollView {

            VStack(spacing: 12) {
                Color.clear.frame(height: 2)
                ForEach(Array(playerVM.captions.indices), id: \.self) { index in
                    let line = playerVM.captions[index]

                    SubtitlesRowView(
                        playerVM: playerVM,
                        line: line,
                        isActive: playerVM.currentLineID == line.id,
                        currentLineID: { playerVM.currentLineID },
                        onTapLine: {
                            Task {
                                await playerVM.playLine(line, index)
                            }
                        }
                    )
                    .id(line.id)
                }
                Color.clear.frame(height: 20)
            }
            .ScrollIndicatorStyle(.white)
            .animation(.easeInOut(duration: 1.0), value: playerVM.captions)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .scrollPosition(id: $scrollTargetID, anchor: .subtitleAnchor)
        .onChange(of: playerVM.currentLineID) { _, new in
            guard let newID = new else { return }

            if settingsStore.videoSubtitleLineWithAnimation == .easeInOut {
                withAnimation(.easeInOut(duration: 0.4)) {
                    scrollTargetID = newID
                }
            } else {
                withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.32)) { // .spring()
                    scrollTargetID = newID
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scrollToCurrentLine)) { _ in
            if let currentLineId = playerVM.currentLineID {

                if settingsStore.videoSubtitleLineWithAnimation == .easeInOut {
                    withAnimation(.easeInOut(duration: 0.4)) {
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

struct SubtitlesRowView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @ObservedObject var playerVM: PlayerViewModel
    let line: CaptionLine
    let isActive: Bool
    let currentLineID: () -> String?
    let onTapLine: () -> Void

    @State private var tapHighlight = false

    var body: some View {
        let ruby_show: [RubyWord] = settingsStore.showShadowingSubtitlesRuby ? (line.ruby ?? []) : []
        let font_size = settingsStore.videoSubtitleFontSizeScale
        let font_style = settingsStore.videoSubtitleFontStyle
        let font_color = settingsStore.videoSubtitleFontUIColor
        let blur_opacity = settingsStore.videoSubtitleDimInactiveLines

        ZStack(alignment: .leading) {

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(tapHighlight ? 0.15 : 0))

            RubyLabel(
                text: line.text,
                rubyWords: ruby_show,
                fontSizeScale: font_size,
                fontStyle: font_style,
                fontColor: font_color,
                onTapWord: { word in
                    if currentLineID() == line.id {
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
            .id(settingsStore.showShadowingSubtitlesRuby)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 6)
            .padding(.horizontal, 20)
            .blur(radius: isActive || !blur_opacity ? 0 : 1.5)
            .opacity(!isActive || (tapHighlight && isActive) ? 0.5 : 1.0)
            .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)

            .scaleEffect(tapHighlight ? 0.96 : 1.0, anchor: .center)
            .animation(tapHighlight ? .easeOut(duration: 0.1) : .spring(response: 0.4, dampingFraction: 0.6), value: tapHighlight)

            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func triggerHighlight() {
        withAnimation(.easeOut(duration: 0.08)) {
            tapHighlight = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.5)) {
                tapHighlight = false
            }
        }
    }
}

struct VideoControlView: View {
    @ObservedObject var playerVM: PlayerViewModel

    var body: some View {

        HStack {

            /* Button {
                if let text = playerVM.currentLineText() {
                    print("Current line:", text)
                } else {
                    print("No active line")
                }
            } label: {
                Image(systemName: "text.quote")
            } */
            Button {
                NotificationCenter.default.post(name: .scrollToCurrentLine, object: nil)
            } label: {
                Image(systemName: "scope")
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)

            HStack {

                Image(systemName: "tortoise.fill")
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        if playerVM.tempRate > 0.5 {
                            playerVM.tempRate = max(playerVM.tempRate - 0.05, 0.5)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }

                ZStack {

                    GeometryReader { geo in
                        let minRate: Double = 0.50
                        let maxRate: Double = 1.25
                        let range = maxRate - minRate
                        let temp_rate = min(playerVM.tempRate, 1.25)

                        let progress = (Double(temp_rate) - minRate) / range
                        let thumbOffset = CGFloat(progress) * (geo.size.width - 30) + 15

                        let selectionFeedback = UISelectionFeedbackGenerator()

                        Slider(
                            value: $playerVM.tempRate,
                            in: 0.5...1.25,
                            step: 0.05,
                            onEditingChanged: { editing in
                                if !editing {
                                    playerVM.setRate(Float(playerVM.tempRate))
                                }
                                if editing { selectionFeedback.prepare() }
                            }
                        )
                        .onChange(of: playerVM.tempRate) { _, newValue in
                            if newValue == 1.0 {
                                selectionFeedback.selectionChanged()
                            }
                        }

                        Text("\(String(format: "%.2f", playerVM.tempRate))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.9))
                            .position(x: thumbOffset, y: 15)
                            .allowsHitTesting(false)
                    }
                    .frame(height: 30)
                }

                Image(systemName: "hare.fill")
                    .foregroundStyle(.secondary)
                    .onTapGesture {
                        if playerVM.tempRate < 2.0 {
                            playerVM.tempRate = min(playerVM.tempRate + 0.05, 2.0)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
            }
            .padding(6)
            .padding(.trailing, 0)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Button(action: {
                playerVM.toggleSingleLineLoop()
            }) {
                Image(systemName: "repeat")
                    .foregroundColor(playerVM.isLoopingSingleLine ? .accentColor : .gray)
                    .contentShape(Rectangle())
                    .padding(.horizontal, 0)
            }
            .buttonStyle(.plain)
        }
    }
}

struct VideoSubtitleFontSizeSliderView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var tempFontSize: Double = 1.0

    var body: some View {
        @Bindable var settingsStoreBindable = settingsStore

        HStack {

            Image(systemName: "textformat.size.smaller")
                .foregroundColor(.secondary)
                .onTapGesture {
                    if settingsStoreBindable.videoSubtitleFontSizeScale > 0.70 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        let newValue = max(
                            settingsStoreBindable.videoSubtitleFontSizeScale - 0.05,
                            0.70
                        )
                        settingsStoreBindable.videoSubtitleFontSizeScale = newValue
                        tempFontSize = newValue
                    }
                }

            ZStack {

                GeometryReader { geo in
                    let minTempSizeScale: Double = 0.80
                    let maxTempSizeScale: Double = 1.20
                    let range = maxTempSizeScale - minTempSizeScale
                    let tempSizeScale = max(minTempSizeScale, min(maxTempSizeScale, tempFontSize))

                    let progress = (Double(tempSizeScale) - minTempSizeScale) / range
                    let thumbOffset = CGFloat(progress) * (geo.size.width - 30) + 15

                    let selectionFeedback = UISelectionFeedbackGenerator()

                    Slider(
                        value: $tempFontSize,
                        in: minTempSizeScale...maxTempSizeScale,
                        step: 0.05,
                        onEditingChanged: { editing in
                            if !editing {
                                settingsStoreBindable.videoSubtitleFontSizeScale = tempFontSize
                            }
                            if editing { selectionFeedback.prepare() }
                        }
                    )
                    .onChange(of: tempFontSize) { _, newValue in
                        if newValue == 1.0 {
                            selectionFeedback.selectionChanged()
                        }
                    }

                    Text(String(format: "%.2f", tempFontSize))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.9))
                        .position(x: thumbOffset, y: 15)
                        .allowsHitTesting(false)
                }
                .frame(height: 32)
            }

            Image(systemName: "textformat.size.larger")
                .foregroundColor(.secondary)
                .onTapGesture {
                    if settingsStoreBindable.videoSubtitleFontSizeScale < 1.40 {
                        let newValue = min(
                            settingsStoreBindable.videoSubtitleFontSizeScale + 0.05,
                            1.40
                        )
                        settingsStoreBindable.videoSubtitleFontSizeScale = newValue
                        tempFontSize = newValue
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
        }
        .onAppear {
            tempFontSize = settingsStoreBindable.videoSubtitleFontSizeScale
        }
        .onChange(of: settingsStoreBindable.videoSubtitleFontSizeScale) { _, newValue in
            if tempFontSize != newValue {
                tempFontSize = newValue
            }
        }
    }
}

// 💡 輔助組件：自動根據環境切換 HStack 或 VStack
struct AdaptiveStack<Content: View>: View {
    var isSideBySide: Bool
    let content: () -> Content

    init(isSideBySide: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.isSideBySide = isSideBySide
        self.content = content
    }

    var body: some View {
        if isSideBySide {
            HStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 0)
        } else {
            VStack(spacing: 0) { content() }
        }
    }
}

struct DictionaryView: UIViewControllerRepresentable {
    let word: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        return UIReferenceLibraryViewController(term: word)
    }

    func updateUIViewController(_ uiViewController: UIReferenceLibraryViewController, context: Context) {}
}

struct AVPlayerControllerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        player.allowsExternalPlayback = true
        vc.showsPlaybackControls = true
        vc.allowsPictureInPicturePlayback = false
        vc.videoGravity = .resizeAspect
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}


extension UnitPoint {
    static let subtitleAnchor = UnitPoint(x: 0.5, y: 0.3)
}
