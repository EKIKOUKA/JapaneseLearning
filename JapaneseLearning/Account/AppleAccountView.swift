//
//  AppleAccountView.swift
//  JapaneseLearning
//
//  Created by Makoto on 2026/10/05.
//

import AuthenticationServices
import CryptoKit
import SwiftUI

struct AppleAccountView: View {
    @Environment(AppleAccountStore.self) private var accountStore
    @State private var rawNonce = ""
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if accountStore.isSignedIn {
                        accountSummary
                    } else {
                        signInView
                    }
                }

                Section("チャージ") {
                    NavigationLink("クレジットを購入") {
                        ChargeView()
                    }
                }

                Section("プライバシーポリシー") {
                    NavigationLink("プライバシーポリシー") {
                        PrivacyPolicyView()
                    }
                }

                Section("設定") {
                    NavigationLink("設定") {
                        AppSettingsView()
                    }
                }
                
                if accountStore.isSignedIn {
                    Section("アカウント管理") {
                        Button("ログアウト", role: .destructive) {
                            Task { await accountStore.signOut() }
                        }
                        .disabled(accountStore.isAccountOperationBlocked)

                        Button("アカウントを削除", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                        .disabled(accountStore.isAccountOperationBlocked)
                        
                        if accountStore.isManagingAccount {
                            ProgressView("処理中…")
                        }
                    }
                }
            }
            .navigationTitle("アカウントとプライバシー")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await accountStore.refreshCredentialState()
            }
            .confirmationDialog("アカウントを削除しますか？", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("アカウントを削除", role: .destructive) {
                    Task { await accountStore.deleteAccount() }
                }
                
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("本アプリのアカウントとクレジット残高を削除し、Apple との連携を解除します。この操作は取り消せません。")
            }
            .alert("アカウント操作に失敗しました", isPresented: Binding(
                get: { accountStore.signInError != nil },
                set: { if !$0 { accountStore.clearSignInError() } }
            )) {
                Button("閉じる", role: .cancel) { accountStore.clearSignInError() }
            } message: {
                Text(accountStore.signInError ?? "")
            }
            .alert("アカウントを削除しました", isPresented: Binding(
                get: { accountStore.accountNotice != nil },
                set: { if !$0 { accountStore.clearAccountNotice() } }
            )) {
                Button("閉じる", role: .cancel) { accountStore.clearAccountNotice() }
            } message: {
                Text(accountStore.accountNotice ?? "")
            }
        }
    }

    private var signInView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("ログインしていません", systemImage: "person.crop.circle")
                .font(.headline)

            Text("Apple でログインして、クレジットのチャージや AI 解説を利用できます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    rawNonce = accountStore.makeNonce()
                    request.nonce = accountStore.hashedNonce(rawNonce)
                },
                onCompletion: { result in
                    let nonce = accountStore.hashedNonce(rawNonce)
                    Task { await accountStore.handleAuthorization(result, hashedNonce: nonce) }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(accountStore.isAccountOperationBlocked)
        }
        .padding(.vertical, 8)
    }

    private var accountSummary: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("クレジット残高")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("ログイン済み")
                }
                .font(.caption)
                .foregroundStyle(.green)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(accountStore.accountCredits.formatted())
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                
                Text("クレジット")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .animation(.smooth, value: accountStore.accountCredits)

            Text("AI 解説・追加の質問に利用できます。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }
}


struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("最終更新：2026 年 10 月 9 日").foregroundStyle(.secondary)
                privacySection("はじめに", "シャドーイング（以下「本アプリ」）は、利用者のプライバシーを尊重します。本ポリシーでは、本アプリにおける情報の取り扱いについて説明します。")
                privacySection("取得する情報", "本アプリは、基本的な学習機能の利用にあたり、氏名、住所、連絡先などの個人情報の登録を求めません。学習記録などの情報は、利用者の端末上で機能を提供するために使用されます。")
                privacySection("Apple ログインとアカウント", "Apple ログインを利用する場合、Apple が発行したユーザー識別子、クレジット残高、ログイン情報をサーバーに保存します。Apple の更新トークンは暗号化して保存し、ログイン用トークンは端末の Keychain に、サーバーにはそのハッシュ値を保存します。ログイン状態に固定の有効期限はありません。アカウント画面から削除すると、Apple との連携を解除し、アカウント情報とすべてのログイン情報を削除します。")
                privacySection("外部サービス", "本アプリでは、利用者が選択した動画を表示するために外部の動画サービスへアクセスする場合があります。外部サービスにおける情報の取り扱いについては、各サービスのプライバシーポリシーをご確認ください。")
                privacySection("情報の共有", "本アプリは、法令に基づく場合を除き、利用者の個人情報を第三者へ販売、貸与、または共有しません。")
                privacySection("ポリシーの変更", "本ポリシーは、必要に応じて変更されることがあります。重要な変更がある場合は、本ページでお知らせします。")
                privacySection("お問い合わせ", "miya_no_makoto@yahoo.co.jpに連絡してください。")
            }
            .padding()
        }
        .navigationTitle("プライバシーポリシー")
    }

    private func privacySection(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(text).foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

struct AppSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppleAccountStore.self) private var accountStore
    @State private var goalHours = 0
    @State private var goalMinutes = 10
    @State private var isLoadingGoal = true
    @State private var goalError: String?

    private var selectedGoalMinutes: Int { goalHours * 60 + goalMinutes }

    private let aiLanguageList: [(name: String, code: String)] = [
        (name: "🇯🇵 日本語", code: "JP"),
        (name: "🇺🇸 英語", code: "EN"),
        (name: "🇹🇼 台湾語", code: "TW")
    ]

    var body: some View {
        @Bindable var settingsStoreBindable = settingsStore

        Form {
            Section(header: Text("言語"), footer: Text("字幕のAI解説に表示する言語")) {
                Picker("AI解説に使用言語", selection: $settingsStoreBindable.aiExplanationLanguage) {
                    ForEach(aiLanguageList, id: \.code) {item in
                        Text(item.name).tag(item.code)
                    }
                }
            }

            Section {
                HStack(spacing: 0) {
                    Picker("時間", selection: $goalHours) {
                        ForEach(0...8, id: \.self) {
                            Text("\($0) 時間").tag($0)
                        }
                    }

                    Picker("分", selection: $goalMinutes) {
                        ForEach(0...59, id: \.self) {
                            Text("\($0) 分").tag($0)
                        }
                    }
                    .disabled(goalHours == 8)
                }
                .pickerStyle(.wheel)
                .frame(height: 160)
                .clipped()
                .onChange(of: goalHours) { _, value in
                    if value == 8 { goalMinutes = 0 }
                }

                Text("現在の目標：\(accountStore.dailyPracticeGoalMinutes) 分")
                    .foregroundStyle(.secondary)

                if let goalError {
                    Text(goalError)
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        goalError = nil
                        
                        do {
                            try await accountStore.saveDailyPracticeGoal(selectedGoalMinutes)
                        } catch {
                            goalError = error.localizedDescription
                        }
                    }
                } label: {
                    if accountStore.isSavingDailyPracticeGoal { ProgressView() }
                    else { Text("目標を保存") }
                }
                .disabled(!(1...480).contains(selectedGoalMinutes) || selectedGoalMinutes == accountStore.dailyPracticeGoalMinutes)
            } header: {
                Text("一日の練習目標")
            } footer: {
                Text(accountStore.isSignedIn
                    ? "1 分〜8 時間で設定できます。学習記録と達成通知に適用され、過去の達成率も現在の目標で計算されます。"
                    : "目標を保存するには Apple でログインしてください。")
            }
            .disabled(!accountStore.isSignedIn || isLoadingGoal || accountStore.isSavingDailyPracticeGoal)
        }
        .navigationTitle("設定")
        .task {
            await accountStore.refreshCredentialState()
            loadGoal()
            isLoadingGoal = false
        }
        .onChange(of: accountStore.dailyPracticeGoalMinutes) { _, _ in loadGoal() }
    }

    private func loadGoal() {
        goalHours = accountStore.dailyPracticeGoalMinutes / 60
        goalMinutes = accountStore.dailyPracticeGoalMinutes % 60
    }
}
