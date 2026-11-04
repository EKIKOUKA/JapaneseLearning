//
//  AutomaticChargeModels.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/11/02.
//
import Foundation

struct AutomaticChargeSetting: Decodable, Identifiable {
    let id: String
    let type: String
    let status: String
    let amount: Int
    let billingDay: Int?
    let nextChargeAt: String?
    let thresholdCredits: Int?
    let monthlyLimitAmount: Int?
    let lastError: String?

    var statusText: String {
        switch status {
            case "active": "有効"
            case "pending_authorization": "承認待ち"
            case "requires_authorization": "再承認が必要"
            default: "停止中"
        }
    }
}
struct AutomaticChargeSettingsResponse: Decodable {
    let settings: [AutomaticChargeSetting]
    let creditBalance: Int?
}
struct AutomaticChargeRequest: Encodable {
    let type: String
    let amount: Int
    let billingDay: Int?
    let thresholdCredits: Int?
    let monthlyLimitAmount: Int?
    let requestID: String
}
struct AutomaticChargeAuthorization: Decodable {
    let clientSecret: String
    let authorizationID: String
    let setting: AutomaticChargeSetting
    let managementURL: URL
    let thresholdAmount: Int?
}

