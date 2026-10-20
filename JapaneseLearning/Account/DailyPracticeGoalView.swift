//
//  DailyPracticeGoalView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/10/20.
//

import SwiftUI

struct DailyPracticeGoalView: View {
    @Environment(AppleAccountStore.self) private var accountStore
    @Environment(\.dismiss) private var dismiss
    @State private var goalHours = 0
    @State private var goalMinutes = 10
    @State private var isLoadingGoal = true
    @State private var goalError: String?

    private var selectedGoalMinutes: Int { goalHours * 60 + goalMinutes }

    var body: some View {
        NavigationStack {
            Form {
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

                    if let goalError {
                        Text(goalError)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("現在の目標：\(accountStore.dailyPracticeGoalMinutes) 分")
                } footer: {
                    Text(accountStore.isSignedIn
                         ? "1 分〜8 時間で設定できます。学習記録と達成通知に適用され、過去の達成率も現在の目標で計算されます。"
                         : "目標を保存するには Apple でログインしてください。")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .disabled(accountStore.isSavingDailyPracticeGoal)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveGoal() }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!goalDisable)
                }
            }
            .navigationTitle("一日の練習目標")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(accountStore.isSavingDailyPracticeGoal)
            .task {
                goalHours = accountStore.dailyPracticeGoalMinutes / 60
                goalMinutes = accountStore.dailyPracticeGoalMinutes % 60
                isLoadingGoal = false
            }
        }
    }

    private var goalDisable: Bool {
        accountStore.isSignedIn &&
        !isLoadingGoal &&
        !accountStore.isSavingDailyPracticeGoal &&
        (1...480).contains(selectedGoalMinutes) &&
        selectedGoalMinutes != accountStore.dailyPracticeGoalMinutes
    }

    @MainActor private func saveGoal() async {
        guard goalDisable else { return }
        goalError = nil

        do {
            try await accountStore.saveDailyPracticeGoal(selectedGoalMinutes)
            dismiss()
        } catch {
            goalError = error.localizedDescription
        }
    }
}
