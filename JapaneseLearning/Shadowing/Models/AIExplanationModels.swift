//
//  AIExplanationModels.swift
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
    var parentRequestID: UUID? = nil
    var language: String? = nil
}

struct AIExplanationRequest: Encodable {
    let question: String
    let mode: AIExplanationMode
    let request_id: String
    var parent_request_id: String? = nil
    var language: String? = nil
}

struct AIExplanationTurn: Identifiable {
    var id: UUID { question.id }
    var question: AIExplanationQuestion
    var response: AIExplanationResponse?
    var streamingText = ""
    var errorMessage: String?
}

struct AIExplanationResponse: Decodable {
    let answer: String
    let creditBalance: Int
    let inputTokens: Int?
    let outputTokens: Int?
    let truncated: Bool
}

struct AIExplanationStreamEvent: Decodable {
    let type: String
    let delta: String?
    let response: AIExplanationResponse?
    let error: String?
}
