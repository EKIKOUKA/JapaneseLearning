//
//  AppleUserModel.swift
//  JapaneseLearning
//
//  Created by Makoto on 2026/10/15.
//

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
}

struct AppleAccountProfile: Decodable {
    let appleUserID: String
    let creditBalance: Int
}

struct AppleAccountDeletionResponse: Decodable {
    // 旧サーバーとの互換性を保つため、省略されている場合も読み込めるようにする。
    let requiresManualAppleRevocation: Bool?
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
