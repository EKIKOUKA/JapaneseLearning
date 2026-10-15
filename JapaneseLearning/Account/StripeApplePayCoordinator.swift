import PassKit
@preconcurrency import StripeApplePay
import SwiftUI

/// Apple Pay の表示と Stripe SDK の連携だけを担当する。残高はサーバー確認後に Store が更新する。
@MainActor
final class StripeApplePayCoordinator: NSObject, ApplePayContextDelegate {
    private var context: STPApplePayContext?
    private var accountStore: AppleAccountStore?
    private var credits = 0
    private var requestID = UUID().uuidString
    private var completion: ((CreditPurchaseOutcome) -> Void)?

    static var isSupported: Bool { StripeAPI.deviceSupportsApplePay() }

    func start(configuration: StripeTestConfiguration, credits: Int, accountStore: AppleAccountStore,
               completion: @escaping (CreditPurchaseOutcome) -> Void) {
        guard let option = configuration.options.first(where: { $0.credits == credits }) else {
            completion(.failed("Apple Pay を表示できません。"))
            return
        }
        guard accountStore.beginStripeTestPurchase() else {
            completion(.failed("ログイン状態と購入の処理状況を確認してください。"))
            return
        }
        
        self.accountStore = accountStore
        self.credits = credits
        self.requestID = UUID().uuidString
        self.completion = completion
        StripeAPI.defaultPublishableKey = configuration.publishableKey
        
        let request = StripeAPI.paymentRequest(
            withMerchantIdentifier: configuration.merchantID,
            country: configuration.country,
            currency: configuration.currency
        )
        
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(
                label: "ことね-言語シャドーイング（テスト）",
                amount: NSDecimalNumber(value: option.amount)
            )
        ]
        
        guard let context = STPApplePayContext(paymentRequest: request, delegate: self) else {
            finish(.failed("Apple Pay の設定と Wallet のカードを確認してください。"))
            return
        }
        self.context = context
        // ボタン操作の直後にシートを開く。非同期の注文作成は支払い方法が確定した後に行う。
        context.presentApplePay()
    }

    func applePayContext(_ context: STPApplePayContext, didCreatePaymentMethod paymentMethod: StripeAPI.PaymentMethod,
             paymentInformation: PKPayment) async throws -> String {
        guard let accountStore else { throw URLError(.userAuthenticationRequired) }
        return try await accountStore.createStripeTestIntent(credits: credits, requestID: requestID).clientSecret
    }

    func applePayContext(_ context: STPApplePayContext, didCompleteWith status: STPApplePayContext.PaymentStatus,
                         error: Error?) {
        switch status {
            case .success:
                Task {
                    guard let accountStore else { return }
                    
                    do {
                        let result = try await accountStore.reconcileStripeTestPayments()
                        finish(.purchased(added: result.addedCredits, balance: result.creditBalance))
                    } catch {
                        finish(.failed("支払い結果の反映を確認できませんでした。次回この画面を開くと再確認します。"))
                    }
                }
            case .userCancellation: finish(.cancelled)
            case .error: finish(.failed(error?.localizedDescription ?? "Apple Pay のテスト決済に失敗しました。"))
            @unknown default: finish(.failed("支払い結果を確認できませんでした。"))
        }
    }

    private func finish(_ outcome: CreditPurchaseOutcome) {
        accountStore?.endStripeTestPurchase()
        completion?(outcome)
        completion = nil
        context = nil
        accountStore = nil
    }
}

/// Apple の正式な支払いボタンを使い、通常のテキストボタンでロゴを再現しない。
struct StripeApplePayButton: UIViewRepresentable {
    let action: () -> Void
    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .automatic)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tap), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: PKPaymentButton, context: Context) { context.coordinator.action = action }
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tap() { action() }
    }
}
