import AVFoundation

/// Reads an audio file into the format every engine expects: 16 kHz mono
/// Float32 samples, in memory. Used by tests, the Network Guard self-test, and
/// the evaluation harness. Never writes audio anywhere.
public enum AudioFileLoader {
    public enum LoadError: Error { case unsupportedFormat, bufferAllocation }

    public static func loadMono16k(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
        guard let converter = AVAudioConverter(from: file.processingFormat, to: outFormat) else {
            throw LoadError.unsupportedFormat
        }
        let capacity = AVAudioFrameCount(Double(file.length) * 16_000 / file.processingFormat.sampleRate + 4096)
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity),
              let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
        else { throw LoadError.bufferAllocation }
        try file.read(into: input)

        var consumed = false
        var convError: NSError?
        converter.convert(to: out, error: &convError) { _, status in
            if consumed { status.pointee = .endOfStream; return nil }
            consumed = true
            status.pointee = .haveData
            return input
        }
        if let convError { throw convError }

        guard let channel = out.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: channel, count: Int(out.frameLength)))
    }
}
