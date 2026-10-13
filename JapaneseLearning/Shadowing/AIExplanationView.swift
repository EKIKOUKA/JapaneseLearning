import SwiftUI

struct AIExplanationView: View {
    @Environment(AppleAccountStore.self) private var accountStore
    let question: AIExplanationQuestion
    @State private var response: AIExplanationResponse?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(question.text).font(.title3.bold()).textSelection(.enabled)

                    if isLoading {
                        ProgressView("AI が解説を作成しています...")
                    } else if let response {
                        Text(response.answer).textSelection(.enabled)
                        if response.truncated {
                            Text("出力上限に達したため、回答の一部が省略されています。")
                                .font(.footnote).foregroundStyle(.secondary)
                        }

                        Text("残り \(response.creditBalance) クレジット")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text("解説のため、このテキストを Cloudflare 経由で OpenAI に送信します。1 クレジットを使用します。内容には誤りが含まれる場合があります。")
                            .font(.subheadline).foregroundStyle(.secondary)

                        if let errorMessage {
                            Text(errorMessage).foregroundStyle(.red)
                        }

                        Button(errorMessage == nil ? "解説する（1 クレジット）" : "同じリクエストを再確認") {
                            Task { await explain() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!accountStore.isSignedIn)

                        if !accountStore.isSignedIn {
                            Text("アカウントタブから Apple でログインしてください。")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle(question.mode == .word ? "単語の AI 解説" : "字幕の AI 解説")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(isLoading)
    }

    @MainActor private func explain() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            response = try await accountStore.requestAIExplanation(question)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
