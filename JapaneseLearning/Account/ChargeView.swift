//
//  ChargeView.swift
//  JapaneseLearning
//
//  Created by Makoto on 2026/10/05.
//

import SwiftUI
import StoreKit

struct ChargeView: View {
    @Environment(AppleAccountStore.self) private var accountStore
    @State private var selectedCredits = 0
    @State private var products: [Product] = []
    @State private var isLoadingProducts = true
    @State private var hasLoadedProducts = false
    @State private var isPurchasing = false
    @State private var showingPurchaseAlert = false
    @State private var purchaseAlertTitle = ""
    @State private var purchaseAlertMessage = ""

    @State private var stripeConfiguration: StripeTestConfiguration?
    @State private var stripeSetupMessage: String?
    @State private var isLoadingStripeConfiguration = true
    @State private var stripeCoordinator = StripeApplePayCoordinator()

    private var creditOptions: [Int] { accountStore.creditProducts.map(\.credits) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("チャージするクレジット数を選んで、お支払いください")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("現在の残高")
                        Spacer()
                        Text("\(accountStore.accountCredits.formatted()) クレジット")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.smooth(duration: 1.0), value: accountStore.accountCredits)
                    }
                    .font(.subheadline)
                    .padding(.top, 8)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 14
                ) {
                    ForEach(creditOptions, id: \.self) { credits in
                        creditOption(credits)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("お支払い金額")
                        .font(.headline)

                    Group {
                        if let selected_price = selectedPrice {
                            Text(selected_price)
                                .font(.title2.bold().monospacedDigit())
                        } else {
                            ProgressView()
                                .controlSize(.regular)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .padding(.horizontal, 18)
                    .background(.background, in: RoundedRectangle(cornerRadius: 18))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("お支払い方法")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 14) {
                        // AppStorePayment
                        ApplePayPayment
                    }
                    .padding(18)
                    .background(.background, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("クレジットチャージ")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProducts()
            await loadStripeConfiguration()
        }
        .alert(purchaseAlertTitle, isPresented: $showingPurchaseAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseAlertMessage)
        }
    }

    private var selectedProduct: Product? {
        products.first { accountStore.credits(for: $0.id) == selectedCredits }
    }

    private var stripeOption: StripeTestConfiguration.Option? {
        stripeConfiguration?.options.first { $0.credits == selectedCredits }
    }

    private var selectedPrice: String? {
        selectedProduct?.displayPrice
            ?? stripeOption.map { $0.amount.formatted(.currency(code: "JPY").precision(.fractionLength(0))) }
    }

    private var AppStorePayment: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                Task { await purchaseSelectedCredits() }
            } label: {
                HStack(spacing: 6) {
                    if isPurchasing { ProgressView() }
                    Text("アプリ内購入")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .opacity(isPurchasing || isLoadingProducts || selectedProduct == nil || accountStore.isAccountOperationBlocked ? 0.45 : 1)
            .disabled(isPurchasing || isLoadingProducts || selectedProduct == nil || accountStore.isAccountOperationBlocked)

            if hasLoadedProducts && !isLoadingProducts && selectedProduct == nil {
                Text("商品を利用できません")
                    .font(.caption).foregroundStyle(.secondary)
                Button("再読み込み") { Task { await loadProducts() } }
                    .font(.caption)
                    .disabled(accountStore.isAccountOperationBlocked)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ApplePayPayment: some View {
        VStack(alignment: .leading, spacing: 14) {
            StripeApplePayButton {
                guard let configuration = stripeConfiguration, stripeOption != nil else { return }
                stripeCoordinator.start(configuration: configuration, credits: selectedCredits, accountStore: accountStore) {
                    showPurchaseOutcome($0)
                }
            }
            .frame(height: 48)
            .disabled(isLoadingStripeConfiguration || stripeOption == nil || !StripeApplePayCoordinator.isSupported || accountStore.isAccountOperationBlocked)

            if !isLoadingStripeConfiguration, stripeOption == nil {
                Text(stripeSetupMessage ?? "この商品は利用できません")
                    .font(.caption).foregroundStyle(.secondary)

                Button("再読み込み") { Task {
                    await loadStripeConfiguration() 
                }}
                .font(.caption)
                .disabled(accountStore.isAccountOperationBlocked)
            } else if !isLoadingStripeConfiguration && !StripeApplePayCoordinator.isSupported {
                Text("対応端末の Wallet にカードを追加してください。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 価格は StoreKit がストア地域に応じて返す表示価格を使う。アプリ内の固定値で請求しない。
    private func loadProducts() async {
        isLoadingProducts = true
        defer {
            isLoadingProducts = false
            hasLoadedProducts = true
        }

        do {
            try await accountStore.loadCreditProducts()
            if !creditOptions.contains(selectedCredits) { selectedCredits = creditOptions.first ?? 0 }
            let fetchedProducts = try await Product.products(for: accountStore.creditProductIDs)
            print("StoreKit raw products:", fetchedProducts.map { "\($0.id) [\($0.type)]" })

            products = fetchedProducts
                .filter { $0.type == .consumable }
                .sorted {
                    (accountStore.credits(for: $0.id) ?? 0) <
                    (accountStore.credits(for: $1.id) ?? 0)
                }
            print("StoreKit consumable products:", products.map { "\($0.id) [\($0.type)]" })
        } catch {
            products = []
            purchaseAlertTitle = "商品を読み込めませんでした"
            purchaseAlertMessage = error.localizedDescription
            showingPurchaseAlert = true
        }
    }

    /// この画面は結果の表示を担当し、検証・残高反映・再送・finish は Store に集約する。
    private func purchaseSelectedCredits() async {
        guard let selectedProduct else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        showPurchaseOutcome(await accountStore.purchaseCredits(selectedProduct))
    }

    private func showPurchaseOutcome(_ outcome: CreditPurchaseOutcome) {
        switch outcome {
            case .purchased(let added, let balance):
                purchaseAlertTitle = "チャージしました"
                purchaseAlertMessage = added > 0
                    ? "+\(added.formatted()) クレジットを追加しました。現在の残高は \(balance.formatted()) クレジットです。"
                    : "この購入はすでに反映されています。現在の残高は \(balance.formatted()) クレジットです。"
                showingPurchaseAlert = true
            case .pending:
                purchaseAlertTitle = "購入の承認待ちです"
                purchaseAlertMessage = "承認されると、クレジットが自動的に追加されます。"
                showingPurchaseAlert = true
            case .cancelled:
                break
            case .failed(let message):
                purchaseAlertTitle = "購入できませんでした"
                purchaseAlertMessage = message
                showingPurchaseAlert = true
        }
    }

    private func loadStripeConfiguration() async {
        isLoadingStripeConfiguration = true
        stripeSetupMessage = nil
        defer { isLoadingStripeConfiguration = false }

        do {
            stripeConfiguration = try await accountStore.stripeTestConfiguration()
            stripeSetupMessage = nil
            _ = try await accountStore.reconcileStripeTestPayments()
        } catch {
            stripeSetupMessage = error.localizedDescription
            if stripeConfiguration != nil {
                purchaseAlertTitle = "支払いの確認が必要です"
                purchaseAlertMessage = "前回のテスト決済を確認できませんでした。時間をおいて設定を再読み込みしてください。"
                showingPurchaseAlert = true
            }
        }
    }

    private func creditOption(_ credits: Int) -> some View {
        let isSelected = selectedCredits == credits

        return Button {
            selectedCredits = credits
        } label: {
            VStack(spacing: 10) {
                Text(credits.formatted())
                    .font(.title.bold().monospacedDigit())
                    .contentTransition(.numericText())

                Text("クレジット")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(uiColor: .secondarySystemGroupedBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
