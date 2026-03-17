//
//  WorkersAPI.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/02/28.
//

import Foundation

enum WorkersAPI {
    private static let baseURL = Config.CloudflareWorkersURL

    // MARK: - GET
    static func get<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: "\(baseURL)/\(path)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - POST (Encodable Body)
    static func post<T: Encodable>(
        _ path: String,
        body: T
    ) async throws {
        let url = URL(string: "\(baseURL)/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response)
    }

    // MARK: - POST (Raw Data)
    static func postRaw(
        _ path: String,
        body: [String: Int]
    ) async throws {
        let url = URL(string: "\(baseURL)/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: body
        )

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response)
    }

    // MARK: - DELETE
    static func delete(_ path: String) async throws {
        let url = URL(string: "\(baseURL)/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response)
    }

    // MARK: - Response Validation
    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= http.statusCode else {
            print("❌ HTTP Error Code: \(http.statusCode)")
            throw URLError(.badServerResponse)
        }
    }
}
