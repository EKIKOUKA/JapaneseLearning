import SwiftUI

struct AIExplanationView: View {
    @Environment(AppleAccountStore.self) private var accountStore
    @Environment(SettingsStore.self) private var settingsStore
    let question: AIExplanationQuestion
    @State private var turns: [AIExplanationTurn]
    @State private var isLoading = false
    @State private var draft = ""
    @FocusState private var isInputFocused: Bool

    init(question: AIExplanationQuestion) {
        self.question = question
        _turns = State(initialValue: [AIExplanationTurn(question: question)])
    }

    private var lastCompleted: AIExplanationTurn? {
        turns.last { $0.response != nil }
    }

    private var canSend: Bool {
        !isLoading && accountStore.isSignedIn && lastCompleted != nil
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.count <= 1000
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(turns.enumerated()), id: \.element.id) { index, turn in
                            turnView(turn, index: index)
                                .id(turn.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: turns.count) { _, _ in
                    if let id = turns.last?.id {
                        withAnimation { proxy.scrollTo(id, anchor: .top) }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if lastCompleted != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .bottom, spacing: 12) {
                            TextField("分からないところを質問する", text: $draft, axis: .vertical)
                                .lineLimit(1...5)
                                .focused($isInputFocused)
                                .disabled(isLoading)

                            Button(action: sendFollowUp) {
                                Image(systemName: "arrow.up.circle.fill").font(.title)
                            }
                            .accessibilityLabel("質問を送信（1 クレジット）")
                            .disabled(!canSend)
                        }

                        Text(draft.count > 1000 ? "質問は 1,000 文字以内で入力してください。" : "送信ごとに 1 クレジット・残り \(accountStore.accountCredits)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.bar)
                }
            }
            .navigationTitle(question.mode == .word ? "単語の AI 解説" : "字幕の AI 解説")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(isLoading)
    }

    @ViewBuilder
    private func turnView(_ turn: AIExplanationTurn, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if index > 0 { Divider() }
            Text(index == 0 ? "解説するテキスト" : "あなたの質問")
                .font(.caption).foregroundStyle(.secondary)
            Text(turn.question.text).font(.title3.bold()).textSelection(.enabled)

            if !turn.streamingText.isEmpty || turn.response != nil {
                Text(formattedAnswer(turn.response?.answer ?? turn.streamingText))
                    .textSelection(.enabled)
            }
            if isLoading && index == turns.count - 1 {
                ProgressView(turn.streamingText.isEmpty ? "AI が解説を作成しています..." : "生成中...")
            }

            if let response = turn.response {
                if response.truncated {
                    Text("出力上限に達したため、回答の一部が省略されています。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else if !isLoading {
                if index == 0 {
                    Text("解説のため、このテキストを Cloudflare 経由で OpenAI に送信します。1 回の質問と回答で 1 クレジットを使用します。内容には誤りが含まれる場合があります。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                if let error = turn.errorMessage {
                    Text(error).foregroundStyle(.red)
                }

                Button(turn.errorMessage == nil ? "解説する（1 クレジット）" : "同じリクエストを再確認") {
                    Task { await explain(at: index) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!accountStore.isSignedIn)

                if !accountStore.isSignedIn {
                    Text("アカウントタブから Apple でログインしてください。")
                }
            }
        }
    }

    private func formattedAnswer(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )) ?? AttributedString(text)
    }

    private func sendFollowUp() {
        guard canSend, let parent = lastCompleted else { return }
        let followUp = AIExplanationQuestion(
            text: draft.trimmingCharacters(in: .whitespacesAndNewlines),
            mode: question.mode,
            parentRequestID: parent.id
        )
        draft = ""
        isInputFocused = false
        turns.append(AIExplanationTurn(question: followUp))
        let index = turns.count - 1
        Task { await explain(at: index) }
    }

    @MainActor private func explain(at index: Int) async {
        guard !isLoading, turns[index].response == nil else { return }
        isLoading = true
        // Freeze the language for retries of the same charged request.
        if turns[index].question.language == nil {
            switch settingsStore.aiExplanationLanguage {
                case "EN": turns[index].question.language = "en"
                case "TW": turns[index].question.language = "zh-TW"
                default: turns[index].question.language = "ja"
            }
        }
        turns[index].errorMessage = nil
        turns[index].streamingText = ""
        defer { isLoading = false }

        do {
            turns[index].response = try await accountStore.requestAIExplanation(turns[index].question) { delta in
                turns[index].streamingText += delta
            }
        } catch {
            turns[index].errorMessage = error.localizedDescription
        }
    }
}
