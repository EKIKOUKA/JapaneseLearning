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
    @State private var isPurchasing = false
    @State private var showingPurchaseAlert = false
    @State private var purchaseAlertTitle = ""
    @State private var purchaseAlertMessage = ""

    @State private var stripeConfiguration: StripeTestConfiguration?
    @State private var stripeSetupMessage: String?
    @State private var stripeCoordinator = StripeApplePayCoordinator()

    private var creditOptions: [Int] { accountStore.creditProducts.map(\.credits) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("購入するクレジット数を選択してください。")
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

                Button {
                    Task {
                        await purchaseSelectedCredits()
                    }
                } label: {
                    HStack {
                        if isPurchasing {
                            ProgressView().tint(.white)
                        }

                        Text(purchaseButtonTitle)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPurchasing || isLoadingProducts || selectedProduct == nil || accountStore.isAccountOperationBlocked)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Apple Pay（Stripe テスト）").font(.headline)
                    if let configuration = stripeConfiguration,
                       let option = configuration.options.first(where: { $0.credits == selectedCredits }) {
                        Text("\(option.credits) クレジット · ¥\(option.amount)（テスト決済）")
                            .font(.subheadline)
                        if StripeApplePayCoordinator.isSupported {
                            StripeApplePayButton {
                                stripeCoordinator.start(configuration: configuration, credits: selectedCredits,
                                                        accountStore: accountStore) { outcome in
                                    showPurchaseOutcome(outcome)
                                }
                            }
                            .frame(height: 48)
                            .disabled(accountStore.isAccountOperationBlocked)
                        } else {
                            Text("Apple Pay 対応端末で Wallet にカードを追加してください。")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    } else {
                        Text(stripeSetupMessage ?? "Stripe の設定を読み込み中…")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("設定を再読み込み") { Task { await loadStripeConfiguration() } }
                    }
                }

                if isLoadingProducts {
                    ProgressView("価格を読み込み中…")
                        .frame(maxWidth: .infinity)
                } else if products.isEmpty {
                    Text("購入商品を読み込めませんでした。時間をおいて再度お試しください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text("上の購入ボタンでは App Store を通じて決済されます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(20)
        }
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

    private var purchaseButtonTitle: String {
        guard let selectedProduct else {
            return "商品を利用できません"
        }
        return "\(selectedCredits.formatted())クレジットを購入 · \(selectedProduct.displayPrice)"
    }

    /// 価格は StoreKit がストア地域に応じて返す表示価格を使う。アプリ内の固定値で請求しない。
    private func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

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
        let productID = accountStore.productID(for: credits)
        let price = productID.flatMap { id in products.first { $0.id == id }?.displayPrice }

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

                Text(price ?? (isLoadingProducts ? "読み込み中…" : "販売なし"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(price == nil ? Color.secondary : Color.accentColor)
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
