import Foundation
import Testing
@testable import MurmurKit

/// A stand-in model that answers after `delay`.
private struct DelayedProvider: LLMProvider {
    let id = LLMProviderID.lmStudio
    let delay: Duration

    func availableModels() async throws -> [LLMModel] { [] }

    func streamChat(messages: [ChatMessage], model: LLMModel, options: ChatOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                try? await Task.sleep(for: delay)
                continuation.yield("Cleaned.")
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

struct PolishServiceTests {
    /// A cleanup slower than the timeout gives up, so the raw transcript
    /// goes in instead of the dictation waiting on a model that's still loading.
    @Test func slowModelTimesOut() async {
        let clock = ContinuousClock()
        let start = clock.now
        await #expect(throws: PolishError.self) {
            try await PolishService().polish(raw: "um hello", context: PolishContext(),
                                             provider: DelayedProvider(delay: .seconds(10)),
                                             model: LLMModel(id: "x"), timeout: .milliseconds(100))
        }
        #expect(clock.now - start < .seconds(2))
    }

    /// The app must send exactly the prompt the bakeoff tested.
    @Test func promptMatchesTheBakeoffPrompt() throws {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let file = try String(contentsOf: repo.appendingPathComponent("tools/cleanup-bakeoff/system-prompt-v3.txt"), encoding: .utf8)
        let style = try #require(PolishService.style(bundleID: "com.apple.mail"))
        let tested = file.replacingOccurrences(of: "{{STYLE}}", with: style)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let terms = ["voir dire", "res judicata", "pendente lite", "QDRO", "MSA",
                     "Claude", "Claude Code", "Opus", "Cowork", "ChatGPT"]
        let sent = PolishService.systemPrompt(context: PolishContext(frontmostBundleID: "com.apple.mail", dictionaryTerms: terms))
        #expect(sent == tested)
    }

    @Test func appStylesFollowTheSpecTable() {
        #expect(PolishService.style(bundleID: "com.microsoft.Outlook")?.hasPrefix("Style: email") == true)
        #expect(PolishService.style(bundleID: "com.microsoft.Word")?.hasPrefix("Style: document") == true)
        #expect(PolishService.style(bundleID: "com.tinyspeck.slackmacgap")?.hasPrefix("Style: casual") == true)
        #expect(PolishService.style(bundleID: "com.anthropic.claudefordesktop")?.hasPrefix("Style: a prompt") == true)
        #expect(PolishService.style(bundleID: "com.apple.Notes") == nil)
    }

    @Test func tidyDropsTagsAndTrailingSpaces() {
        #expect(PolishService.tidy("<transcript>\nHi Jennifer,  \n\nThanks.  \n</transcript>") == "Hi Jennifer,\n\nThanks.")
    }

    @Test func capitalizesTheFirstWordAfterADroppedFiller() {
        #expect(PolishService.capitalizingFirstWord("we can sign on Wednesday.", like: "Um, so we can sign") == "We can sign on Wednesday.")
        #expect(PolishService.capitalizingFirstWord("iPhone sales are up.", like: "Um, iPhone sales") == "iPhone sales are up.")
        #expect(PolishService.capitalizingFirstWord("and then we left.", like: "and then we left") == "and then we left.")
    }

    @Test func fastModelReturnsCleanedText() async throws {
        let text = try await PolishService().polish(raw: "um hello", context: PolishContext(),
                                                    provider: DelayedProvider(delay: .zero),
                                                    model: LLMModel(id: "x"), timeout: .seconds(2))
        #expect(text == "Cleaned.")
    }
}
