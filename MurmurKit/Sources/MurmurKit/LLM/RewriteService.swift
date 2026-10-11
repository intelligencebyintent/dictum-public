import Foundation

/// Applies an instruction to selected text (Transforms) or answers/generates
/// from a spoken instruction (Command Mode). Outputs only the resulting text.
public struct RewriteService: Sendable {
    public init() {}

    public func rewrite(
        instruction: String,
        selection: String?,
        provider: any LLMProvider,
        model: LLMModel
    ) async throws -> String {
        let system = """
        You are a text-editing engine. Apply the user's instruction and output \
        ONLY the resulting text — no preamble, quotes, or explanation. Preserve \
        the original language unless told to translate.
        """

        let user: String
        if let selection, !selection.isEmpty {
            user = "Instruction: \(instruction)\n\nApply it to the following text and return only the result:\n\n\(selection)"
        } else {
            user = instruction
        }

        let output = try await provider.chat(
            messages: [.system(system), .user(user)],
            model: model,
            options: ChatOptions(temperature: 0.3)
        )
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
