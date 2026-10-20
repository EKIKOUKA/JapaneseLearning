//
//  PrivacyPolicyView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/10/20.
//

import SwiftUI

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
