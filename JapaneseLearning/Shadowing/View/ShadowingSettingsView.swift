//
//  ShadowingSettingsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/27.
//

import SwiftUI

struct ShadowingSettingsSheetView: View {
    @Environment(SettingsStore.self) private var settingsStore
    var playerVM: PlayerViewManager?

    var body: some View {
        @Bindable var settingsStoreBindable = settingsStore

        NavigationStack {
            Form {
                if let playerVM {
                    @Bindable var playerVM = playerVM

                    Section(footer: Text("動画の再生速度を調整します")) {
                        PlaybackRateSliderView(
                            rateValue: $playerVM.tempRate,
                            minValue: 0.50,
                            maxValue: 1.50,
                            step: 0.05
                        ) { rate in
                            playerVM.setRate(rate)
                        }
                    }
                }

                Section(footer: Text("字幕のサイズを調整します")) {
                    VideoSubtitleFontSizeSliderView()
                }

                Section(footer: Text("再生中の行の話が終了すると、自動的に次の文へ移動します")) {
                    Toggle(isOn: $settingsStoreBindable.videoAutoJumpToNextLine) {
                        Text("次の文へ自動移動")
                    }
                }

                Section(footer: Text("字幕の色を変更します")) {
                    ColorPicker("字幕の色", selection: settingsStore.videoSubtitleFontColorBinding, supportsOpacity: true)
                }

                Section(footer: Text("再生中の行を強調し、他の字幕を控えめに表示します")) {
                    Toggle(isOn: $settingsStoreBindable.videoSubtitleDimInactiveLines) {
                        Text("再生中の字幕を強調表示")
                    }
                }

                if playerVM == nil {
                    Section(footer: Text("字幕のフォントを変更します")) {
                        Picker("フォント", selection: $settingsStoreBindable.videoSubtitleFontStyle) {
                            ForEach(VideoSubtitleRubyFontStyle.allCases, id: \.self) { fontStyle in
                                Text(fontStyle.displayName).tag(fontStyle)
                            }
                        }
                    }
                }

                Section(footer: Text("単語の上に発音（ルビ）を表示します")) {
                    Toggle(isOn: $settingsStoreBindable.showShadowingSubtitlesRuby) {
                        Text("発音を表示")
                    }
                }
            }
            .contentMargins(.top, 10)
            .navigationTitle("シャドーイング設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
