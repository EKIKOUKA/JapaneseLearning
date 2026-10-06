import AuthenticationServices
import SwiftUI

struct AppleAccountView: View {
    @Environment(AppleAccountStore.self) private var accountStore
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

                if accountStore.isSignedIn {
                    Section("アカウント管理") {
                        Button("ログアウト", role: .destructive) {
                            accountStore.signOut()
                        }

                        Button("アカウント削除", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }

                Section("チャージ") {
                    NavigationLink("クレジットを購入") {
                        ChargeView()
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
            .confirmationDialog("アカウントを削除しますか？", isPresented: $showingDeleteConfirmation) {
                Button("刪除", role: .destructive) {
                    accountStore.deleteLocalAccountData()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("この操作によると、もうアカウントの取り戻すことはできない")
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

            SignInWithAppleButton(.signIn) { _ in
            } onCompletion: { result in
                accountStore.handleAuthorization(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("プライバシー政策").font(.largeTitle.bold())
                Text("最後更新：2026 年 9 月 30 日").foregroundStyle(.secondary)
                privacySection("はじめに", "シャドーイング（以下「本アプリ」）は、利用者のプライバシーを尊重します。本ポリシーでは、本アプリにおける情報の取り扱いについて説明します。")
                privacySection("取得する情報", "本アプリは、基本的な学習機能の利用にあたり、氏名、住所、連絡先などの個人情報の登録を求めません。学習記録などの情報は、利用者の端末上で機能を提供するために使用されます。")
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
