import Foundation

/// Shared wire client for OpenAI-compatible `/chat/completions` + `/models`
/// endpoints on this Mac (LM Studio, Ollama's /v1 shim). Every request URL must
/// pass `LocalEndpoint.isLoopback`, and system proxies are bypassed so a
/// loopback request can't be routed off the machine.
public struct OpenAICompatibleClient: Sendable {
    let baseURL: String
    private let session: URLSession

    public init(baseURL: String) {
        self.baseURL = baseURL
        self.session = URLSession(configuration: .localOnly(timeout: 120))
    }

    /// Build an endpoint URL, refusing anything that isn't loopback.
    func endpoint(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL.trimmingTrailingSlash + path) else {
            throw LLMError.invalidBaseURL(baseURL)
        }
        guard LocalEndpoint.isLoopback(url) else { throw LLMError.nonLocalEndpoint(baseURL) }
        return url
    }

    public func listModels() async throws -> [LLMModel] {
        let url = try endpoint("/models")
        let (data, response) = try await session.data(from: url)
        // Surface the real failure (bad key, wrong endpoint, server error) instead
        // of failing open with [] — an empty list reads as "no models" and hides
        // the misconfiguration.
        guard let http = response as? HTTPURLResponse else { throw LLMError.network("No HTTP response") }
        guard 200..<300 ~= http.statusCode else {
            throw LLMError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        let decoded = try JSONDecoder().decode(ModelList.self, from: data)
        return decoded.data.map { LLMModel(id: $0.id) }
    }

    public func streamChat(messages: [ChatMessage], model: LLMModel, options: ChatOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: try endpoint("/chat/completions"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body = ChatRequest(
                        model: model.id,
                        messages: messages.map { .init(role: $0.role.rawValue, content: $0.content) },
                        stream: true,
                        temperature: options.temperature,
                        max_tokens: options.maxTokens,
                        reasoning_effort: "none"
                    )
                    request.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw LLMError.network("No HTTP response")
                    }
                    guard 200..<300 ~= http.statusCode else {
                        var errorBody = ""
                        for try await line in bytes.lines { errorBody += line }
                        throw LLMError.http(status: http.statusCode, body: errorBody)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8) else { continue }
                        do {
                            let chunk = try JSONDecoder().decode(StreamChunk.self, from: data)
                            if let delta = chunk.choices.first?.delta.content, !delta.isEmpty {
                                continuation.yield(delta)
                            }
                        } catch {
                            // Don't silently drop content: a chunk we can't parse may
                            // carry text. Log it so token loss is diagnosable.
                            Log.llm.debug("Skipped unparseable stream chunk: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Wire types

    private struct ChatRequest: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        let model: String
        let messages: [Message]
        let stream: Bool
        let temperature: Double?
        let max_tokens: Int?
        /// Thinking models (Gemma 4, Qwen) otherwise reason for seconds before
        /// answering, which blows the cleanup timeout. Cleanup and rewrites
        /// don't need it. Servers that don't know the field ignore it.
        let reasoning_effort: String
    }
    private struct StreamChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable { let content: String? }
            let delta: Delta
        }
        let choices: [Choice]
    }
    private struct ModelList: Decodable {
        struct Entry: Decodable { let id: String }
        let data: [Entry]
    }
}

extension URLSessionConfiguration {
    /// An ephemeral (no disk cache, no cookies) configuration that never uses a
    /// system or PAC proxy, for talking to servers on this Mac only.
    static func localOnly(timeout: TimeInterval) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.waitsForConnectivity = false
        config.connectionProxyDictionary = [:]
        return config
    }
}
