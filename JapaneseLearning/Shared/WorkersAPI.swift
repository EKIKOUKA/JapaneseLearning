//
//  WorkersAPI.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/02/28.
//

import Foundation

enum WorkersAPI {
    private static let baseURL = URL(string: Config.CloudflareWorkersURL)!

    @MainActor
    static func streamAIExplanation(
        body: AIExplanationRequest,
        authorizationToken: String,
        onDelta: @MainActor (String) -> Void
    ) async throws -> AIExplanationResponse {
        var request = URLRequest(url: baseURL.appending(path: "request_ai_question"))
            .setMethod("POST")
            .setJSONBody(body)
        request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 90

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let http = response as? HTTPURLResponse

        guard let http, (200...299).contains(http.statusCode),
              http.value(forHTTPHeaderField: "Content-Type")?.contains("text/event-stream") == true else {
            // Completed requests replay as JSON; pre-stream validation errors are JSON too.
            var data = Data()
            for try await byte in bytes {
                guard data.count < 1_048_576 else { throw URLError(.dataLengthExceedsMaximum) }
                data.append(byte)
            }
            try response.validateHTTPStatus(data)

            return try JSONDecoder().decode(AIExplanationResponse.self, from: data)
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: ") else { continue }
            let event = try JSONDecoder().decode(AIExplanationStreamEvent.self, from: Data(line.dropFirst(6).utf8))

            switch event.type {
                case "delta":
                    if let delta = event.delta { onDelta(delta) }
                case "done":
                    guard let result = event.response else { throw URLError(.cannotParseResponse) }
                    return result
                case "error":
                    throw WorkersAPIError.httpStatus(502, event.error)
                default:
                    break
            }
        }

        throw WorkersAPIError.httpStatus(502, "通信が中断されました。同じリクエストで再確認してください。")
    }

    // MARK: - GET
    static func get<T: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem]? = nil,
        authorizationToken: String? = nil
    ) async throws -> T {
        var url = baseURL.appending(path: path)
        if let queryItems {
            url = url.appending(queryItems: queryItems)
        }

        var request = URLRequest(url: url)
        if let authorizationToken {
            request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try response.validateHTTPStatus(data)

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - POST (Encodable Body)
    static func post<T: Encodable>(
        _ path: String,
        body: T,
        authorizationToken: String? = nil
    ) async throws {
        let url = baseURL.appending(path: path)

        var request = URLRequest(url: url)
            .setMethod("POST")
            .setJSONBody(body)
        if let authorizationToken {
            request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        try response.validateHTTPStatus(data)
    }

    static func postForResponse<Response: Decodable, Body: Encodable>(
        _ path: String,
        body: Body,
        authorizationToken: String? = nil
    ) async throws -> Response {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
            .setMethod("POST")
            .setJSONBody(body)
        if let authorizationToken {
            request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try response.validateHTTPStatus(data)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    // MARK: - POST (Raw Data)
    static func postRaw(_ path: String, body: [String: Int]) async throws {
        let url = baseURL.appending(path: path)

        let request = URLRequest(url: url)
            .setMethod("POST")
            .setRawJSONBody(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        try response.validateHTTPStatus(data)
    }

    // MARK: - GET (Raw Data)
    static func getData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        try response.validateHTTPStatus(data)

        guard !data.isEmpty else {
            throw URLError(.zeroByteResource)
        }

        return data
    }
}

extension URLRequest {
    func setMethod(_ method: String) -> URLRequest {
        var request = self
        request.httpMethod = method

        return request
    }

    func setJSONBody<T: Encodable>(_ body: T) -> URLRequest {
        var request = self
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)

        return request
    }

    func setRawJSONBody(_ body: [String: Any]) -> URLRequest {
        var request = self
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        return request
    }
}

extension URLResponse {
    func validateHTTPStatus(_ data: Data) throws {
        guard let httpResponse = self as? HTTPURLResponse else {
            print("❌ HTTP Request is Not")
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Cloudflare Workers HTTP Error Code: \(httpResponse.statusCode)")
            let message = (try? JSONDecoder().decode(WorkersAPIErrorBody.self, from: data).error)
            throw WorkersAPIError.httpStatus(httpResponse.statusCode, message)
        }
    }
}

private struct WorkersAPIErrorBody: Decodable {
    let error: String?
}

enum WorkersAPIError: LocalizedError {
    case httpStatus(Int, String?)

    var statusCode: Int {
        switch self {
        case .httpStatus(let status, _): return status
        }
    }

    var errorDescription: String? {
        switch self {
        case .httpStatus(_, let message):
            return message ?? "サーバーとの通信に失敗しました。"
        }
    }
}
