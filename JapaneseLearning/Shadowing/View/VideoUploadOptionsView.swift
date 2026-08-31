//
//  VideoUploadOptionsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 5/30/R8.
//

import SwiftUI

struct VideoUploadOptionsView: View {
    @Environment(VideoStore.self) private var store
    @State private var selectedLanguage: VideoContentLanguage = .ja
    @State private var createCaptionByAi: Bool = false
    @State private var playbackRate: Float = 1.50
    @State private var videoTitle: String
    @State private var selectedCategoryID: String
    let showTitleField: Bool

    let onConfirm: (VideoContentLanguage, Bool, Float, String, String) -> Void

    init(
        initialVideoTitle: String = "",
        initialCategoryID: String = "listening",
        showTitleField: Bool = true,
        onConfirm: @escaping (VideoContentLanguage, Bool, Float, String, String) -> Void
    ) {
        _videoTitle = State(initialValue: initialVideoTitle)
        _selectedCategoryID = State(initialValue: initialCategoryID)
        self.showTitleField = showTitleField
        self.onConfirm = onConfirm
    }

    var body: some View {
        Form {
            if showTitleField {
                Section(header: Text("動画のタイトル"), footer: Text("変更しない場合は元の動画タイトルが使われます")) {
                    TextField("動画のタイトルを入力してください", text: $videoTitle, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            Section(footer: Text("動画の分類を選択しましょう")) {
                Picker("動画の分類", selection: $selectedCategoryID) {
                    ForEach(store.playlistCategories) { category in
                        Text(category.title)
                            .tag(category.id)
                    }
                }
            }
            Section(footer: Text("動画の再生速度を調整しましょう")) {
                PlaybackRateSliderView(
                    rateValue: $playbackRate,
                    minValue: 0.50,
                    maxValue: 2.00,
                    step: 0.05
                )
            }
            Section(footer: Text("動画の言語を選択しましょう")) {
                Picker("動画の言語", selection: $selectedLanguage) {
                    ForEach(VideoContentLanguage.allCases, id: \.self) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
            }
            Section(footer: Text("人工字幕が無い場合、AIを使って字幕を生成します")) {
                Toggle(isOn: $createCaptionByAi) {
                    Text("AIを使って字幕を生成します")
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("動画のアップロード設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    onConfirm(
                        selectedLanguage,
                        createCaptionByAi,
                        playbackRate,
                        videoTitle,
                        selectedCategoryID
                    )
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}
