//
//  AppleAccountStore.swift
//  JapaneseLearning
//
//  Created by Makoto on 2026/10/05.
//

import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Security
import StoreKit

enum CreditPurchaseOutcome {
    case purchased(added: Int, balance: Int)
    case pending
    case cancelled
    case failed(String)
}

@MainActor
@Observable
final class AppleAccountStore {
    static var savedSessionToken: String? { AppleSessionKeychain.read() }
    static var savedUserID: String? { UserDefaults.standard.string(forKey: Keys.userID) }
    private enum Keys {
        static let userID = "apple.account.userID"
    }

    private(set) var userID: String?
    private(set) var credentialState: ASAuthorizationAppleIDProvider.CredentialState = .revoked
    private(set) var signInError: String?
    private(set) var accountNotice: String?
    private(set) var isManagingAccount = false
    private(set) var isPurchasingCredits = false
    private(set) var isApplyingCreditTransactions = false
    private(set) var dailyPracticeGoalMinutes = 10
    private(set) var isSavingDailyPracticeGoal = false
    @ObservationIgnored private var goalRevision = 0

    // 購入確認・残高反映中はアカウントを固定し、途中のログアウトや退会を防ぐ。
    var isAccountOperationBlocked: Bool {
        isManagingAccount || isPurchasingCredits || isApplyingCreditTransactions || isSavingDailyPracticeGoal
    }

    private(set) var accountCredits: Int
    @ObservationIgnored private var balanceRevision = 0
    @ObservationIgnored private var creditTransactionTaskID: UUID?
    @ObservationIgnored private var sessionToken: String?
    @ObservationIgnored private var creditTransactionTask: Task<CreditPurchaseOutcome, Never>?
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?

    var isSignedIn: Bool {
        userID != nil && sessionToken != nil && credentialState != .revoked && credentialState != .notFound
    }

    /// Keychain には本アプリの session のみ保存する。Apple の refresh token と残高はサーバーで管理する。
    init() {
        accountCredits = 0

        userID = UserDefaults.standard.string(forKey: Keys.userID)
        sessionToken = AppleSessionKeychain.read()
        if userID != nil, sessionToken != nil {
            credentialState = .authorized
        } else if userID == nil {
            AppleSessionKeychain.delete()
            sessionToken = nil
        }

        transactionUpdatesTask = Task { [weak self] in
            await self?.retryUnfinishedCreditTransactions()

            for await result in Transaction.updates {
                guard let self else { return }
                let outcome = await self.processCreditTransaction(result)

                if case .failed(let message) = outcome {
                    print("Credit transaction update failed: \(message)")
                }
            }
        }
    }

    /// Apple の認証結果をサーバーに送る。端末から送られた user ID だけでは本人と判断しない。
    private func makeAppleLoginRequest(
        from credential: ASAuthorizationAppleIDCredential,
        hashedNonce: String
    ) throws -> AppleLoginRequest {
        guard
            let tokenData = credential.identityToken,
            let identityToken = String(data: tokenData, encoding: .utf8),
            let codeData = credential.authorizationCode,
            let authorizationCode = String(data: codeData, encoding: .utf8)
        else {
            throw URLError(.cannotDecodeContentData)
        }

        return AppleLoginRequest(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            hashedNonce: hashedNonce
        )
    }

    private(set) var creditProducts: [CreditProduct] = []

    var creditProductIDs: [String] { creditProducts.map(\.appStoreProductID) }

    func productID(for credits: Int) -> String? {
        creditProducts.first(where: { $0.credits == credits })?.appStoreProductID
    }

    func credits(for productID: String) -> Int? {
        creditProducts.first(where: { $0.appStoreProductID == productID })?.credits
    }

    func loadCreditProducts() async throws {
        let catalog: CreditProductCatalog = try await WorkersAPI.get("credit_products", requiresAuthentication: true)
        creditProducts = catalog.products
    }

    // Stripe はテスト専用。Release では購入経路自体を含めない。
    func beginStripeTestPurchase() -> Bool {
        guard isSignedIn, !isAccountOperationBlocked else { return false }
        isPurchasingCredits = true

        return true
    }

    func endStripeTestPurchase() { isPurchasingCredits = false }

    func stripeTestConfiguration() async throws -> StripeTestConfiguration {
        guard let sessionToken, isSignedIn else { throw URLError(.userAuthenticationRequired) }

        return try await WorkersAPI.postForResponse(
            "payments/stripe/config",
            body: [String: String](),
            authorizationToken: sessionToken
        )
    }

    func createStripeTestIntent(credits: Int, requestID: String) async throws -> StripeTestIntent {
        guard let sessionToken, isSignedIn else { throw URLError(.userAuthenticationRequired) }

        return try await WorkersAPI.postForResponse(
            "payments/stripe/create",
            body: StripeTestCreateRequest(credits: credits, requestID: requestID),
            authorizationToken: sessionToken
        )
    }

    /// 再起動・通信断の後も Stripe の確定状態から復旧する。端末側で残高を足し算しない。
    func reconcileStripeTestPayments() async throws -> CreditChargeResponse {
        guard let sessionToken, isSignedIn else { throw URLError(.userAuthenticationRequired) }
        let initialBalanceRevision = balanceRevision
        let response: CreditChargeResponse = try await WorkersAPI.postForResponse(
            "payments/stripe/reconcile",
            body: [String: String](),
            authorizationToken: sessionToken
        )

        if self.sessionToken == sessionToken, balanceRevision == initialBalanceRevision {
            setCreditBalance(response.creditBalance)
        }

        return response
    }

    /// appAccountToken で購入を現在のアカウントに紐付ける。.pending は承認待ちで、まだ残高には反映しない。
    func purchaseCredits(_ product: Product) async -> CreditPurchaseOutcome {
        guard isSignedIn, let userID else {
            return .failed("チャージするには、Apple でログインしてください。")
        }
        guard !isAccountOperationBlocked else {
            return .failed("アカウントまたは購入を処理中です。完了してから再度お試しください。")
        }
        guard credits(for: product.id) != nil, product.type == .consumable else {
            return .failed("選択した商品を確認できませんでした。")
        }

        isPurchasingCredits = true
        defer { isPurchasingCredits = false }
        do {
            switch try await product.purchase(options: [.appAccountToken(Self.creditAccountToken(for: userID))]) {
                case .success(let verificationResult):
                    return await processCreditTransaction(verificationResult)
                case .pending:
                    return .pending
                case .userCancelled:
                    return .cancelled
                @unknown default:
                    return .failed("購入の結果を確認できませんでした。")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// 端末の StoreKit 検証に加え、サーバーでも JWS を検証し、取引 ID で二重付与を防ぐ。
    /// DB への付与確認後にだけ finish する。通信失敗時は未完了のまま残して再送する。
    private func processCreditTransaction(
        _ verificationResult: VerificationResult<Transaction>
    ) async -> CreditPurchaseOutcome {
        guard case .verified(let transaction) = verificationResult else {
            return .failed("Appleによる購入の検証に失敗しました。")
        }

        // 未完了取引は商品一覧の取得前にも届く。所属商品の最終判定はサーバーで行う。
        guard transaction.productType == .consumable else {
            return .failed("購入商品がクレジット商品と一致しません。")
        }

        // purchase()・updates・unfinished に同じ取引が届くため、直列化し、サーバーでも重複を排除する。
        let taskID = UUID()
        creditTransactionTaskID = taskID
        isApplyingCreditTransactions = true
        let previous = creditTransactionTask
        let task = Task { [weak self] () -> CreditPurchaseOutcome in
            if let previous { _ = await previous.value }
            guard let self, self.isSignedIn, let sessionToken = self.sessionToken else {
                return .failed("購入は保留されています。Apple でログインすると再度反映されます。")
            }

            do {
                let response: CreditChargeResponse = try await WorkersAPI.postForResponse(
                    "user/credit_charge",
                    body: CreditChargeRequest(signedTransaction: verificationResult.jwsRepresentation),
                    authorizationToken: sessionToken
                )

                if self.sessionToken == sessionToken {
                    self.setCreditBalance(response.creditBalance)
                }
                // 通信失敗時に finish しないことで、次回起動・ログイン時の再送を可能にする。
                await transaction.finish()

                return .purchased(added: response.addedCredits, balance: response.creditBalance)
            } catch {
                return .failed("購入の反映に失敗しました。再接続後に再度反映されます。\n\(error.localizedDescription)")
            }
        }

        creditTransactionTask = task
        let outcome = await task.value
        // 古い処理が後続のタスクを消さないよう、最後のタスクだけがキューの状態を解除する。
        if creditTransactionTaskID == taskID {
            creditTransactionTask = nil
            creditTransactionTaskID = nil
            isApplyingCreditTransactions = false
        }

        return outcome
    }

    /// サーバーと同じ「SHA-256 → 先頭16バイト → UUID」で購入の帰属を示す。認証用の秘密情報ではない。
    private static func creditAccountToken(for userID: String) -> UUID {
        let hex = SHA256.hash(data: Data(userID.utf8)).prefix(16)
            .map { String(format: "%02x", $0) }.joined()
        let parts = [0..<8, 8..<12, 12..<16, 16..<20, 20..<32].map { range in
            String(hex[hex.index(hex.startIndex, offsetBy: range.lowerBound)..<hex.index(hex.startIndex, offsetBy: range.upperBound)])
        }

        return UUID(uuidString: parts.joined(separator: "-"))!
    }

    /// 未完了の消耗型取引だけを再送する。完了済みのチャージを再付与する処理ではない。
    private func retryUnfinishedCreditTransactions() async {
        guard isSignedIn else { return }

        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result,
                  transaction.productType == .consumable else { continue }
            _ = await processCreditTransaction(result)
        }
    }

    /// 初回登録と再ログインは同じ API を使い、Apple の sub で新規作成または既存アカウントを特定する。
    /// session を Keychain に保存できてからログイン済みにする。
    func handleAuthorization(_ result: Result<ASAuthorization, Error>, hashedNonce: String) async {
        guard !isManagingAccount else { return }
        isManagingAccount = true
        defer { isManagingAccount = false }

        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            if case .failure(let error) = result,
               (error as? ASAuthorizationError)?.code != .canceled {
                signInError = error.localizedDescription
            }

            return
        }

        do {
            let request = try makeAppleLoginRequest(from: credential, hashedNonce: hashedNonce)

            let response: AppleLoginResponse = try await WorkersAPI.postForResponse(
                "auth/apple_login",
                body: request
            )

            guard AppleSessionKeychain.save(response.sessionToken) else {
                try? await WorkersAPI.post(
                    "user/logout",
                    body: EmptyRequest(),
                    authorizationToken: response.sessionToken
                )
                throw URLError(.cannotWriteToFile)
            }

            sessionToken = response.sessionToken
            setDailyPracticeGoal(response.dailyPracticeGoalMinutes ?? 10)
            userID = response.appleUserID
            setCreditBalance(response.creditBalance)
            credentialState = .authorized
            signInError = nil
            persist()
            await syncAPNsDeviceToken()
            await retryUnfinishedCreditTransactions()
        } catch {
            signInError = error.localizedDescription
            print("Apple login request failed:", error.localizedDescription)
        }
    }

    /// Apple の連携状態とアプリの session を別々に確認する。一時的な通信失敗ではログアウトしない。
    func refreshCredentialState() async {
        guard !isManagingAccount, let userID, let initialSessionToken = sessionToken else { return }

        do {
            let state: ASAuthorizationAppleIDProvider.CredentialState = try await withCheckedThrowingContinuation { continuation in
                ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: state)
                    }
                }
            }

            guard self.userID == userID, self.sessionToken == initialSessionToken, !isManagingAccount else { return }
            if state == .revoked || state == .notFound {
                clearLocalSession()
                return
            }
            credentialState = state
        } catch {
            // 一時的な Apple 側・通信の障害では保存済み session を消さない。
            return
        }

        let sessionToken = initialSessionToken

        do {
            let requestedBalanceRevision = balanceRevision
            let requestedGoalRevision = goalRevision
            let profile: AppleAccountProfile = try await WorkersAPI.get(
                "users",
                authorizationToken: sessionToken
            )

            guard self.sessionToken == sessionToken, !isManagingAccount else { return }
            self.userID = profile.appleUserID
            // 取得中にチャージや消費が完了した場合、古い profile の残高で上書きしない。
            if balanceRevision == requestedBalanceRevision {
                setCreditBalance(profile.creditBalance)
            }
            if goalRevision == requestedGoalRevision && !isSavingDailyPracticeGoal {
                setDailyPracticeGoal(profile.dailyPracticeGoalMinutes ?? 10)
            }
            persist()

            await retryUnfinishedCreditTransactions()
        } catch {
            guard self.sessionToken == sessionToken, !isManagingAccount else { return }
            if let apiError = error as? WorkersAPIError, apiError.statusCode == 401 {
                clearLocalSession()
            }
            signInError = error.localizedDescription
        }
    }

    /// ログアウトは現在の session だけを無効化する。アカウント・残高・Apple との連携は残す。
    func signOut() async {
        guard !isAccountOperationBlocked else { return }
        isManagingAccount = true
        defer { isManagingAccount = false }

        do {
            if let sessionToken {
                try await WorkersAPI.post(
                    "user/logout",
                    body: APNsDeviceTokenRequest(deviceToken: APNsTokenStore.shared.token),
                    authorizationToken: sessionToken
                )
            }
            clearLocalSession()
            signInError = nil
        } catch {
            // 無効化に失敗した場合はログイン状態を保ち、画面だけがログアウト済みになることを防ぐ。
            signInError = error.localizedDescription
        }
    }

    /// サーバーの退会処理が成功してから、端末の認証情報とキャッシュを消す。
    func deleteAccount() async {
        guard !isAccountOperationBlocked else { return }
        guard let sessionToken else {
            signInError = "アカウントを削除するには、Apple でログインしてください。"
            return
        }

        isManagingAccount = true
        defer { isManagingAccount = false }

        do {
            let response: AppleAccountDeletionResponse = try await WorkersAPI.postForResponse(
                "user/delete_account",
                body: EmptyRequest(),
                authorizationToken: sessionToken
            )

            deleteLocalAccountData()
            signInError = nil

            if response.requiresManualAppleRevocation == true {
                accountNotice = "アカウントを削除しました。Apple の連携情報が保存されていなかったため、iPhone の設定から「Apple でサインイン」の本アプリとの連携も解除してください。"
            }
        } catch {
            signInError = error.localizedDescription
        }
    }

    func clearAccountNotice() {
        accountNotice = nil
    }

    func clearSignInError() {
        signInError = nil
    }

    func saveDailyPracticeGoal(_ minutes: Int) async throws {
        guard isSignedIn, let sessionToken else {
            throw WorkersAPIError.httpStatus(401, "Apple でログインしてください。")
        }

        guard (1...480).contains(minutes), !isAccountOperationBlocked else {
            throw WorkersAPIError.httpStatus(400, "目標は 1〜480 分で設定してください。処理中の場合はしばらくお待ちください。")
        }

        isSavingDailyPracticeGoal = true
        defer { isSavingDailyPracticeGoal = false }

        let settings: PracticeGoalSettings = try await WorkersAPI.postForResponse(
            "user/practice_goal",
            body: PracticeGoalSettings(dailyPracticeGoalMinutes: minutes),
            authorizationToken: sessionToken
        )

        guard self.sessionToken == sessionToken else { return }
        setDailyPracticeGoal(settings.dailyPracticeGoalMinutes)
    }

    private func setDailyPracticeGoal(_ minutes: Int) {
        dailyPracticeGoalMinutes = min(480, max(1, minutes))
        goalRevision += 1
    }

    func syncAPNsDeviceToken() async {
        guard isSignedIn, let sessionToken, let token = APNsTokenStore.shared.token else { return }

        do {
            try await WorkersAPI.post(
                "user/apns_device_token",
                body: APNsDeviceTokenRequest(deviceToken: token),
                authorizationToken: sessionToken
            )
        } catch is CancellationError {
            // A changed token starts a new synchronization task.
        } catch {
            print("APNs token の同期に失敗しました:", error.localizedDescription)
        }
    }

    func requestAIExplanation(
        _ question: AIExplanationQuestion,
        onDelta: @MainActor (String) -> Void = { _ in }
    ) async throws -> AIExplanationResponse {
        guard isSignedIn, let sessionToken else {
            throw WorkersAPIError.httpStatus(401, "アカウントタブから Apple でログインしてください。")
        }

        let response = try await WorkersAPI.streamAIExplanation(
            body: AIExplanationRequest(
                question: question.text,
                mode: question.mode,
                request_id: question.id.uuidString,
                parent_request_id: question.parentRequestID?.uuidString,
                language: question.language,
                provider: question.provider
            ),
            authorizationToken: sessionToken,
            onDelta: onDelta
        )
        // 通信中にログアウト・別アカウントへの切り替えが起きた場合、その応答で残高を更新しない。
        if self.sessionToken == sessionToken {
            setCreditBalance(response.creditBalance)
        }

        return response
    }

    func deleteLocalAccountData() {
        clearLocalSession()
        accountCredits = 0
        UserDefaults.standard.removeObject(forKey: "cached_videos")
        UserDefaults.standard.removeObject(forKey: "cached_playlist_categories")
    }

    private func setCreditBalance(_ balance: Int) {
        accountCredits = balance
        balanceRevision += 1
    }

    /// 端末の情報削除だけでは session は無効にならない。通常のログアウトは先に user/logout を呼ぶ。
    private func clearLocalSession() {
        userID = nil
        setDailyPracticeGoal(10)
        setCreditBalance(0)
        sessionToken = nil
        credentialState = .revoked
        AppleSessionKeychain.delete()
        clearPersistedData()
    }

    private func persist() {
        UserDefaults.standard.set(userID, forKey: Keys.userID)
    }

    private func clearPersistedData() {
        UserDefaults.standard.removeObject(forKey: Keys.userID)
    }

    /// 認証のたびに新しい nonce を生成し、Apple の JWT に同じハッシュ値が含まれることを確認する。
    func makeNonce(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

    func hashedNonce(_ nonce: String) -> String {
        SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private struct EmptyRequest: Encodable {}

private struct APNsDeviceTokenRequest: Encodable {
    let deviceToken: String?
}

private enum AppleSessionKeychain {
    private static let account = "apple.account.sessionToken"
    private static var service: String { Bundle.main.bundleIdentifier ?? "JapaneseLearning" }

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }

        return String(data: data, encoding: .utf8)
    }

    /// 既存項目は上書きし、未登録時だけ追加する。保存失敗で元の session まで失わないようにする。
    static func save(_ token: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }

        return SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
