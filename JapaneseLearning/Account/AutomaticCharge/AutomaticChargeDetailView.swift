//
//  AutomaticChargeDetailView.swift
//  JapaneseLearning
//
//  Created by Makoto on 2026/11/02.
//

import SwiftUI
import PassKit

struct AutomaticChargeDetailView: View {
    let kind: AutomaticChargeKind
    var onSettingsLoaded: ([AutomaticChargeSetting]) -> Void
    @Environment(AppleAccountStore.self) private var accountStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var configuration: StripeTestConfiguration?
    @State private var settings: [AutomaticChargeSetting] = []
    @State private var isLoading = true
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var notice: String?
    @State private var monthlyAmount = 0
    @State private var reloadAmount = 0
    @State private var billingDay = 1
    @State private var thresholdText = "100"
    @State private var monthlyLimitText = "1000"
    @State private var stoppingType: String?
    @State private var showsStopConfirmation = false
    @State private var coordinator = AutomaticChargeCoordinator()

    private var threshold: Int? { Int(thresholdText) }
    private var monthlyLimit: Int? { Int(monthlyLimitText) }
    private func setting(_ type: String) -> AutomaticChargeSetting? { settings.first { $0.type == type } }

    var body: some View {
        Form {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("設定を読み込み中…")
                        Spacer()
                    }
                }
            } else if let configuration {
                if kind == .monthly {
                    Section {
                        statusView("monthly")
                        amountPicker("毎月の金額", selection: $monthlyAmount, configuration: configuration)

                        Picker("チャージ日", selection: $billingDay) {
                            ForEach(1...28, id: \.self) {
                                Text("毎月 \($0) 日").tag($0)
                            }
                        }

                        creditDescription(amount: monthlyAmount, configuration: configuration)
                        authorizationButton(type: "monthly", configuration: configuration)
                        stopButton("monthly")
                    } footer: {
                        Text("次の指定日から毎月チャージします。今日のチャージは行いません。変更には再承認が必要です。")
                    }
                }

                if kind == .lowBalance {
                    Section {
                        statusView("low_balance")
                        LabeledContent("追加する残高の目安") {
                            TextField("100", text: $thresholdText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 90)
                            Text("クレジット未満").foregroundStyle(.secondary)
                        }

                        amountPicker("1 回の金額", selection: $reloadAmount, configuration: configuration, range: 50...20000)
                        creditDescription(amount: reloadAmount, configuration: configuration)

                        LabeledContent("追加チャージの月額上限") {
                            TextField("1000", text: $monthlyLimitText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 100)
                            Text("円").foregroundStyle(.secondary)
                        }

                        if !validReload {
                            Text("残高の目安は 50〜20,000 クレジット、月額上限は 50〜20,000 円の整数で入力してください。月額上限は 1 回の金額以上にしてください。")
                                .font(.footnote).foregroundStyle(.red)
                        }
                        authorizationButton(type: "low_balance", configuration: configuration)
                        stopButton("low_balance")
                    } footer: {
                        Text("現在の総残高が目安を下回ると追加します。月額上限は日本時間の月単位で、手動・毎月のチャージは含みません。承認直後も残高が少ない場合は追加します。")
                    }
                }
            }


            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                    Button("再読み込み") {
                        Task { await load() }
                    }
                }
            }
        }
        .disabled(isBusy || accountStore.isManagingAccount)
        .overlay {
            if isBusy {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressLoadingView()
                }
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isBusy)
        .navigationBarBackButtonHidden(isBusy)
        .task { await load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !isBusy {
                Task { await load() }
            }
        }
        .alert("自動チャージを停止しますか？", isPresented: $showsStopConfirmation) {
            Button("キャンセル", role: .cancel) { stoppingType = nil }
            Button("停止する", role: .destructive) {
                guard let type = stoppingType else { return }

                Task { await stop(type) }
            }
        } message: {
            Text("この種類の新しい自動チャージを停止します。処理中のお支払いは取り消されません。")
        }
        .alert("自動チャージ", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } })
        ) {
            Button("OK", role: .cancel) {
                notice = nil
            }
        } message: {
            Text(notice ?? "")
        }
    }

    private var validReload: Bool {
        guard let threshold, let monthlyLimit else { return false }

        return (50...20000).contains(threshold) && (50...20000).contains(monthlyLimit)
            && (50...20000).contains(reloadAmount) && monthlyLimit >= reloadAmount
    }

    @ViewBuilder private func statusView(_ type: String) -> some View {
        if let saved = setting(type) {
            LabeledContent("保存済みの設定", value: saved.statusText)

            if saved.status == "active" {
                Text(type == "monthly"
                     ? "毎月 \(saved.billingDay ?? 1) 日・¥\(saved.amount.formatted())"
                     : "\((saved.thresholdCredits ?? 0).formatted()) クレジット未満・1 回 ¥\(saved.amount.formatted())・月 ¥\((saved.monthlyLimitAmount ?? 0).formatted()) まで")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            if let error = saved.lastError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        } else {
            LabeledContent("状態", value: "未設定")
        }
    }

    private func authorizationButton(type: String, configuration: StripeTestConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(setting(type)?.status == "active" ? "変更を Apple Pay で承認" : "Apple Pay で設定を承認")
                .font(.subheadline)

            let draft = authorizationDraft(type)
            let preview = previewSetting(draft)
            let option = configuration.options.first { $0.amount == draft.amount }
            let thresholdAmount = option.map {
                max(1, Int(ceil(Double(draft.thresholdCredits ?? 0) * Double($0.amount) / Double(max(1, $0.credits)))))
            }
            
            ActionApplePayButton(.plain, request: AutomaticChargeCoordinator.paymentRequest(
                configuration: configuration,
                setting: preview,
                thresholdAmount: thresholdAmount
            )) { phase in
                if case .willAuthorize = phase {
                    guard !isBusy, accountStore.beginStripeTestPurchase() else { return }
                    
                    isBusy = true
                    errorMessage = nil
                }
                
                coordinator.handle(phase, configuration: configuration, request: draft, accountStore: accountStore) { result in
                    Task {
                        defer { isBusy = false; accountStore.endStripeTestPurchase() }
                        
                        do {
                            notice = try result.get() ? "自動チャージを設定しました。" : "承認をキャンセルしました。自動チャージは有効になっていません。"
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        
                        await load()
                    }
                }
            }
            .payWithApplePayButtonStyle(.automatic)
            .buttonSizing(.flexible)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .disabled(option == nil || !StripeApplePayCoordinator.isSupported || !accountStore.isSignedIn ||
                      accountStore.isAccountOperationBlocked || (type == "low_balance" && !validReload))

            if !StripeApplePayCoordinator.isSupported {
                Text("Wallet に対応するカードを追加してください。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func stopButton(_ type: String) -> some View {
        if let saved = setting(type), saved.status != "disabled" {
            Button("自動チャージを停止", role: .destructive) {
                stoppingType = type
                showsStopConfirmation = true
            }
        }
    }

    private func amountPicker(_ title: String, selection: Binding<Int>, configuration: StripeTestConfiguration, range: ClosedRange<Int> = 1...20000) -> some View {
        Picker(title, selection: selection) {
            ForEach(Array(Set(configuration.options.map(\.amount))).filter { range.contains($0) }.sorted(), id: \.self) { amount in
                Text(amount.formatted(.currency(code: "JPY").precision(.fractionLength(0)))).tag(amount)
            }
        }
    }

    @ViewBuilder private func creditDescription(amount: Int, configuration: StripeTestConfiguration) -> some View {
        if let option = configuration.options.first(where: { $0.amount == amount }) {
            Text("現在は \(option.credits.formatted()) クレジットを受け取れます")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func authorizationDraft(_ type: String) -> AutomaticChargeRequest {
        AutomaticChargeRequest(type: type, amount: type == "monthly" ? monthlyAmount : reloadAmount,
            billingDay: type == "monthly" ? billingDay : nil,
            thresholdCredits: type == "low_balance" ? threshold : nil,
            monthlyLimitAmount: type == "low_balance" ? monthlyLimit : nil, requestID: UUID().uuidString)
    }

    private func previewSetting(_ draft: AutomaticChargeRequest) -> AutomaticChargeSetting {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let next = draft.billingDay.flatMap { day in
            calendar.nextDate(after: Date(), matching: DateComponents(day: day, hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime)
        }
        return AutomaticChargeSetting(id: "preview", type: draft.type, status: "pending_authorization",
            amount: draft.amount, billingDay: draft.billingDay,
            nextChargeAt: next.map { ISO8601DateFormatter().string(from: $0) },
            thresholdCredits: draft.thresholdCredits, monthlyLimitAmount: draft.monthlyLimitAmount, lastError: nil)
    }

    private func stop(_ type: String) async {
        guard accountStore.beginStripeTestPurchase() else { return }
        isBusy = true
        defer { isBusy = false; accountStore.endStripeTestPurchase() }

        do {
            settings = try await accountStore.disableAutomaticCharge(type).settings
            onSettingsLoaded(settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let config = try await accountStore.stripeTestConfiguration()
            let response = try await accountStore.automaticChargeSettings()
            configuration = config
            settings = response.settings
            onSettingsLoaded(settings)
            let amounts = Array(Set(config.options.map(\.amount))).filter { (1...20000).contains($0) }.sorted()
            let reloadAmounts = amounts.filter { (50...20000).contains($0) }
            monthlyAmount = setting("monthly")?.amount ?? amounts.first ?? 0
            reloadAmount = setting("low_balance")?.amount ?? reloadAmounts.first ?? 0

            // 無効化された商品も表示できるよう、再承認時は有効な金額を選択する。
            if !amounts.contains(monthlyAmount) { monthlyAmount = amounts.first ?? 0 }
            if !reloadAmounts.contains(reloadAmount) { reloadAmount = reloadAmounts.first ?? 0 }

            billingDay = setting("monthly")?.billingDay ?? 1
            thresholdText = String(setting("low_balance")?.thresholdCredits ?? 100)
            monthlyLimitText = String(setting("low_balance")?.monthlyLimitAmount ?? max(1000, reloadAmount))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
