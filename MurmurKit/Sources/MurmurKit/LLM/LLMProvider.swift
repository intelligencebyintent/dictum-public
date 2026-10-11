import Foundation

// MARK: - Identity

/// Every chat/completion backend Dictum can use for "Polish" and Command Mode.
/// All run on this Mac; there are no cloud providers in this build.
public enum LLMProviderID: String, Codable, CaseIterable, Sendable, Identifiable {
    case appleOnDevice   // Apple's on-device model (Foundation Models), no server
    case lmStudio        // local OpenAI-compatible server (:1234)
    case ollama          // local (:11434, native + /v1 shim)

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .appleOnDevice: "Apple on-device model"
        case .lmStudio: "LM Studio (local)"
        case .ollama: "Ollama (local)"
        }
    }

    /// Whether the provider is a server reached over a URL. Apple's model is
    /// called in-process through the Foundation Models framework.
    public var usesServer: Bool { self != .appleOnDevice }

    /// Every provider runs on this Mac. Kept so callers can show "local" in the UI.
    public var isLocal: Bool { true }

    /// Default endpoint base URL (overridable in Settings, loopback only). An
    /// explicit 127.0.0.1 rather than `localhost`, so nothing depends on name
    /// resolution and the Network Guard sees exactly 127.0.0.1.
    public var defaultBaseURL: String {
        switch self {
        case .appleOnDevice: ""
        case .lmStudio: "http://127.0.0.1:1234/v1"
        case .ollama: "http://127.0.0.1:11434/v1"
        }
    }
}

// MARK: - Messages + models

public struct LLMModel: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let displayName: String
    public let contextLength: Int?

    public init(id: String, displayName: String? = nil, contextLength: Int? = nil) {
        self.id = id
        self.displayName = displayName ?? id
        self.contextLength = contextLength
    }
}

public struct ChatMessage: Codable, Sendable, Hashable {
    public enum Role: String, Codable, Sendable { case system, user, assistant }
    public var role: Role
    public var content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }

    public static func system(_ content: String) -> ChatMessage { .init(role: .system, content: content) }
    public static func user(_ content: String) -> ChatMessage { .init(role: .user, content: content) }
    public static func assistant(_ content: String) -> ChatMessage { .init(role: .assistant, content: content) }
}

public struct ChatOptions: Sendable {
    public var temperature: Double?
    public var maxTokens: Int?

    public init(temperature: Double? = 0.2, maxTokens: Int? = nil) {
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

// MARK: - Errors

public enum LLMError: LocalizedError {
    case nonLocalEndpoint(String)
    case invalidBaseURL(String)
    case http(status: Int, body: String)
    case network(String)
    case decoding(String)
    case noModelSelected
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .nonLocalEndpoint(let s): "Refused \(s): Dictum only connects to servers on this Mac (127.0.0.1 or localhost)."
        case .invalidBaseURL(let s): "Invalid server URL: \(s)"
        case .http(let status, let body): "LLM request failed (HTTP \(status)). \(HTTPBody.summarize(body))"
        case .network(let message): "Network error: \(message)"
        case .decoding(let message): "Couldn't read the LLM response: \(message)"
        case .noModelSelected: "No model selected for the AI cleanup provider."
        case .unavailable(let reason): reason
        }
    }
}

// MARK: - Protocol

/// A chat-completion backend on this Mac, spoken to over the OpenAI wire format
/// via `OpenAICompatibleClient`.
public protocol LLMProvider: Sendable {
    var id: LLMProviderID { get }
    var isLocal: Bool { get }

    /// Query the running local server for its models.
    func availableModels() async throws -> [LLMModel]

    /// Stream the assistant's reply as incremental text chunks.
    func streamChat(messages: [ChatMessage], model: LLMModel, options: ChatOptions) -> AsyncThrowingStream<String, Error>
}

public extension LLMProvider {
    var isLocal: Bool { id.isLocal }

    /// Convenience: collect a streamed reply into a single string.
    func chat(messages: [ChatMessage], model: LLMModel, options: ChatOptions = ChatOptions()) async throws -> String {
        var result = ""
        for try await chunk in streamChat(messages: messages, model: model, options: options) {
            result += chunk
        }
        return result
    }
}
