//
//  AVPlayerControllerView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/11/24.
//

import SwiftUI
import AVKit

@MainActor
final class NativePlayerHostController: UIViewController {
    private var embeddedPlayer: AVPlayerViewController?
    private let artworkView = UIImageView()

    func updatePodcastArtwork(enabled: Bool, image: UIImage?) {
        guard enabled, let overlay = embeddedPlayer?.contentOverlayView else {
            artworkView.removeFromSuperview()
            artworkView.image = nil
            return
        }

        if artworkView.superview !== overlay {
            artworkView.frame = overlay.bounds
            artworkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            artworkView.contentMode = .scaleAspectFit
            artworkView.clipsToBounds = true
            artworkView.isUserInteractionEnabled = false
            artworkView.accessibilityElementsHidden = true
            artworkView.backgroundColor = .black
            overlay.addSubview(artworkView)
        }
        artworkView.image = image ?? UIImage(systemName: "waveform")?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        artworkView.contentMode = image == nil ? .center : .scaleAspectFit
    }

    func attach(_ player: AVPlayerViewController) {
        guard embeddedPlayer !== player else { return }
        detach()
        
        if let previousHost = player.parent as? NativePlayerHostController {
            previousHost.detach()
        } else if player.parent != nil {
            player.willMove(toParent: nil)
            player.view.removeFromSuperview()
            player.removeFromParent()
        }
        embeddedPlayer = player
        addChild(player)
        player.view.frame = view.bounds
        player.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(player.view)
        player.didMove(toParent: self)
    }

    func detach() {
        artworkView.removeFromSuperview()
        guard let player = embeddedPlayer else { return }
        // 古いホストの破棄が遅れても、新しいホストから取り外さない。
        if player.parent === self {
            player.willMove(toParent: nil)
            player.view.removeFromSuperview()
            player.removeFromParent()
        }
        embeddedPlayer = nil
    }
}

// SwiftUI の表示単位ごとに親を作り、再利用するプレイヤーを明示的に付け替える。
struct AVPlayerControllerView: UIViewControllerRepresentable {
    let controller: AVPlayerViewController
    var usesPodcastArtwork = false
    var podcastArtwork: UIImage?
    @Environment(SettingsStore.self) private var settingsStore

    func makeUIViewController(context: Context) -> NativePlayerHostController {
        let host = NativePlayerHostController()
        host.view.backgroundColor = .clear
        host.attach(controller)
        host.updatePodcastArtwork(enabled: usesPodcastArtwork, image: podcastArtwork)
        controller.player?.allowsExternalPlayback = true
        controller.allowsPictureInPicturePlayback = settingsStore.videoAllowsPictureInPicturePlayback
        return host
    }

    func updateUIViewController(_ host: NativePlayerHostController, context: Context) {
        host.attach(controller)
        host.updatePodcastArtwork(enabled: usesPodcastArtwork, image: podcastArtwork)
        controller.allowsPictureInPicturePlayback = settingsStore.videoAllowsPictureInPicturePlayback
    }

    static func dismantleUIViewController(_ host: NativePlayerHostController, coordinator: ()) {
        host.detach()
    }
}
