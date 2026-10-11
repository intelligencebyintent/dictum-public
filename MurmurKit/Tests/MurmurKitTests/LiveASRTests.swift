import AVFoundation
import Foundation
import Testing
@testable import MurmurKit

/// End-to-end local-transcription check. Gated behind `MURMUR_LIVE_ASR=1` because
/// it downloads a ~600MB CoreML model on first run and needs a real audio file.
///
/// Generate the sample first:
///   say -o /tmp/murmur_test.aiff "Testing Murmur local transcription, one two three."
///   afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/murmur_test.aiff /tmp/murmur_test.wav
///   MURMUR_LIVE_ASR=1 swift test --filter parakeetTranscribesRealAudio
@Test(.enabled(if: ProcessInfo.processInfo.environment["MURMUR_LIVE_ASR"] == "1"))
func parakeetTranscribesRealAudio() async throws {
    let path = ProcessInfo.processInfo.environment["MURMUR_LIVE_WAV"] ?? "/tmp/murmur_test.wav"
    let samples = try AudioFileLoader.loadMono16k(URL(fileURLWithPath: path))
    #expect(samples.count > 16_000, "expected >1s of audio, got \(samples.count) samples")

    let model = ModelCatalog.defaultTranscriptionModel(for: .parakeet)
    let engine = ParakeetEngine(model: model)
    try await engine.prepare(model: model) { p in
        if p == 1 { print("Parakeet model ready (downloaded to \(ModelStorage.modelsDirectory.path))") }
    }

    // Run twice to prove the fresh-decoder-state fix: the 2nd dictation must be
    // just as good as the 1st (no state bleed).
    let first = try await engine.transcribe(samples: samples, options: TranscriptionOptions(language: "en"))
    let second = try await engine.transcribe(samples: samples, options: TranscriptionOptions(language: "en"))
    print("ASR #1: \(first.text)")
    print("ASR #2: \(second.text)")

    #expect(!first.text.isEmpty, "first transcription was empty")
    #expect(!second.text.isEmpty, "second transcription was empty (decoder-state bleed?)")
    let normalized = first.text.lowercased()
    #expect(normalized.contains("murmur") || normalized.contains("transcription") || normalized.contains("test"),
            "transcript didn't contain expected words: \(first.text)")
    #expect(second.text == first.text, "same audio gave different results across runs: '\(first.text)' vs '\(second.text)'")
}

/// Out-of-the-box regression: with the *shipping defaults*, the default engine
/// must be on-device AND actually transcribe. Gated (downloads the model on first run).
@Test(.enabled(if: ProcessInfo.processInfo.environment["MURMUR_LIVE_ASR"] == "1"))
@MainActor
func defaultEngineTranscribesOnDevice() async throws {
    // Fresh UserDefaults so we exercise the shipping DEFAULT, not a persisted choice.
    let suite = "murmur.tests.ootb"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    let settings = AppSettings(defaults: defaults)

    #expect(settings.transcriptionEngineID == .parakeet)
    let registry = EngineRegistry(settings: settings)

    let path = ProcessInfo.processInfo.environment["MURMUR_LIVE_WAV"] ?? "/tmp/murmur_test.wav"
    let samples = try AudioFileLoader.loadMono16k(URL(fileURLWithPath: path))
    #expect(samples.count > 16_000, "expected >1s of audio, got \(samples.count) samples")

    let engine = try await registry.preparedTranscriptionEngine()
    let result = try await engine.transcribe(samples: samples, options: TranscriptionOptions(language: "en"))
    print("OOTB ASR (\(settings.transcriptionEngineID.rawValue)): \(result.text)")
    #expect(!result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "the default engine produced no text")
}
