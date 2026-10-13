//
//  AIExplanation.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/10/13.
//

import Foundation

enum AIExplanationMode: String, Encodable {
    case word, sentence
}

struct AIExplanationQuestion: Identifiable {
    let id = UUID()
    let text: String
    let mode: AIExplanationMode
}

struct AIExplanationRequest: Encodable {
    let question: String
    let mode: AIExplanationMode
    let request_id: String
}

struct AIExplanationResponse: Decodable {
    let answer: String
    let creditBalance: Int
    let inputTokens: Int?
    let outputTokens: Int?
    let truncated: Bool
}
