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
                    Section("現在の設定") {
                        LabeledContent("状態", value: setting("monthly")?.statusText ?? "未設定")
                        
                        if let saved = setting("monthly"), saved.status == "active" {
                            LabeledContent("毎月の金額", value: "¥\(saved.amount.formatted())")
                            LabeledContent("チャージ日", value: "毎月 \(saved.billingDay ?? 1) 日")
                        }
                        
                        if let error = setting("monthly")?.lastError {
                            Text(error).font(.footnote).foregroundStyle(.red)
                        }
                    }

                    Section("チャージ条件") {
                        amountPicker("毎月の金額", selection: $monthlyAmount, configuration: configuration)
                        Picker("チャージ日", selection: $billingDay) {
                            ForEach(1...28, id: \.self) {
                                Text("毎月 \($0) 日").tag($0)
                            }
                        }
                        
                        if let option = configuration.options.first(where: { $0.amount == monthlyAmount }) {
                            LabeledContent("1 回で追加されるクレジット", value: option.credits.formatted())
                        }
                    }

                    Section {
                        authorizationButton(type: "monthly", configuration: configuration)
                    } footer: {
                        Text("次の指定日から毎月チャージします。承認当日のチャージは行いません。変更には再承認が必要です。")
                    }

                    if let saved = setting("monthly"), saved.status != "disabled" {
                        Section {
                            stopButton("monthly")
                        }
                    }
                }

                if kind == .lowBalance {
                    Section("現在の設定") {
                        LabeledContent("状態", value: setting("low_balance")?.statusText ?? "未設定")
                        
                        if let saved = setting("low_balance"), saved.status == "active" {
                            LabeledContent("開始残高", value: "\((saved.thresholdCredits ?? 0).formatted()) クレジット未満")
                            LabeledContent("1 回の金額", value: "¥\(saved.amount.formatted())")
                            LabeledContent("月額上限", value: "¥\((saved.monthlyLimitAmount ?? 0).formatted())")
                        }
                        
                        if let error = setting("low_balance")?.lastError {
                            Text(error).font(.footnote).foregroundStyle(.red)
                        }
                    }

                    Section {
                        LabeledContent("開始残高") {
                            HStack(spacing: 6) {
                                TextField("100", text: $thresholdText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(minWidth: 48, idealWidth: 64, maxWidth: 78)
                                    .accessibilityLabel("開始残高")
                                Text("クレジット未満").foregroundStyle(.secondary)
                            }
                        }

                        amountPicker("1 回の金額", selection: $reloadAmount, configuration: configuration, range: 50...30000)
                        if let option = configuration.options.first(where: { $0.amount == reloadAmount }) {
                            LabeledContent("1 回で追加されるクレジット", value: option.credits.formatted())
                        }

                        LabeledContent("月額上限") {
                            HStack(spacing: 6) {
                                TextField("1000", text: $monthlyLimitText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 90)
                                    .accessibilityLabel("月額上限")
                                Text("円").foregroundStyle(.secondary)
                            }
                        }

                        if !validReload {
                            Text("開始残高と月額上限は 50〜30,000 の整数で入力し、月額上限は 1 回の金額以上にしてください。")
                                .font(.footnote).foregroundStyle(.red)
                        }
                    } header: {
                        Text("チャージ条件")
                    } footer: {
                        Text("総残高が開始残高を下回るとチャージします。月額上限は日本時間の暦月ごとに適用され、手動・毎月のチャージは含みません。")
                    }

                    Section {
                        authorizationButton(type: "low_balance", configuration: configuration)
                    } footer: {
                        Text("承認直後に総残高が開始残高を下回っている場合もチャージします。")
                    }

                    if let saved = setting("low_balance"), saved.status != "disabled" {
                        Section {
                            stopButton("low_balance")
                        }
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

        return (50...30000).contains(threshold) && (50...30000).contains(monthlyLimit)
            && (50...30000).contains(reloadAmount) && monthlyLimit >= reloadAmount
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

    private func amountPicker(_ title: String, selection: Binding<Int>, configuration: StripeTestConfiguration, range: ClosedRange<Int> = 1...30000) -> some View {
        Picker(title, selection: selection) {
            ForEach(Array(Set(configuration.options.map(\.amount))).filter { range.contains($0) }.sorted(), id: \.self) { amount in
                Text(amount.formatted(.currency(code: "JPY").precision(.fractionLength(0)))).tag(amount)
            }
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
            let amounts = Array(Set(config.options.map(\.amount))).filter { (1...30000).contains($0) }.sorted()
            let reloadAmounts = amounts.filter { (50...30000).contains($0) }
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
