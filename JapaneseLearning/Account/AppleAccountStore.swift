import AuthenticationServices
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
    private enum Keys {
        static let userID = "apple.account.userID"
        static let wallet = "credits.localWallet.v1"
    }

    private struct WalletState: Codable {
        var balance = 100
        var processedTransactionIDs = Set<UInt64>()
    }

    private static let creditAmountsByProductID: [String: Int] = [
        "com.makoto.languagelearning.webview.credits.100": 100,
        "com.makoto.languagelearning.webview.credits.200": 200,
        "com.makoto.languagelearning.webview.credits.500": 500,
        "com.makoto.languagelearning.webview.credits.1000": 1000
    ]

    private(set) var userID: String?
    private(set) var credentialState: ASAuthorizationAppleIDProvider.CredentialState = .revoked
    private(set) var signInError: String?
    private(set) var isManagingAccount = false

    private(set) var accountCredits: Int
    @ObservationIgnored private var sessionToken: String?
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?

    var isSignedIn: Bool {
        userID != nil && sessionToken != nil && credentialState != .revoked && credentialState != .notFound
    }

    init() {
        let walletData = UserDefaults.standard.data(forKey: Keys.wallet)
        let wallet = walletData.flatMap { try? JSONDecoder().decode(WalletState.self, from: $0) }
        accountCredits = wallet?.balance ?? 100

        userID = UserDefaults.standard.string(forKey: Keys.userID)
        sessionToken = AppleSessionKeychain.read()
        if userID != nil, sessionToken != nil {
            credentialState = .authorized
        } else if userID == nil {
            AppleSessionKeychain.delete()
            sessionToken = nil
        }

        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                let outcome = await self.processCreditTransaction(result)
                if case .failed(let message) = outcome {
                    print("Credit transaction update failed: \(message)")
                }
            }
        }
    }

    private struct AppleLoginRequest: Encodable {
        let identityToken: String
        let authorizationCode: String
        let hashedNonce: String
    }

    private struct AppleLoginResponse: Decodable {
        let appleUserID: String
        let creditBalance: Int
        let sessionToken: String
    }

    private struct AppleAccountProfile: Decodable {
        let appleUserID: String
        let creditBalance: Int
    }

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

    static var creditProductIDs: [String] {
        creditAmountsByProductID.keys.sorted()
    }

    static func productID(for credits: Int) -> String? {
        creditAmountsByProductID.first(where: { $0.value == credits })?.key
    }

    func credits(for productID: String) -> Int? {
        Self.creditAmountsByProductID[productID]
    }

    func purchaseCredits(_ product: Product) async -> CreditPurchaseOutcome {
        guard credits(for: product.id) != nil, product.type == .consumable else {
            return .failed("選択した商品を確認できませんでした。")
        }

        do {
            switch try await product.purchase() {
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

    private func processCreditTransaction(
        _ verificationResult: VerificationResult<Transaction>
    ) async -> CreditPurchaseOutcome {
        guard case .verified(let transaction) = verificationResult else {
            return .failed("Appleによる購入の検証に失敗しました。")
        }

        guard let amount = credits(for: transaction.productID),
              transaction.productType == .consumable else {
            return .failed("購入商品がクレジット商品と一致しません。")
        }

        var wallet = UserDefaults.standard.data(forKey: Keys.wallet)
            .flatMap { try? JSONDecoder().decode(WalletState.self, from: $0) }
            ?? WalletState()

        let wasAlreadyApplied = wallet.processedTransactionIDs.contains(transaction.id)
        if !wasAlreadyApplied {
            wallet.processedTransactionIDs.insert(transaction.id)
            wallet.balance += amount

            do {
                let data = try JSONEncoder().encode(wallet)
                UserDefaults.standard.set(data, forKey: Keys.wallet)
            } catch {
                return .failed("購入情報を端末に保存できませんでした。")
            }

            accountCredits = wallet.balance
        }

        await transaction.finish()
        return .purchased(added: wasAlreadyApplied ? 0 : amount, balance: wallet.balance)
    }

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
                    "auth/logout",
                    body: EmptyRequest(),
                    authorizationToken: response.sessionToken
                )
                throw URLError(.cannotWriteToFile)
            }

            sessionToken = response.sessionToken
            userID = response.appleUserID
            accountCredits = response.creditBalance
            credentialState = .authorized
            signInError = nil
            persist()
        } catch {
            signInError = error.localizedDescription
            print("Apple login request failed:", error.localizedDescription)
        }
    }

    func refreshCredentialState() async {
        guard !isManagingAccount, let userID else { return }

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
            guard self.userID == userID, !isManagingAccount else { return }
            if state == .revoked || state == .notFound {
                clearLocalSession()
                return
            }
            credentialState = state
        } catch {
            // A temporary Apple/network failure must not erase the saved session.
            return
        }

        guard let sessionToken else { return }

        do {
            let profile: AppleAccountProfile = try await WorkersAPI.get(
                "users",
                authorizationToken: sessionToken
            )
            guard self.sessionToken == sessionToken, !isManagingAccount else { return }
            self.userID = profile.appleUserID
            accountCredits = profile.creditBalance
            persist()
        } catch {
            guard self.sessionToken == sessionToken, !isManagingAccount else { return }
            if let apiError = error as? WorkersAPIError, apiError.statusCode == 401 {
                clearLocalSession()
            }
            signInError = error.localizedDescription
        }
    }

    func signOut() async {
        guard !isManagingAccount else { return }
        isManagingAccount = true
        defer { isManagingAccount = false }
        if let sessionToken {
            try? await WorkersAPI.post(
                "auth/logout",
                body: EmptyRequest(),
                authorizationToken: sessionToken
            )
        }
        clearLocalSession()
    }

    func deleteAccount() async {
        guard !isManagingAccount else { return }
        guard let sessionToken else {
            signInError = "アカウントを削除するには、Apple でログインしてください。"
            return
        }

        isManagingAccount = true
        defer { isManagingAccount = false }

        do {
            try await WorkersAPI.post(
                "auth/delete_account",
                body: EmptyRequest(),
                authorizationToken: sessionToken
            )
            deleteLocalAccountData()
            signInError = nil
        } catch {
            signInError = error.localizedDescription
        }
    }

    func clearSignInError() {
        signInError = nil
    }

    func requestAIExplanation(_ question: AIExplanationQuestion) async throws -> AIExplanationResponse {
        guard isSignedIn, let sessionToken else {
            throw WorkersAPIError.httpStatus(401, "アカウントタブから Apple でログインしてください。")
        }
        let response: AIExplanationResponse = try await WorkersAPI.postForResponse(
            "request_ai_question",
            body: AIExplanationRequest(question: question.text, mode: question.mode, request_id: question.id.uuidString),
            authorizationToken: sessionToken
        )
        // Do not apply a response to an account that signed out during the request.
        if self.sessionToken == sessionToken {
            accountCredits = response.creditBalance
        }
        return response
    }

    func deleteLocalAccountData() {
        clearLocalSession()
        UserDefaults.standard.removeObject(forKey: Keys.wallet)
        accountCredits = 100
        UserDefaults.standard.removeObject(forKey: "cached_videos")
        UserDefaults.standard.removeObject(forKey: "cached_playlist_categories")
    }

    private func clearLocalSession() {
        userID = nil
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
}

private struct EmptyRequest: Encodable {}

private enum AppleSessionKeychain {
    private static let account = "apple.account.sessionToken"
    private static var service: String { Bundle.main.bundleIdentifier ?? "JapaneseLearning" }

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ token: String) -> Bool {
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
