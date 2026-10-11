import Foundation

/// Post-transcription text fixups: literal dictionary replacements and snippet
/// expansions. Both are case-insensitive, **whole-word** replacements — a phrase
/// like "ai" must not rewrite the "ai" inside "rain".
public enum TextProcessing {
    public static func applyReplacements(_ text: String, _ pairs: [(from: String, to: String)]) -> String {
        var result = text
        for pair in pairs where !pair.from.isEmpty {
            guard let regex = wholeWordRegex(for: pair.from) else { continue }
            // `escapedTemplate` keeps the replacement literal (no `$1`/`\` surprises).
            let template = NSRegularExpression.escapedTemplate(for: pair.to)
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: template)
        }
        return result
    }

    /// A case-insensitive regex matching `phrase` only at word boundaries. The
    /// `\b` anchors are added only on sides whose edge character is alphanumeric,
    /// so triggers that begin/end with punctuation (e.g. ":sig") still match.
    private static func wholeWordRegex(for phrase: String) -> NSRegularExpression? {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let leading = phrase.first.map(isWordEdge) == true ? "\\b" : ""
        let trailing = phrase.last.map(isWordEdge) == true ? "\\b" : ""
        return try? NSRegularExpression(pattern: leading + escaped + trailing, options: [.caseInsensitive])
    }

    private static func isWordEdge(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }
}
