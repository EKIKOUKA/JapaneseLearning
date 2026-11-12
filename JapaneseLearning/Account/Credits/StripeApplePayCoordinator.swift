//
//  StripeApplePayCoordinator.swift
//  JapaneseLearning
//
//  Created by Makoto on 2026/10/15.
//

import PassKit
@preconcurrency import StripeApplePay
@preconcurrency import StripePayments
import SwiftUI

/// Apple Pay の承認結果を Stripe に渡して決済を確定する。
@MainActor
final class StripeApplePayCoordinator {
    static var isSupported: Bool { StripeAPI.deviceSupportsApplePay() }
    private var accountStore: AppleAccountStore?
    private var configuration: StripeTestConfiguration?
    private var credits = 0
    private var requestID = UUID().uuidString
    private var outcome: CreditPurchaseOutcome = .cancelled
    private var completion: ((CreditPurchaseOutcome) -> Void)?
    private var pending = false
    private var dismissed = false

    static func paymentRequest(configuration: StripeTestConfiguration, credits: Int) -> PKPaymentRequest? {
        guard let option = configuration.options.first(where: { $0.credits == credits }) else { return nil }

        let request = StripeAPI.paymentRequest(
            withMerchantIdentifier: configuration.merchantID,
            country: configuration.country,
            currency: configuration.currency
        )
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: "ことね-言語シャドーイング",
            amount: NSDecimalNumber(value: option.amount))
        ]

        return request
    }

    func handle(_ phase: PayWithApplePayButtonPaymentAuthorizationPhase,
                configuration: StripeTestConfiguration, credits: Int, accountStore: AppleAccountStore,
                completion: @escaping (CreditPurchaseOutcome) -> Void) {
        switch phase {
            case .willAuthorize:
                guard self.accountStore == nil, accountStore.beginStripeTestPurchase() else { return }
                self.accountStore = accountStore
                self.configuration = configuration
                self.credits = credits
                self.completion = completion
                requestID = UUID().uuidString
                outcome = .cancelled
                dismissed = false
            case .didAuthorize(let payment, let resultHandler):
                guard let store = self.accountStore, let config = self.configuration, !pending else {
                    resultHandler(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                    return
                }
                pending = true

                Task {
                    do {
                        let client = STPAPIClient(publishableKey: config.publishableKey)
                        let method: STPPaymentMethod = try await withCheckedThrowingContinuation { continuation in
                            client.createPaymentMethod(with: payment) { method, error in
                                if let method { continuation.resume(returning: method) }
                                else { continuation.resume(throwing: error ?? URLError(.badServerResponse)) }
                            }
                        }
                        
                        let intent = try await store.createStripeTestIntent(credits: self.credits, requestID: requestID)
                        let existing: STPPaymentIntent = try await withCheckedThrowingContinuation { continuation in
                            client.retrievePaymentIntent(withClientSecret: intent.clientSecret) { intent, error in
                                if let intent { continuation.resume(returning: intent) }
                                else { continuation.resume(throwing: error ?? URLError(.badServerResponse)) }
                            }
                        }
                        
                        let confirmed: STPPaymentIntent
                        if existing.status == .succeeded || existing.status == .requiresCapture {
                            // 前回の応答だけが失われた場合も再請求しない。
                            confirmed = existing
                        } else {
                            let params = STPPaymentIntentParams(clientSecret: intent.clientSecret)
                            params.paymentMethodId = method.stripeId
                            params.useStripeSDK = true
                            confirmed = try await withCheckedThrowingContinuation { continuation in
                                client.confirmPaymentIntent(with: params) { intent, error in
                                    if let intent {
                                        continuation.resume(returning: intent)
                                    } else {
                                        continuation.resume(throwing: error ?? URLError(.badServerResponse))
                                    }
                                }
                            }
                        }
                        
                        guard confirmed.status == .succeeded || confirmed.status == .requiresCapture else {
                            throw URLError(.cannotParseResponse)
                        }
                        
                        // 支払い成功と残高更新の失敗は分ける。再決済を促さない。
                        do {
                            let result = try await store.reconcileStripeTestPayments()
                            outcome = .purchased(added: result.addedCredits, balance: result.creditBalance)
                        } catch {
                            outcome = .failed("支払い結果の反映を確認できませんでした。次回この画面を開くと再確認します。")
                        }
                        
                        resultHandler(PKPaymentAuthorizationResult(status: .success, errors: nil))
                    } catch {
                        outcome = .failed(error.localizedDescription)
                        resultHandler(PKPaymentAuthorizationResult(status: .failure, errors: [error]))
                    }
                    
                    pending = false
                    if dismissed { finish() }
                }
            case .didFinish:
                dismissed = true
                if !pending { finish() }
            @unknown default: break
        }
    }

    private func finish() {
        let callback = completion
        let result = outcome
        accountStore?.endStripeTestPurchase()
        accountStore = nil
        configuration = nil
        completion = nil
        callback?(result)
    }
}

/// action 版を使用し、request 版でボタンの幅が固定される問題を回避する。
struct ActionApplePayButton: View {
    private let label: PayWithApplePayButtonLabel
    private let request: PKPaymentRequest
    private let onPhase: (PayWithApplePayButtonPaymentAuthorizationPhase) -> Void
    @State private var presenter = ApplePaySheetPresenter()

    init(_ label: PayWithApplePayButtonLabel, request: PKPaymentRequest,
         onPhase: @escaping (PayWithApplePayButtonPaymentAuthorizationPhase) -> Void) {
        self.label = label
        self.request = request
        self.onPhase = onPhase
    }

    var body: some View {
        PayWithApplePayButton(label) {
            presenter.present()
        }
        .onChange(of: ObjectIdentifier(request), initial: true) {
            presenter.update(request: request, onPhase: onPhase)
        }
    }
}

@MainActor
private final class ApplePaySheetPresenter: NSObject, PKPaymentAuthorizationControllerDelegate {
    private var controller: PKPaymentAuthorizationController?
    private var request: PKPaymentRequest?
    private var authorizationHandler: ((PayWithApplePayButtonPaymentAuthorizationPhase) -> Void)?
    private var onPhase: ((PayWithApplePayButtonPaymentAuthorizationPhase) -> Void)?

    func update(request: PKPaymentRequest, onPhase: @escaping (PayWithApplePayButtonPaymentAuthorizationPhase) -> Void) {
        self.request = request
        authorizationHandler = onPhase
    }

    func present() {
        guard controller == nil, let request, let onPhase = authorizationHandler else { return }
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        self.controller = controller
        self.onPhase = onPhase
        controller.delegate = self
        onPhase(.willAuthorize)
        controller.present { [weak self] presented in
            guard !presented else { return }
            Task { @MainActor [weak self] in self?.finish() }
        }
    }

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        guard let onPhase else {
            completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
            return
        }
        onPhase(.didAuthorize(payment: payment, resultHandler: completion))
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss { [weak self] in
            Task { @MainActor [weak self] in self?.finish() }
        }
    }

    private func finish() {
        let callback = onPhase
        onPhase = nil
        controller?.delegate = nil
        controller = nil
        callback?(.didFinish)
    }
}
