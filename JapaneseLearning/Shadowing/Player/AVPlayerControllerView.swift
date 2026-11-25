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

    func attach(_ player: AVPlayerViewController) {
        guard embeddedPlayer !== player else { return }
        detach()
        
        if player.parent != nil {
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
    @Environment(SettingsStore.self) private var settingsStore

    func makeUIViewController(context: Context) -> NativePlayerHostController {
        let host = NativePlayerHostController()
        host.view.backgroundColor = .clear
        host.attach(controller)
        controller.player?.allowsExternalPlayback = true
        controller.allowsPictureInPicturePlayback = settingsStore.videoAllowsPictureInPicturePlayback
        return host
    }

    func updateUIViewController(_ host: NativePlayerHostController, context: Context) {
        host.attach(controller)
        controller.allowsPictureInPicturePlayback = settingsStore.videoAllowsPictureInPicturePlayback
    }

    static func dismantleUIViewController(_ host: NativePlayerHostController, coordinator: ()) {
        host.detach()
    }
}
