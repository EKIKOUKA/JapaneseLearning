//
//  AppSettingsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/10/20.
//

import SwiftUI

struct AppSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppleAccountStore.self) private var accountStore
    @State private var goalHours = 0
    @State private var goalMinutes = 10
    @State private var isLoadingGoal = true
    @State private var goalError: String?

    @State private var showDailyPracticeGoalSheet = false
    private var selectedGoalMinutes: Int { goalHours * 60 + goalMinutes }

    private let aiLanguageList: [(name: String, code: String)] = [
        (name: "🇯🇵 日本語", code: "JP"),
        (name: "🇺🇸 英語", code: "EN"),
        (name: "🇹🇼 台湾語", code: "TW")
    ]
    private let AIProviderList: [(provider: String, model: String)] = [
        (provider: "Anthropic", model: "claude-haiku-5.5"),
        (provider: "Google", model: "gemini-2.5-flash-lite"),
        (provider: "OpenAI", model: "gpt-6-luna")
    ]


    @State var storageBytes: Int64 = 0

    func folderSize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [],
            errorHandler: nil
        ) else { return 0 }

        var total: Int64 = 0

        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
               values.isRegularFile == true, let size = values.fileSize {
                total += Int64(size)
            }
        }

        return total
    }

    // 表示する容量と削除対象を同じディレクトリにそろえる。
    private var cacheDirectories: [URL] {
        let files = FileManager.default
        return [
            files.urls(for: .cachesDirectory, in: .userDomainMask).first,
            files.temporaryDirectory,
            files.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Thumbnails", isDirectory: true),
            files.containerURL(forSecurityApplicationGroupIdentifier: AppGroupThumbnailStorage.groupIdentifier)?
                .appendingPathComponent("Thumbnails", isDirectory: true)
        ].compactMap { $0 }
    }

    private func getCacheSize() -> Int64 {
        cacheDirectories.reduce(0) { $0 + folderSize(at: $1) }
    }

    func formattedStorageSize(_ bytes: Int64) -> String {
        if bytes <= 0 {
            return "0 KB"
        }

        let kb = Double(bytes) / 1024
        let mb = kb / 1024

        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.0f KB", kb)
        }
    }

    var body: some View {
        @Bindable var settingsStoreBindable = settingsStore

        Form {
            Section(footer: Text("字幕のAI解説に表示する言語")) {
                Picker("AI解説に使用言語", selection: $settingsStoreBindable.AIExplanationLanguage) {
                    ForEach(aiLanguageList, id: \.code) {item in
                        Text(item.name).tag(item.code)
                    }
                }
            }

            Section(footer: Text("AI解説と字幕の文分けに使用するモデル")) {
                Picker("使用するAIモデル", selection: $settingsStoreBindable.AIProvider) {
                    ForEach(AIProviderList, id: \.provider) {item in
                        Button {} label: {
                            Text(item.provider)
                            Text(item.model)
                        }
                        .tag(item.provider)
                    }
                }
            }

            Section(footer: Text("学習記録と目標達成通知に使用します")) {
                Button {
                    showDailyPracticeGoalSheet = true
                } label: {
                    LabeledContent("一日の練習目標時間", value: "\(accountStore.dailyPracticeGoalMinutes) 分")
                }
                .tint(.primary)
            }
            
            
            Section(footer: Text("キャッシュを削除すると、一時的に保存されたデータが削除されます。")) {
                HStack {
                    Text("キャッシュ容量")
                    Spacer()
                    Text(formattedStorageSize(storageBytes))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.smooth(duration: 0.5), value: storageBytes)
                }

                Button {
                    Task {
                        await clearAppCache()
                        storageBytes = getCacheSize()
                    }
                } label: {
                    Text("キャッシュを削除")
                }
            }
        }
        .navigationTitle("設定")
        .task {
            await accountStore.refreshCredentialState()
            loadGoal()
            isLoadingGoal = false
            storageBytes = getCacheSize()
        }
        .onChange(of: accountStore.dailyPracticeGoalMinutes) { _, _ in loadGoal() }
        .sheet(isPresented: $showDailyPracticeGoalSheet) {
            DailyPracticeGoalView()
                .presentationDetents([.height(350)])
        }
    }

    private func loadGoal() {
        goalHours = accountStore.dailyPracticeGoalMinutes / 60
        goalMinutes = accountStore.dailyPracticeGoalMinutes % 60
    }
    
    private func clearAppCache() async {
        URLCache.shared.removeAllCachedResponses()
        let files = FileManager.default

        for directory in cacheDirectories {
            do {
                for item in try files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                    do {
                        try files.removeItem(at: item)
                    } catch {
                        NSLog("キャッシュの削除に失敗しました: %@", error.localizedDescription)
                    }
                }
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                // まだ作られていないキャッシュは削除不要。
            } catch {
                NSLog("キャッシュの読み込みに失敗しました: %@", error.localizedDescription)
            }
        }
    }
}
