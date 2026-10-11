import Testing
@testable import MurmurKit

/// Locks in the whole-word replacement contract (the old code matched substrings,
/// rewriting "ai" inside "rain").
@Suite("Text processing")
struct TextProcessingTests {
    @Test func doesNotReplaceInsideWords() {
        #expect(TextProcessing.applyReplacements("rain again", [(from: "ai", to: "X")]) == "rain again")
    }

    @Test func replacesWholeWordCaseInsensitively() {
        #expect(TextProcessing.applyReplacements("ai there", [(from: "ai", to: "hi")]) == "hi there")
        #expect(TextProcessing.applyReplacements("AI there", [(from: "ai", to: "hi")]) == "hi there")
    }

    @Test func replacesMultiWordPhrase() {
        #expect(TextProcessing.applyReplacements("my email please", [(from: "my email", to: "me@x.com")]) == "me@x.com please")
    }

    @Test func replacementTextIsLiteral() {
        // `$` must not be treated as a regex template reference.
        #expect(TextProcessing.applyReplacements("it costs five", [(from: "five", to: "$5")]) == "it costs $5")
    }

    @Test func punctuationTriggerStillMatches() {
        // A trigger ending in non-word chars shouldn't require a trailing boundary.
        #expect(TextProcessing.applyReplacements("ping :sig now", [(from: ":sig", to: "signature")]) == "ping signature now")
    }
}
