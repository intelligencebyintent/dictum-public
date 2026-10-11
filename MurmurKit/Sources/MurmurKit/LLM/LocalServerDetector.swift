import Foundation

/// A local LLM server discovered on the machine, with its live model list.
public struct DetectedServer: Sendable, Identifiable {
    public let provider: LLMProviderID
    public let baseURL: String
    public let models: [LLMModel]
    public var id: LLMProviderID { provider }
}

/// Probes localhost for running LM Studio / Ollama servers and fetches their
/// model lists, so the UI can offer local LLMs without manual configuration.
public actor LocalServerDetector {
    private let session: URLSession

    public init() {
        self.session = URLSession(configuration: .localOnly(timeout: 1.2))
    }

    /// Probe both known local providers. Unreachable servers are simply omitted.
    public func probe(lmStudioBaseURL: String, ollamaBaseURL: String) async -> [DetectedServer] {
        async let lmStudio = probeOpenAICompatible(.lmStudio, baseURL: lmStudioBaseURL)
        async let ollama = probeOllama(baseURL: ollamaBaseURL)
        return await [lmStudio, ollama].compactMap { $0 }
    }

    // MARK: OpenAI-compatible (LM Studio, Ollama /v1 shim)

    private func probeOpenAICompatible(_ provider: LLMProviderID, baseURL: String) async -> DetectedServer? {
        guard let url = URL(string: baseURL.trimmingTrailingSlash + "/models"), LocalEndpoint.isLoopback(url) else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(OpenAIModelList.self, from: data)
            let models = decoded.data.map { LLMModel(id: $0.id) }
            guard !models.isEmpty else { return nil }
            return DetectedServer(provider: provider, baseURL: baseURL, models: models)
        } catch {
            return nil
        }
    }

    // MARK: Ollama native (/api/tags)

    private func probeOllama(baseURL: String) async -> DetectedServer? {
        // baseURL is the OpenAI shim (…/v1); native tags live at the root host.
        guard let shim = URL(string: baseURL), let host = shim.host else { return nil }
        var components = URLComponents()
        components.scheme = shim.scheme
        components.host = host
        components.port = shim.port
        components.path = "/api/tags"
        guard let url = components.url, LocalEndpoint.isLoopback(url) else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(OllamaTagList.self, from: data)
            let models = decoded.models.map { LLMModel(id: $0.name) }
            guard !models.isEmpty else { return nil }
            return DetectedServer(provider: .ollama, baseURL: baseURL, models: models)
        } catch {
            return nil
        }
    }

    // MARK: Wire types

    private struct OpenAIModelList: Decodable {
        struct Entry: Decodable { let id: String }
        let data: [Entry]
    }
    private struct OllamaTagList: Decodable {
        struct Entry: Decodable { let name: String }
        let models: [Entry]
    }
}

extension String {
    var trimmingTrailingSlash: String {
        hasSuffix("/") ? String(dropLast()) : self
    }
}
