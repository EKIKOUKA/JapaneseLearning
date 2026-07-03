//
//  WorkersAPI.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/02/28.
//

import Foundation

enum WorkersAPI {
    private static let baseURL = URL(string: Config.CloudflareWorkersURL)!

    // MARK: - GET
    static func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        var url = baseURL.appending(path: path)
        if let queryItems {
            url = url.appending(queryItems: queryItems)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        try response.validateHTTPStatus()

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - POST (Encodable Body)
    static func post<T: Encodable>(_ path: String, body: T) async throws {
        let url = baseURL.appending(path: path)

        let request = URLRequest(url: url)
            .setMethod("POST")
            .setJSONBody(body)

        let (_, response) = try await URLSession.shared.data(for: request)

        try response.validateHTTPStatus()
    }

    // MARK: - POST (Raw Data)
    static func postRaw(_ path: String, body: [String: Int]) async throws {
        let url = baseURL.appending(path: path)

        let request = URLRequest(url: url)
            .setMethod("POST")
            .setRawJSONBody(body)

        let (_, response) = try await URLSession.shared.data(for: request)

        try response.validateHTTPStatus()
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
    func validateHTTPStatus() throws {
        guard let httpResponse = self as? HTTPURLResponse else {
            print("❌ HTTP Request is Not")
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Cloudflare Workers HTTP Error Code: \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }
    }
}
