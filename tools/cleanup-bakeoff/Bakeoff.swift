// Cleanup bakeoff: run every test paragraph through each candidate model with
// the same system prompt and record the output and the time each call took.
//
// Models: "apple" is Apple's on-device model (SystemLanguageModel, never
// Private Cloud Compute). Anything else is an LM Studio model id, called on
// 127.0.0.1 with thinking turned off. Nothing leaves the Mac.
//
// Build and run with run.sh.
import Foundation
import FoundationModels

struct Suite: Decodable {
    struct Paragraph: Decodable {
        let id: Int
        let style: String
        let raw: String
    }
    let styles: [String: String]
    let paragraphs: [Paragraph]
}

struct Result: Encodable {
    let model: String
    let paragraph: Int
    let run: Int
    let ms: Int
    let prompt: String
    let output: String?
    let error: String?
    let completionTokens: Int?
}

@main
struct Bakeoff {
    static func main() async throws {
        let args = CommandLine.arguments
        func value(_ flag: String) -> String? {
            args.firstIndex(of: flag).flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        }
        let dir = URL(fileURLWithPath: value("--dir") ?? ".")
        let runs = Int(value("--runs") ?? "3") ?? 3
        let models = (value("--models") ?? "apple").split(separator: ",").map(String.init)
        let out = URL(fileURLWithPath: value("--out") ?? "results.json")

        let suite = try JSONDecoder().decode(Suite.self, from: Data(contentsOf: dir.appendingPathComponent("paragraphs.json")))
        let promptFile = value("--prompt") ?? "system-prompt.txt"
        let template = try String(contentsOf: dir.appendingPathComponent(promptFile), encoding: .utf8)

        var results: [Result] = []
        for model in models {
            for run in 1...runs {
                for p in suite.paragraphs {
                    let style = suite.styles[p.style] ?? ""
                    let system = template.replacingOccurrences(of: "{{STYLE}}", with: style)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let user = "<transcript>\n\(p.raw)\n</transcript>"

                    let clock = ContinuousClock()
                    let start = clock.now
                    var output: String?
                    var failure: String?
                    var tokens: Int?
                    do {
                        if model == "apple" {
                            output = try await apple(system: system, user: user)
                        } else {
                            (output, tokens) = try await lmStudio(model: model, system: system, user: user)
                        }
                    } catch {
                        failure = String(describing: error)
                    }
                    let elapsed = clock.now - start
                    let ms = Int(elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000)
                    results.append(Result(model: model, paragraph: p.id, run: run, ms: ms, prompt: promptFile,
                                          output: output?.trimmingCharacters(in: .whitespacesAndNewlines),
                                          error: failure, completionTokens: tokens))
                    print("\(model) run \(run) paragraph \(p.id): \(ms) ms\(failure.map { " ERROR \($0.prefix(120))" } ?? "")")
                }
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(results).write(to: out)
        print("Wrote \(results.count) results to \(out.path)")
    }

    /// Apple's on-device model only. Permissive guardrails are Apple's setting
    /// for transforming the user's own text, which is what cleanup does.
    static func apple(system: String, user: String) async throws -> String {
        let model = SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)
        guard case .available = model.availability else {
            throw NSError(domain: "Bakeoff", code: 1, userInfo: [NSLocalizedDescriptionKey: "Apple model unavailable: \(model.availability)"])
        }
        let session = LanguageModelSession(model: model, instructions: system)
        let response = try await session.respond(to: user, options: GenerationOptions(samplingMode: .greedy))
        return response.content
    }

    static func lmStudio(model: String, system: String, user: String) async throws -> (String, Int?) {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:1234/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "temperature": 0,
            "max_tokens": 1024,
            "reasoning_effort": "none",
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw NSError(domain: "Bakeoff", code: 2, userInfo: [NSLocalizedDescriptionKey: String(decoding: data.prefix(300), as: UTF8.self)])
        }
        let usage = json["usage"] as? [String: Any]
        return (content, usage?["completion_tokens"] as? Int)
    }
}
