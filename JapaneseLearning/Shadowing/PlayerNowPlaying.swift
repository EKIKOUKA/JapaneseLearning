//
//  PlayerNowPlaying.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 7/3/R8.
//

import Foundation
import AVFoundation
import AVKit
import MediaPlayer
import UIKit
import Observation

@Observable
@MainActor
final class PlayerNowPlaying {
    unowned let playerManager: PlayerViewManager

    var nowPlayingInfo: [String: Any] = [:]
    var nowPlayingArtwork: UIImage?
    var nowPlayingTitle: String?
    var nowPlayingVideoID: String?
    var lastPublishedElapsedSecond: Int?
    var lastPublishedPlaybackRate: Float?

    init(playerManager: PlayerViewManager) {
        self.playerManager = playerManager
    }

    // MARK: - Now Playing & Remote Command Center
    func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                playerManager.playPlayer()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                playerManager.pausePlayer()
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                playerManager.seek(to: positionEvent.positionTime)
            }
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [10]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                playerManager.seekForward(seconds: 10)
            }
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [10]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                playerManager.seekForward(seconds: -10)
            }
            return .success
        }
    }

    @MainActor
    func updateNowPlayingMetadata() {
        guard playerManager.currentVideoItem != nil else { return }

        if let title = nowPlayingTitle {
            nowPlayingInfo[MPMediaItemPropertyTitle] = title
        }

        if let image = nowPlayingArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = Self.makeArtwork(image)
        } else {
            nowPlayingInfo.removeValue(forKey: MPMediaItemPropertyArtwork)
        }

        if let item = playerManager.player.currentItem {
            let duration = item.duration.seconds
            if duration.isFinite {
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            }
        }

        let current = playerManager.player.currentTime().seconds
        if current.isFinite {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = current
            lastPublishedElapsedSecond = Int(current.rounded(.down))
        }

        let playbackRate = playerManager.isPlaying ? playerManager.player.rate : 0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = playerManager.rate
        lastPublishedPlaybackRate = playbackRate

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    @MainActor
    func updateNowPlayingProgress() {
        let current = playerManager.player.currentTime().seconds
        guard current.isFinite else { return }

        let currentSecond = Int(current.rounded(.down))
        let playbackRate = playerManager.isPlaying ? playerManager.player.rate : 0
        if lastPublishedElapsedSecond == currentSecond, lastPublishedPlaybackRate == playbackRate {
            return
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = current
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        lastPublishedElapsedSecond = currentSecond
        lastPublishedPlaybackRate = playbackRate
    }

    @MainActor
    func updatePlaybackRate() {
        let playbackRate = playerManager.isPlaying ? playerManager.player.rate : 0
        let currentSecond = Int(playerManager.player.currentTime().seconds.rounded(.down))
        if lastPublishedElapsedSecond == currentSecond, lastPublishedPlaybackRate == playbackRate {
            return
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = playerManager.rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        lastPublishedPlaybackRate = playbackRate
    }

    func clearNowPlayingInfo() {
        nowPlayingArtwork = nil
        nowPlayingTitle = nil
        nowPlayingVideoID = nil
        nowPlayingInfo.removeAll()
        lastPublishedElapsedSecond = nil
        lastPublishedPlaybackRate = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private nonisolated static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in
            image
        }
    }
}
