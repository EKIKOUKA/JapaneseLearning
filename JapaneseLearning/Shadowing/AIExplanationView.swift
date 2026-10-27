//
//  AIExplanationView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/10/13.
//

import SwiftUI

struct AIExplanationView: View {
    @Environment(AppleAccountStore.self) private var accountStore
    @Environment(SettingsStore.self) private var settingsStore

    let question: AIExplanationQuestion
    @State private var turns: [AIExplanationTurn]
    @State private var isLoading = false
    @State private var hasStartedInitialExplanation = false
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
                if question.mode == .sentence, lastCompleted != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .bottom, spacing: 12) {
                            TextField("分からないところを質問する", text: $draft, axis: .vertical)
                                .lineLimit(1...5)
                                .focused($isInputFocused)
                                .disabled(isLoading)

                            Button(action: sendFollowUp) {
                                Image(systemName: "arrow.up.circle.fill").font(.title)
                            }
                            .accessibilityLabel("質問を送信する")
                            .disabled(!canSend)
                        }

                        Text(draft.count > 1000 ? "質問は 1,000 文字以内で入力してください。" : "送信ごとに 1 クレジット・残り \(accountStore.accountCredits.formatted())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(.smooth(duration: 0.5), value: accountStore.accountCredits)
                    }
                    .padding()
                    .background(.bar)
                }
            }
            .navigationTitle(question.mode == .word ? question.text : "字幕の AI 解説")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(isLoading)
        .task {
            // 再表示で同じ質問を自動送信しない。失敗後は再確認ボタンから再試行する。
            guard !hasStartedInitialExplanation else { return }
            hasStartedInitialExplanation = true
            await explain(at: 0)
        }
    }

    @ViewBuilder
    private func turnView(_ turn: AIExplanationTurn, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if index > 0 { Divider() }

            if question.mode == .sentence || index > 0 {
                Text(index == 0 ? "解説するテキスト" : "あなたの質問")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(turn.question.text)
                    .font(.title3.bold())
                    .textSelection(.enabled)
            }

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
                if let error = turn.errorMessage {
                    Text(error).foregroundStyle(.red)

                    Button("同じリクエストを再確認") {
                        Task { await explain(at: index) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!accountStore.isSignedIn)
                }

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
            switch settingsStore.AIExplanationLanguage {
                case "EN": turns[index].question.language = "en"
                case "TW": turns[index].question.language = "zh-TW"
                default: turns[index].question.language = "ja"
            }
        }

        turns[index].errorMessage = nil
        if turns[index].question.provider == nil {
            turns[index].question.provider = settingsStore.AIProvider
        }
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
