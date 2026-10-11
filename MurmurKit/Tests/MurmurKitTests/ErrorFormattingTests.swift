import Testing
@testable import MurmurKit

/// `HTTPBody.summarize` keeps user-facing HTTP error messages compact: providers
/// can return multi-kilobyte HTML/JSON error pages that must not be dumped into
/// the HUD verbatim.
@Suite("HTTP error formatting")
struct ErrorFormattingTests {
    @Test func collapsesWhitespaceAndNewlines() {
        #expect(HTTPBody.summarize("  hello\n\n  world \t!  ") == "hello world !")
    }

    @Test func truncatesLongBodiesWithEllipsis() {
        let body = String(repeating: "x", count: 500)
        let summary = HTTPBody.summarize(body, limit: 200)
        #expect(summary.count == 201) // 200 chars + ellipsis
        #expect(summary.hasSuffix("…"))
    }

    @Test func shortBodyIsUnchanged() {
        #expect(HTTPBody.summarize("Unauthorized") == "Unauthorized")
    }

    @Test func emptyBodyStaysEmpty() {
        #expect(HTTPBody.summarize("   \n  ") == "")
    }

    @Test func errorDescriptionTruncatesBody() {
        let long = String(repeating: "e", count: 1000)
        let message = LLMError.http(status: 500, body: long).errorDescription ?? ""
        #expect(message.count < 300)
        #expect(message.contains("HTTP 500"))
    }
}
