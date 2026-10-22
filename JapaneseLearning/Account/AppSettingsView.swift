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

    var body: some View {
        @Bindable var settingsStoreBindable = settingsStore

        Form {
            Section(header: Text("言語"), footer: Text("字幕のAI解説に表示する言語")) {
                Picker("AI解説に使用言語", selection: $settingsStoreBindable.AIExplanationLanguage) {
                    ForEach(aiLanguageList, id: \.code) {item in
                        Text(item.name).tag(item.code)
                    }
                }
            }

            Section(header: Text("AIモデル"), footer: Text("字幕のAI解説に使用AIモデル")) {
                Picker("AI解説に使用するモデル", selection: $settingsStoreBindable.AIProvider) {
                    ForEach(AIProviderList, id: \.provider) {item in
                        Button {} label: {
                            Text(item.provider)
                            Text(item.model)
                        }
                        .tag(item.provider)
                    }
                }
            }

            Section(header: Text("学習目標"), footer: Text("学習記録と目標達成通知に使用します")) {
                Button {
                    showDailyPracticeGoalSheet = true
                } label: {
                    LabeledContent("一日の練習目標時間", value: "\(accountStore.dailyPracticeGoalMinutes) 分")
                }
                .tint(.primary)
            }
            .tint(.primary)
        }
        .navigationTitle("設定")
        .task {
            await accountStore.refreshCredentialState()
            loadGoal()
            isLoadingGoal = false
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
}
