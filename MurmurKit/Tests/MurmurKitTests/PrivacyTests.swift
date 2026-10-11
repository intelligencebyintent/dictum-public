import Foundation
import Testing
@testable import MurmurKit

/// Privacy requirements that can be tested without a
/// microphone or a running app. The end-to-end check is `scripts/network-guard.sh`.
@Suite("Privacy")
struct PrivacyTests {

    // MARK: Loopback rule

    @Test(arguments: [
        "http://127.0.0.1:1234/v1",
        "http://127.0.0.1:11434/v1",
        "http://localhost:1234/v1",
        "http://LOCALHOST:1234/v1",
        "http://127.0.0.2:8080",
        "http://[::1]:1234/v1",
        "https://127.0.0.1/v1",
    ])
    func loopbackURLsAreAllowed(_ url: String) {
        #expect(LocalEndpoint.isLoopback(url))
    }

    @Test(arguments: [
        "https://api.openai.com/v1",
        "https://api.anthropic.com/v1",
        "http://192.168.1.20:1234/v1",
        "http://10.0.0.5:11434/v1",
        "http://127.0.0.1.attacker.example/v1",
        "http://localhost.attacker.example/v1",
        "http://attacker.example/127.0.0.1",
        "http://user:pass@127.0.0.1:1234/v1",
        "http://127.0.0.1@attacker.example/v1",
        "http://127.1/v1",
        "http://127.0.0.256/v1",
        "ftp://127.0.0.1/v1",
        "file:///etc/hosts",
        "127.0.0.1:1234",
        "",
    ])
    func nonLoopbackURLsAreRefused(_ url: String) {
        #expect(!LocalEndpoint.isLoopback(url))
    }

    // MARK: The LLM client refuses before opening a socket

    @Test func clientRefusesRemoteBaseURL() async {
        let client = OpenAICompatibleClient(baseURL: "https://api.openai.com/v1")
        #expect(throws: LLMError.self) { try client.endpoint("/models") }

        var refused = false
        do {
            _ = try await client.listModels()
        } catch LLMError.nonLocalEndpoint {
            refused = true
        } catch {}
        #expect(refused, "listModels should fail with nonLocalEndpoint, not attempt a request")

        refused = false
        do {
            for try await _ in client.streamChat(messages: [.user("hi")], model: LLMModel(id: "x"), options: ChatOptions()) {}
        } catch LLMError.nonLocalEndpoint {
            refused = true
        } catch {}
        #expect(refused, "streamChat should fail with nonLocalEndpoint, not attempt a request")
    }

    @Test func detectorSkipsRemoteServers() async {
        let servers = await LocalServerDetector().probe(
            lmStudioBaseURL: "https://api.openai.com/v1",
            ollamaBaseURL: "http://192.168.1.20:11434/v1"
        )
        #expect(servers.isEmpty)
    }

    @MainActor
    @Test func registryWontPolishThroughARemoteURL() {
        let suite = "dictum.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        let registry = EngineRegistry(settings: settings)

        settings.llmProviderID = .lmStudio
        #expect(registry.canPolish)
        settings.lmStudioBaseURL = "https://api.openai.com/v1"
        #expect(!registry.canPolish)
    }

    /// Apple's model is reached in-process, never through a URL, so a remote
    /// URL left in the server settings can't route cleanup anywhere.
    @MainActor
    @Test func appleModelNeverUsesAServerURL() {
        let suite = "dictum.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        let registry = EngineRegistry(settings: settings)

        settings.llmProviderID = .appleOnDevice
        settings.lmStudioBaseURL = "https://api.openai.com/v1"
        #expect(!LLMProviderID.appleOnDevice.usesServer)
        #expect(registry.makeLLMProvider().id == .appleOnDevice)
        #expect(registry.currentLLMModel()?.id == ModelCatalog.appleOnDevice.id)
    }

    // MARK: No cloud code paths in the source

    /// "Remove the cloud providers from the build entirely. Commenting them out
    /// doesn't count." Scans every Swift file, plist and project file for cloud
    /// API hosts and the auto-updater, so they can't creep back in. Apple's
    /// Foundation Models framework can also reach Apple's cloud model, so its
    /// cloud type is banned too: Dictum uses the on-device model only.
    @Test func sourceContainsNoCloudEndpointsOrUpdater() throws {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // MurmurKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // MurmurKit
            .deletingLastPathComponent()   // repo root
        let banned = [
            "api.openai.com", "api.groq.com", "api.deepgram.com", "api.assemblyai.com",
            "api.elevenlabs.io", "api.anthropic.com", "import Sparkle", "SUFeedURL",
            "sparkle-project", "WhisperKit", "PrivateCloudCompute",
        ]
        let scanned = ["Murmur", "MurmurKit/Sources", "MurmurKit/Package.swift", "project.yml"]
        var hits: [String] = []
        var filesChecked = 0
        for relative in scanned {
            let root = repo.appendingPathComponent(relative)
            let files: [URL]
            if relative.hasSuffix(".swift") || relative.hasSuffix(".yml") {
                files = [root]
            } else {
                let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
                files = (enumerator?.allObjects as? [URL] ?? []).filter {
                    ["swift", "plist", "entitlements", "yml"].contains($0.pathExtension)
                }
            }
            for file in files {
                let text = try String(contentsOf: file, encoding: .utf8)
                filesChecked += 1
                for term in banned where text.contains(term) {
                    hits.append("\(file.path.replacingOccurrences(of: repo.path + "/", with: "")): \(term)")
                }
            }
        }
        #expect(filesChecked > 40, "scanned only \(filesChecked) files; is the repo layout right?")
        #expect(hits.isEmpty, "cloud or updater references found:\n\(hits.joined(separator: "\n"))")
    }
}
