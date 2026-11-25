//
//  WorkersAPI.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/02/28.
//

import UIKit

enum WorkersAPI {
    /// バックグラウンド同期や定期更新では、このタスク内のエラー表示を抑制できる。
    @TaskLocal static var reportsErrors = true

    /// 通信エラーを共通の方法で表示し、呼び出し元にも返す。キャンセルは表示しない。
    @MainActor
    private static func reporting<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            if reportsErrors && !Task.isCancelled && !(error is CancellationError)
                && (error as? URLError)?.code != .cancelled {
                presentError(error)
            }
            throw error
        }
    }

    /// 表示中のシートもたどり、最前面の画面にエラーを表示する。
    @MainActor
    private static func presentError(_ error: Error) {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap { $0.windows }

        guard var presenter = windows.first(where: \.isKeyWindow)?.rootViewController else { return }
        while let presented = presenter.presentedViewController, !presented.isBeingDismissed {
            presenter = presented
        }
        guard !(presenter is UIAlertController) else { return }

        let apiError = error as? WorkersAPIError
        let title = apiError?.statusCode == 402 ? "クレジット残高が不足しています" : "エラー"
        let message = apiError?.errorDescription ?? "通信に失敗しました。しばらくしてからもう一度お試しください。"

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }

    private static let baseURL = URL(string: "https://japanese-learning.makoto.lol/shadowing")!

    @MainActor
    static func streamAIExplanation(
        body: AIExplanationRequest,
        authorizationToken: String,
        onDelta: @MainActor (String) -> Void
    ) async throws -> AIExplanationResponse {
        return try await reporting {
            var request = URLRequest(url: baseURL.appending(path: "request_ai_question"))
                .setMethod("POST")
                .setJSONBody(body)
            request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 90

            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            let http = response as? HTTPURLResponse

            guard let http, http.statusIsSuccessful,
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
    }

    /// 明示されたトークンを優先し、認証が必要な場合は保存済みのセッションを使う。
    private static func authorize(_ request: inout URLRequest, token: String?, required: Bool) async throws {
        #if DEBUG
        request.setValue("sandbox", forHTTPHeaderField: "X-APNs-Environment")
        #else
        request.setValue("production", forHTTPHeaderField: "X-APNs-Environment")
        #endif
        let resolvedToken: String?

        if let token {
            resolvedToken = token
        } else if required {
            resolvedToken = await MainActor.run {
                AppleAccountStore.savedSessionToken
            }
        } else {
            resolvedToken = nil
        }

        if required && (resolvedToken?.isEmpty ?? true) {
            throw WorkersAPIError.httpStatus(401, "Apple でログインしてください。")
        }

        if let resolvedToken {
            request.setValue("Bearer \(resolvedToken)", forHTTPHeaderField: "Authorization")
        }
    }

    // MARK: - GET
    static func get<T: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem]? = nil,
        authorizationToken: String? = nil,
        requiresAuthentication: Bool = false
    ) async throws -> T {
        return try await reporting {
            var url = baseURL.appending(path: path)
            if let queryItems {
                url = url.appending(queryItems: queryItems)
            }

            var request = URLRequest(url: url)
            try await authorize(&request, token: authorizationToken, required: requiresAuthentication)
            let (data, response) = try await URLSession.shared.data(for: request)
            try response.validateHTTPStatus(data)

            return try JSONDecoder().decode(T.self, from: data)
        }
    }

    // MARK: - POST (Encodable Body)
    static func post<T: Encodable>(
        _ path: String,
        body: T,
        authorizationToken: String? = nil,
        requiresAuthentication: Bool = false
    ) async throws {
        try await reporting {
            let url = baseURL.appending(path: path)

            var request = URLRequest(url: url)
                .setMethod("POST")
                .setJSONBody(body)
            try await authorize(&request, token: authorizationToken, required: requiresAuthentication)

            let (data, response) = try await URLSession.shared.data(for: request)

            try response.validateHTTPStatus(data)
        }
    }

    static func postForResponse<Response: Decodable, Body: Encodable>(
        _ path: String,
        body: Body,
        authorizationToken: String? = nil,
        requiresAuthentication: Bool = false
    ) async throws -> Response {
        return try await reporting {
            let url = baseURL.appending(path: path)
            var request = URLRequest(url: url)
                .setMethod("POST")
                .setJSONBody(body)
            try await authorize(&request, token: authorizationToken, required: requiresAuthentication)

            let (data, response) = try await URLSession.shared.data(for: request)
            try response.validateHTTPStatus(data)

            return try JSONDecoder().decode(Response.self, from: data)
        }
    }

    // MARK: - POST (Raw Data)
    static func postRaw(
        _ path: String,
        body: [String: Int],
        authorizationToken: String? = nil,
        requiresAuthentication: Bool = false
    ) async throws {
        try await reporting {
            let url = baseURL.appending(path: path)

            var request = URLRequest(url: url)
                .setMethod("POST")
                .setRawJSONBody(body)
            try await authorize(&request, token: authorizationToken, required: requiresAuthentication)

            let (data, response) = try await URLSession.shared.data(for: request)

            try response.validateHTTPStatus(data)
        }
    }

    /// 外部の字幕 JSON を取得する。Worker 用の認証トークンは送信しない。
    static func getExternalJSON<T: Decodable>(from url: URL, failureMessage: String) async throws -> T {
        try await reporting {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                guard http.statusIsSuccessful else {
                    throw WorkersAPIError.httpStatus(http.statusCode, failureMessage)
                }

                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                    throw error
                }

                if let error = error as? WorkersAPIError { throw error }
                throw WorkersAPIError.httpStatus(0, failureMessage)
            }
        }
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

private extension HTTPURLResponse {
    var statusIsSuccessful: Bool { (200...299).contains(statusCode) }
}

extension URLResponse {
    /// Worker が返す利用者向けメッセージを HTTP エラーに引き継ぐ。
    func validateHTTPStatus(_ data: Data) throws {
        guard let httpResponse = self as? HTTPURLResponse else {
            print("❌ HTTP Request is Not")
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusIsSuccessful else {
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
            case .httpStatus(_, let message): return message ?? "サーバーとの通信に失敗しました。"
        }
    }
}
