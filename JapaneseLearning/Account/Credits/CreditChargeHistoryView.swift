//
//  CreditChargeHistoryView.swift
//  JapaneseLearning
//
//  Created by Makoto on 2026/11/08.
//

import SwiftUI

struct CreditChargeHistoryView: View {
    @State private var entries: [CreditChargeRecord] = []
    @State private var error: String?
    @State private var isReady: Bool = false

    var body: some View {
        List {
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text("+\(entry.credits) クレジット")

                    if let price = formattedPrice(entry) {
                        Text(price)
                    }

                    Text("\(entry.provider) · \(triggerLabel(entry.chargeTrigger))")
                    Text(serverDateTimeInJST(entry.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if entry.environment == "Sandbox" {
                        Text("テスト環境")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let error {
                Text(error).foregroundStyle(.red)
            }
            if entries.isEmpty && error == nil {
                Text("チャージ履歴はありません")
            }
        }
        .navigationTitle("クレジットのチャージ履歴")
        .opacity(isReady ? 1 : 0)
        .task {
            if entries.isEmpty {
                do {
                    entries = try await WorkersAPI.get("credits/charge_history", requiresAuthentication: true)
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

    private func triggerLabel(_ trigger: String) -> String {
        switch trigger {
            case "manual": String(localized: "手動チャージ")
            case "monthly": String(localized: "毎月の自動チャージ")
            case "low_balance": String(localized: "残高不足時の自動チャージ")
            default: trigger
        }
    }

    private func formattedPrice(_ entry: CreditChargeRecord) -> String? {
        guard let amount = entry.amount, let currency = entry.currency else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        let price = Decimal(amount) / pow(Decimal(10), formatter.maximumFractionDigits)

        return formatter.string(from: NSDecimalNumber(decimal: price))
    }
}
