import Foundation
import FoundationModels

/// Apple's on-device language model (the one behind Apple Intelligence),
/// through the Foundation Models framework. It runs on this Mac, needs no
/// server, and loads only when used.
///
/// Privacy: Dictum uses `SystemLanguageModel` only. The same framework can also
/// send prompts to Apple's Private Cloud Compute or to third-party server
/// models; Dictum never uses either, and `PrivacyTests` fails if the source
/// mentions them.
@available(macOS 26.0, *)
public struct AppleOnDeviceProvider: LLMProvider {
    public let id = LLMProviderID.appleOnDevice

    public init() {}

    /// Permissive guardrails are Apple's setting for transforming the user's
    /// own text, which is what cleanup and rewrites do, so dictated case notes
    /// about crimes or injuries aren't refused.
    private static var model: SystemLanguageModel {
        SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)
    }

    /// Whether Apple Intelligence is on and the model is downloaded.
    public static var isAvailable: Bool { model.isAvailable }

    public func availableModels() async throws -> [LLMModel] {
        let availability = Self.model.availability
        guard case .available = availability else { throw LLMError.unavailable(Self.explain(availability)) }
        return ModelCatalog.chatModels(for: .appleOnDevice)
    }

    /// System messages become the session's instructions and the rest the
    /// prompt. A fresh session per call, so nothing carries over between
    /// dictations. The reply arrives whole (cleanup output is short).
    public func streamChat(messages: [ChatMessage], model _: LLMModel, options: ChatOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let instructions = messages.filter { $0.role == .system }.map(\.content).joined(separator: "\n\n")
                    let prompt = messages.filter { $0.role != .system }.map(\.content).joined(separator: "\n\n")
                    let session = LanguageModelSession(model: Self.model, instructions: instructions)
                    let greedy = options.temperature == 0
                    let generation = GenerationOptions(
                        samplingMode: greedy ? .greedy : nil,
                        temperature: greedy ? nil : options.temperature,
                        maximumResponseTokens: options.maxTokens
                    )
                    let response = try await session.respond(to: prompt, options: generation)
                    continuation.yield(response.content)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func explain(_ availability: SystemLanguageModel.Availability) -> String {
        switch availability {
        case .available:
            "Apple's model is ready."
        case .unavailable(.appleIntelligenceNotEnabled):
            "Turn on Apple Intelligence in System Settings to use Apple's model."
        case .unavailable(.modelNotReady):
            "Apple's model is still downloading. Try again in a few minutes."
        case .unavailable(.deviceNotEligible):
            "This Mac can't run Apple's model."
        case .unavailable:
            "Apple's model isn't available right now."
        }
    }
}
