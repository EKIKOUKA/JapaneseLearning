//
//  CreditUsageHistoryView.swift
//  JapaneseLearning
//
//  Created by Makoto on 2026/11/07.
//

import SwiftUI

struct CreditUsageHistoryView: View {
    @State private var entries: [CreditUsageRecord] = []
    @State private var error: String?
    @State private var isReady: Bool = false

    var body: some View {
        List {
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.videoTitle)
                    Text("\(VideoAIMode(rawValue: entry.mode)?.title ?? entry.mode) · \(entry.creditsUsed) クレジット消費")
                    Text("\(serverDateTimeInJST(entry.createdAt)) · 残高 \(entry.balanceAfter)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if let error {
                Text(error).foregroundStyle(.red)
            }
            if entries.isEmpty && error == nil {
                Text("利用履歴はありません")
            }
        }
        .navigationTitle("クレジットの利用履歴")
        .opacity(isReady ? 1 : 0)
        .task {
            if entries.isEmpty {
                do {
                    entries = try await WorkersAPI.get("credits/usage_history", requiresAuthentication: true)
                    withAnimation(.easeIn(duration: 0.15)) {
                        isReady = true
                    }
                } catch {
                    self.error = error.localizedDescription
                    isReady = true
                }
            }
        }
    }
}
