//
//  AppleAccountView.swift
//  JapaneseLearning
//
//  Created by Makoto on 2026/10/05.
//

import SwiftUI
import AuthenticationServices

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

                Section("アプリ設定") {
                    NavigationLink("アプリ設定") {
                        AppSettingsView()
                    }
                }

                Section("プライバシーポリシー") {
                    NavigationLink("プライバシーポリシー") {
                        PrivacyPolicyView()
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
