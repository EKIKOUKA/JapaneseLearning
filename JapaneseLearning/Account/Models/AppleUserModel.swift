//
//  AppleUserModel.swift
//  JapaneseLearning
//
//  Created by Makoto on 2026/10/15.
//

import Foundation

// 商品一覧の管理元は Worker の DB。Apple の購入価格表示は StoreKit に任せる。
struct CreditProduct: Decodable, Identifiable {
    let id: String
    let credits: Int
    let appStoreProductID: String
    let stripeAmount: Int
    let stripeCurrency: String
}

struct CreditProductCatalog: Decodable {
    let products: [CreditProduct]
}

struct AppleLoginRequest: Encodable {
    let identityToken: String
    let authorizationCode: String
    let hashedNonce: String
}

struct AppleLoginResponse: Decodable {
    let appleUserID: String
    let creditBalance: Int
    let sessionToken: String
    let dailyPracticeGoalMinutes: Int?
}

struct AppleAccountProfile: Decodable {
    let appleUserID: String
    let creditBalance: Int
    let dailyPracticeGoalMinutes: Int?
}

struct PracticeGoalSettings: Codable {
    let dailyPracticeGoalMinutes: Int
}

struct AppleAccountDeletionResponse: Decodable {
    let requiresManualAppleRevocation: Bool
}


struct CreditChargeRequest: Encodable {
    let signedTransaction: String
}

struct CreditChargeResponse: Decodable {
    let addedCredits: Int
    let creditBalance: Int
}


// Stripe
struct StripeTestConfiguration: Decodable {
    struct Option: Decodable {
        let credits: Int
        let amount: Int
    }
    let publishableKey: String
    let merchantID: String
    let country: String
    let currency: String
    let options: [Option]
}

struct StripeTestCreateRequest: Encodable {
    let credits: Int
    let requestID: String
}

struct StripeTestIntent: Decodable {
    let clientSecret: String
}


struct CreditUsageRecord: Codable, Identifiable {
    let id: Int
    let videoTitle: String
    let mode: String
    let creditsUsed: Int
    let balanceAfter: Int
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case videoTitle = "video_title"
        case mode
        case creditsUsed = "credits_used"
        case balanceAfter = "balance_after"
        case createdAt = "created_at"
    }
}

struct CreditChargeRecord: Codable, Identifiable {
    let id: String
    let provider: String
    let credits: Int
    let amount: Int?
    let currency: String?
    let environment: String
    let chargeTrigger: String
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case provider
        case credits
        case amount
        case currency
        case environment
        case chargeTrigger = "charge_trigger"
        case createdAt = "created_at"
    }
}
