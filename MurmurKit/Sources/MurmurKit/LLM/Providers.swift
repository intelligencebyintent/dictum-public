import Foundation

/// A provider backed by a local OpenAI-compatible endpoint (LM Studio, or
/// Ollama's /v1 shim). Models are listed from the live server.
public struct OpenAICompatibleProvider: LLMProvider {
    public let id: LLMProviderID
    private let client: OpenAICompatibleClient

    public init(id: LLMProviderID, baseURL: String) {
        self.id = id
        self.client = OpenAICompatibleClient(baseURL: baseURL)
    }

    public func availableModels() async throws -> [LLMModel] {
        try await client.listModels()
    }

    public func streamChat(messages: [ChatMessage], model: LLMModel, options: ChatOptions) -> AsyncThrowingStream<String, Error> {
        client.streamChat(messages: messages, model: model, options: options)
    }
}
