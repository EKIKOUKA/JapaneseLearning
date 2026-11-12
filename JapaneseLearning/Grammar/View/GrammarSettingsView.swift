//
//  GrammarSettingsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/17.
//

import SwiftUI

struct GrammarSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        @Bindable var settingsStoreBindable = settingsStore

        NavigationStack {
            Form {
                Section(header: Text("表示設定")) {
                    Toggle(isOn: $settingsStoreBindable.showGrammarListAddButton) {
                        VStack(alignment: .leading) {
                            Text("新規追加ボタンを表示")
                            Text("文法リストに新規追加ボタンを表示する")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settingsStoreBindable.showGrammarEditorButton) {
                        VStack(alignment: .leading) {
                            Text("編集ボタンを表示")
                            Text("文法画面に編集ボタンを表示")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settingsStoreBindable.showGrammarListItemSwipeActions) {
                        VStack(alignment: .leading) {
                            Text("スワイプアクションを表示")
                            Text("文法リストにスワイプアクションを表示")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settingsStoreBindable.showGrammarListItemImportantImage) {
                        VStack(alignment: .leading) {
                            Text("重要アイコンを表示")
                            Text("文法リストに重要アイコンを表示")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settingsStoreBindable.showGrammarListCount) {
                        VStack(alignment: .leading) {
                            Text("件数を表示")
                            Text("文法リスト底に件数を表示する")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settingsStoreBindable.showGrammarListAllItemTag) {
                        VStack(alignment: .leading) {
                            Text("タグを表示")
                            Text("すべての文法リストにレベルタグを表示する")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("日本語勉学に設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
