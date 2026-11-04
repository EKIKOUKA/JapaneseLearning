import PassKit
@preconcurrency import StripeApplePay
@preconcurrency import StripePayments
import SwiftUI

/// SwiftUI のシートで承認し、SetupIntent で将来の支払い方法を登録する。
@MainActor
final class AutomaticChargeCoordinator {
    private var preparation: Task<AutomaticChargeAuthorization, Error>?
    private var result: Result<Bool, Error> = .success(false)
    private var pending = false
    private var dismissed = false
    private var completion: ((Result<Bool, Error>) -> Void)?

    static func paymentRequest(configuration: StripeTestConfiguration, setting: AutomaticChargeSetting,
                               thresholdAmount: Int?) -> PKPaymentRequest {
        let managementURL = URL(string: "https://admin.japanese-learning.makoto.lol/credits/automatic")!
        let request = StripeAPI.paymentRequest(
            withMerchantIdentifier: configuration.merchantID,
            country: configuration.country,
            currency: configuration.currency
        )
        
        let amount = NSDecimalNumber(value: setting.amount)
        if setting.type == "monthly" {
            let item = PKRecurringPaymentSummaryItem(label: "毎月のクレジットチャージ", amount: amount)
            item.intervalUnit = .month
            item.intervalCount = 1
            item.startDate = setting.nextChargeAt.flatMap { ISO8601DateFormatter().date(from: $0) }
            
            let recurring = PKRecurringPaymentRequest(
                paymentDescription: "ことね 毎月のチャージ",
                regularBilling: item, managementURL: managementURL
            )
            
            recurring.billingAgreement = """
            日本時間の毎月 \(setting.billingDay ?? 1) 日に ¥\(setting.amount.formatted()) をチャージします。
            チャージで受け取れるクレジット数は変更される場合があります。
            アプリの自動チャージ設定から停止できます。
            """
            request.recurringPaymentRequest = recurring
        } else {
            let item = PKAutomaticReloadPaymentSummaryItem(label: "残高不足時の追加チャージ", amount: amount)
            item.thresholdAmount = NSDecimalNumber(value: thresholdAmount ?? 1)
            
            let reload = PKAutomaticReloadPaymentRequest(
                paymentDescription: "ことね 追加チャージ",
                automaticReloadBilling: item,
                managementURL: managementURL
            )
            reload.billingAgreement = """
            残高が \((setting.thresholdCredits ?? 0).formatted()) クレジット未満になると ¥\(setting.amount.formatted()) を追加します。
            追加チャージの上限は、日本時間の毎月 ¥\((setting.monthlyLimitAmount ?? 0).formatted()) です。手動・毎月のチャージは含みません。

            チャージで受け取れるクレジット数は変更される場合があります。
            上部の円表示は残高の目安です。実際はクレジット数で判定します。
            設定直後も残高が少ない場合は追加します。アプリから停止できます。
            """
            request.automaticReloadPaymentRequest = reload
        }
        
        // 今回は支払方法の登録のみ。将来の請求額は各専用リクエストに表示する。
        request.paymentSummaryItems = [PKPaymentSummaryItem(label: "ことね（支払方法の登録）", amount: .zero)]
        return request
    }

    func handle(_ phase: PayWithApplePayButtonPaymentAuthorizationPhase,
                configuration: StripeTestConfiguration, request: AutomaticChargeRequest,
                accountStore: AppleAccountStore, completion: @escaping (Result<Bool, Error>) -> Void) {
        switch phase {
        case .willAuthorize:
            guard preparation == nil else { return }
            self.completion = completion
            result = .success(false)
            dismissed = false
            preparation = Task { try await accountStore.prepareAutomaticCharge(request) }
        case .didAuthorize(let payment, let handler):
            guard let preparation, !pending else {
                handler(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                return
            }
            pending = true
            Task {
                do {
                    let authorization = try await preparation.value
                    guard authorization.setting.type == request.type,
                          authorization.setting.amount == request.amount,
                          authorization.setting.billingDay == request.billingDay,
                          authorization.setting.thresholdCredits == request.thresholdCredits,
                          authorization.setting.monthlyLimitAmount == request.monthlyLimitAmount else {
                        throw URLError(.badServerResponse)
                    }
                    let client = STPAPIClient(publishableKey: configuration.publishableKey)
                    let existing = try await client.retrieveSetupIntent(withClientSecret: authorization.clientSecret)
                    if existing.status != .succeeded {
                        let method: STPPaymentMethod = try await withCheckedThrowingContinuation { continuation in
                            client.createPaymentMethod(with: payment) { method, error in
                                if let method { continuation.resume(returning: method) }
                                else { continuation.resume(throwing: error ?? URLError(.badServerResponse)) }
                            }
                        }
                        let params = STPSetupIntentConfirmParams(clientSecret: authorization.clientSecret)
                        params.paymentMethodID = method.stripeId
                        params.useStripeSDK = true
                        let confirmed = try await client.confirmSetupIntent(with: params)
                        guard confirmed.status == .succeeded else { throw URLError(.cannotParseResponse) }
                    }
                    // サーバーが Stripe の状態を検証してから設定を有効にする。
                    _ = try await accountStore.completeAutomaticCharge(authorization.authorizationID)
                    result = .success(true)
                    handler(PKPaymentAuthorizationResult(status: .success, errors: nil))
                } catch {
                    result = .failure(error)
                    handler(PKPaymentAuthorizationResult(status: .failure, errors: [error]))
                }
                pending = false
                if dismissed { finish() }
            }
        case .didFinish:
            dismissed = true
            if !pending {
                // シートを早く閉じても準備処理が終わってから設定を再取得する。
                Task {
                    _ = try? await preparation?.value
                    finish()
                }
            }
        @unknown default: break
        }
    }

    private func finish() {
        let callback = completion
        let outcome = result
        preparation = nil
        completion = nil
        callback?(outcome)
    }
}
