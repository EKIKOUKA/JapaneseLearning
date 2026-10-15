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

                Section("プライバシー") {
                    NavigationLink("プライバシー政策") {
                        PrivacyPolicyView()
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
            Label("Apple ログインしてません", systemImage: "person.crop.circle")
                .font(.headline)

            Text("Apple ログインした後，ユーザーのユニックコードを確認することができます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    rawNonce = Self.makeNonce()
                    request.nonce = Self.hashedNonce(rawNonce)
                },
                onCompletion: { result in
                    let nonce = Self.hashedNonce(rawNonce)
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
        VStack(alignment: .leading, spacing: 12) {
            accountRow(title: "クレジット残高", value: "\(accountStore.accountCredits.formatted()) クレジット")

            Label("Apple ログインしました", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.headline)

            accountRow(title: "Apple userID", value: accountStore.userID ?? "未取得")
        }
        .padding(.vertical, 8)
    }

    private func accountRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
        }
    }

    /// 認証のたびに新しい nonce を生成し、Apple の JWT に同じハッシュ値が含まれることを確認する。
    private static func makeNonce(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

    private static func hashedNonce(_ nonce: String) -> String {
        SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("プライバシー政策").font(.largeTitle.bold())
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
        .navigationTitle("プライバシー政策")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacySection(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(text).foregroundStyle(.secondary)
        }
    }
}
