import AuthenticationServices
import Foundation
import Observation
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
        "com.makoto.languagelearning.webview.credits.1000": 1000,
        "com.makoto.languagelearning.webview.credits.8964": 8964
    ]

    private(set) var userID: String?
    private(set) var credentialState: ASAuthorizationAppleIDProvider.CredentialState = .revoked

    private(set) var accountCredits: Int
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?

    var isSignedIn: Bool {
        userID != nil && credentialState != .revoked && credentialState != .notFound
    }

    init() {
        let walletData = UserDefaults.standard.data(forKey: Keys.wallet)
        let wallet = walletData.flatMap { try? JSONDecoder().decode(WalletState.self, from: $0) }
        accountCredits = wallet?.balance ?? 100

        userID = UserDefaults.standard.string(forKey: Keys.userID)

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

    func handleAuthorization(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }

        userID = credential.user
        credentialState = .authorized
        persist()
    }

    func refreshCredentialState() async {
        guard let userID else { return }

        credentialState = await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }

    func signOut() {
        userID = nil
        credentialState = .revoked
        clearPersistedData()
    }

    func deleteLocalAccountData() {
        signOut()
        UserDefaults.standard.removeObject(forKey: "cached_videos")
        UserDefaults.standard.removeObject(forKey: "cached_playlist_categories")
    }

    private func persist() {
        UserDefaults.standard.set(userID, forKey: Keys.userID)
    }

    private func clearPersistedData() {
        UserDefaults.standard.removeObject(forKey: Keys.userID)
    }
}
