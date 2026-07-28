//
//  VideoMiniPlayerView.swift
//  JapaneseLearning
//
//  Created by Codex on 2026/06/30.
//

import SwiftUI
import AVFoundation

struct VideoMiniPlayerView: View {
    @Environment(AppNavigationStore.self) private var navigationStore
    @Environment(PlayerViewManager.self) private var playerVM
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.transitionNamespace) private var transitionNamespace

    var body: some View {
        if let video = playerVM.currentVideoItem, playerVM.player.currentItem != nil {
            HStack(spacing: 0) {
                if placement == .expanded || video.title.cleanedVideoTitle.textWidth < 155 {
                    if let artwork = playerVM.playerNowPlaying.nowPlayingArtwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 32)
                            .clipShape(.rect(cornerRadius: 8))
                            .padding(.trailing, 4)
                    }
                }

                Text(video.title.cleanedVideoTitle)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 15))

                Button {
                    if playerVM.isPlaying {
                        playerVM.pausePlayer()
                    } else {
                        playerVM.playPlayer()
                    }
                } label: {
                    Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(PressScaleButtonStyle())

                if placement == .expanded {
                    Button {
                        playerVM.seekForward()
                    } label: {
                        Image(systemName: "10.arrow.trianglehead.clockwise")
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .contentShape(Rectangle())
            .matchedTransitionSource(
                id: "mini-\(video.id)",
                in: transitionNamespace!
            )
            .onTapGesture {
                presentVideo(video.id)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        guard value.translation.height < -32,
                              abs(value.translation.height) > abs(value.translation.width) else {
                            return
                        }

                        presentVideo(video.id)
                    }
            )
        }
    }

    private func presentVideo(_ videoID: String) {
        navigationStore.videoTransitionSourceID = "mini-\(videoID)"
        navigationStore.quickActionTarget = .resumeVideo(id: videoID)
    }
}
