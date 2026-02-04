//
//  VideoContentView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/22.
//

import SwiftUI
import AVFoundation
import MediaPlayer
import AVKit
import Combine


struct VideoContentView: View {
    let videoID: String
    var video: VideoItem? {
        videoStore.videos.first { $0.id == videoID }
    }
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(VideoStore.self) private var videoStore
    @StateObject private var playerVM = PlayerViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettingSheet = false

    var body: some View {

        let isLoading = video == nil || video?.firstLoad == true

        Group {

            if isLoading {
                ProgressLoadingView()
            } else {

                ZStack {

                    GeometryReader { geo in
                        if let image = playerVM.nowPlayingArtwork {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .blur(radius: 70, opaque: true)
                                .overlay(Color.black.opacity(0.2))
                        } else {
                            Color.black.opacity(0.5)
                        }
                    }
                    .ignoresSafeArea()

                    VStack(spacing: 0) {

                        ZStack {

                            AVPlayerControllerView(player: playerVM.player)
                                .frame(height: 201)
                                .cornerRadius(15)
                                .opacity(playerVM.isVideoLoading ? 0 : 1)
                                .padding(.horizontal, 18)
                                .padding(.top, 0)
                                .padding(.bottom, 4)

                            if let image = playerVM.nowPlayingArtwork, playerVM.isVideoLoading {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 201)
                                    .cornerRadius(15)
                                    .padding(.horizontal, 18)
                                    .padding(.top, 0)
                                    .padding(.bottom, 4)
                                    .clipped()
                                    .opacity(playerVM.isVideoLoading ? 1 : 0)
                            }
                        }
                        .animation(.easeInOut(duration: 0.5), value: playerVM.isVideoLoading)

                        SubtitlesContentView(playerVM: playerVM)
                    }
                }
            }
        }
        .navigationTitle(video?.title ?? "何これ！")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettingSheet = true
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .toolbar(isLoading ? .hidden : .visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: video?.id) {
            guard let video else { return }
            playerVM.nowPlayingTitle = video.title

            if let url = video.thumbnailURL {
                Task.detached {
                    if let data = try? Data(contentsOf: url),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            playerVM.nowPlayingArtwork = image
                            playerVM.setupNowPlaying()
                        }
                    }
                }
            }

            Task {
                playerVM.startLoadVideo(for: video)
            }
        }
        .sheet(item: $playerVM.activeLookUpWordIdentifiable,
            onDismiss: {
                playerVM.activeLookUpWordIdentifiable = nil
                playerVM.playPlayer()
            }
        ) { item in
            DictionaryView(word: item.word)
                .ignoresSafeArea()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettingSheet) {
            ShadowingSettingsSheetView(playerVM: playerVM)
                .presentationDetents([.medium])
        }
        .onAppear {
            playerVM.inject(
                videoStore: videoStore,
                settingsStore: settingsStore
            )
        }
        .onDisappear {
            playerVM.resetPlayer()
        }
        .onChange(of: scenePhase) { _, phase in
            Task {
                if phase == .background {
                    playerVM.saveCurrentProgress()
                    playerVM.player.pause()
                    playerVM.isPlaying = false
                }
            }
        }
    }
}

struct SubtitlesContentView: View {
    @ObservedObject var playerVM: PlayerViewModel
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {

        ScrollViewReader { proxy in

            ScrollView {

                VStack(spacing: 12) {
                    Color.clear.frame(height: 2)
                    ForEach(playerVM.captions) { line in
                        SubtitlesRowView(
                            line: line,
                            isActive: playerVM.currentLineID == line.id,
                            currentLineID: { playerVM.currentLineID },
                            playerVM: playerVM,
                            onTapLine: {
                                playerVM.playLine(line)
                            },
                            onTapWord: { lineID, wordIndex in
                                playerVM.handleWordLookup(lineID, wordIndex)
                            }
                        )
                        .id(line.id)
                    }
                    Color.clear.frame(height: 10)
                }
                .animation(.easeInOut(duration: 1.0), value: playerVM.captions)
                .padding(.horizontal, 18)
            }
            .onChange(of: playerVM.currentLineID) { _, newID in
                guard let newID = newID else { return }

                if settingsStore.settings.videoSubtitleLineWithAnimation == .easeInOut {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(newID, anchor: .subtitleAnchor)
                    }
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        proxy.scrollTo(newID, anchor: .subtitleAnchor)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollToCurrentLine)) { _ in
                if let currentLineId = playerVM.currentLineID {

                    if settingsStore.settings.videoSubtitleLineWithAnimation == .easeInOut {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(currentLineId, anchor: .subtitleAnchor)
                        }
                    } else {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            proxy.scrollTo(currentLineId, anchor: .subtitleAnchor)
                        }
                    }
                }
            }
        }
    }
}

struct SubtitlesRowView: View {
    let line: CaptionLine
    let isActive: Bool
    let currentLineID: () -> String?
    @ObservedObject var playerVM: PlayerViewModel
    let onTapLine: () -> Void
    let onTapWord: (String, Int) -> Void
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        let ruby_show = (settingsStore.settings.showShadowingSubtitlesRuby ? line.ruby : [])!

        VStack(alignment: .leading) {
            RubyLabel(
                text: line.text,
                rubyWords: ruby_show,
                onTapWordAtIndex: { index in
                    let isNowActive = (currentLineID() == line.id)
                    if isNowActive {
                        if index != -1 {
                            onTapWord(line.id, index)
                        }
                    } else {
                        onTapLine()
                    }
                }
            )
            .id(settingsStore.settings.showShadowingSubtitlesRuby)
            .fixedSize(horizontal: false, vertical: true)
            .blur(radius: isActive ? 0 : 1.5)
            .opacity(isActive ? 1.0 : 0.4)
            .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
            .animation(.easeInOut(duration: 0.3), value: isActive)
        }
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
                Image(systemName: "gauge.with.needle")
                    .foregroundColor(.blue)

                Slider(
                    value: $playerVM.tempRate,
                    in: 0.5...1.25,
                    step: 0.05,
                    onEditingChanged: { editing in
                        if !editing {
                            playerVM.setRate(playerVM.tempRate)
                        }
                    }
                )
                .accentColor(.blue)

                Text("\(String(format: "%.2f", playerVM.tempRate))x")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 55)
                    .onTapGesture {
                        playerVM.setRate(1.0)
                    }
            }
            .padding(6)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Button(action: {
                playerVM.toggleSingleLineLoop()
            }) {
                Image(systemName: "repeat")
                    .foregroundColor(playerVM.isLoopingSingleLine ? .accentColor : .gray)
                    .contentShape(Rectangle())
                    .padding(5)
            }
            .buttonStyle(.plain)
        }
    }
}


struct WordIdentifiable: Identifiable {
    let id = UUID()
    let word: String
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
        vc.showsPlaybackControls = true
        vc.allowsPictureInPicturePlayback = false  // !!
        vc.videoGravity = .resizeAspect
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}


extension UnitPoint {
    static let subtitleAnchor = UnitPoint(x: 0.5, y: 0.25)
}
