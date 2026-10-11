@preconcurrency import AVFoundation
import Accelerate

/// Single-shot feed state for `AVAudioConverter`'s pull-based input block.
/// A reference box so the converter callback mutates a property, not a captured
/// `var` (keeps strict concurrency quiet in the realtime path).
private final class ConverterFeed: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    var consumed = false
    init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }
}

public enum AudioCaptureError: LocalizedError {
    case microphoneDenied
    case formatUnavailable
    case converterUnavailable
    case engineStartFailed(String)

    public var errorDescription: String? {
        switch self {
        case .microphoneDenied: "Microphone access is denied. Enable it in System Settings → Privacy & Security → Microphone."
        case .formatUnavailable: "Couldn't read the microphone's audio format."
        case .converterUnavailable: "Couldn't set up audio conversion."
        case .engineStartFailed(let m): "Audio engine failed to start: \(m)"
        }
    }
}

/// Captures microphone audio via `AVAudioEngine`, converts it to **16 kHz mono
/// Float32** (what every transcription engine expects), accumulates the samples,
/// and reports a normalized RMS level for the live waveform.
///
/// `@unchecked Sendable`: the realtime tap callback mutates shared buffers, so
/// access is guarded by an explicit lock rather than actor isolation (the tap
/// closure cannot hop actors).
public final class AudioCaptureEngine: @unchecked Sendable {
    public let targetSampleRate: Double = 16_000

    private let engine = AVAudioEngine()
    private let outputFormat: AVAudioFormat
    private let lock = NSLock()

    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    private var levelHandler: (@Sendable (Float) -> Void)?
    private var isRunning = false
    private var didHitCap = false

    /// Hard cap on retained audio (~15 min at 16 kHz) so a forgotten or
    /// toggled-on recording can't grow memory without bound. Audio past the cap
    /// is dropped; far beyond any real single dictation.
    private let maxSamples = 16_000 * 60 * 15

    public init() {
        // Force-unwrap is safe: this is a standard, always-available format.
        outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
    }

    public var isCapturing: Bool {
        lock.lock(); defer { lock.unlock() }
        return isRunning
    }

    /// Begin capturing. `onLevel` is called frequently with a 0…1 RMS level
    /// (already on a background thread — hop to the main actor in the handler).
    public func start(deviceUID: String?, onLevel: @escaping @Sendable (Float) -> Void) throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .denied, .restricted:
            throw AudioCaptureError.microphoneDenied
        default:
            break // .authorized, or .notDetermined (engine.start triggers the TCC prompt)
        }

        lock.lock()
        samples.removeAll(keepingCapacity: true)
        levelHandler = onLevel
        didHitCap = false
        lock.unlock()

        let input = engine.inputNode
        bindDevice(deviceUID, to: input)

        let inputFormat = input.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else { throw AudioCaptureError.formatUnavailable }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioCaptureError.converterUnavailable
        }
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw AudioCaptureError.engineStartFailed(error.localizedDescription)
        }

        lock.lock(); isRunning = true; lock.unlock()
        Log.audio.info("Capture started: input \(inputFormat.sampleRate, format: .fixed(precision: 0)) Hz → 16 kHz mono")
    }

    /// Stop capturing and return the accumulated 16 kHz mono samples.
    @discardableResult
    public func stop() -> [Float] {
        lock.lock()
        guard isRunning else { lock.unlock(); return [] }
        isRunning = false
        lock.unlock()

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        lock.lock()
        let captured = samples
        samples.removeAll(keepingCapacity: false)
        levelHandler = nil
        converter = nil
        lock.unlock()

        Log.audio.info("Capture stopped: \(captured.count) samples (\(Double(captured.count) / 16_000.0, format: .fixed(precision: 2))s)")
        return captured
    }

    /// Stop and discard any captured audio.
    public func cancel() {
        _ = stop()
    }

    // MARK: - Realtime conversion

    private func process(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        guard isRunning, var converter = self.converter else { lock.unlock(); return }
        // The input device's format can change mid-recording (e.g. a Bluetooth
        // headset switching profiles, or a default-device change). The converter
        // is built from the format at start; if the live buffer no longer matches,
        // rebuild it so we don't feed a stale resampler and silently drop audio.
        if converter.inputFormat != buffer.format {
            if let rebuilt = AVAudioConverter(from: buffer.format, to: outputFormat) {
                converter = rebuilt
                self.converter = rebuilt
                Log.audio.info("Input format changed to \(buffer.format.sampleRate, format: .fixed(precision: 0)) Hz; rebuilt converter")
            } else {
                lock.unlock()
                Log.audio.error("Input format changed but converter rebuild failed; dropping buffer")
                return
            }
        }
        lock.unlock()

        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1024)
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }

        let feed = ConverterFeed(buffer)
        var conversionError: NSError?
        converter.convert(to: outBuffer, error: &conversionError) { _, statusPtr in
            if feed.consumed {
                statusPtr.pointee = .noDataNow
                return nil
            }
            feed.consumed = true
            statusPtr.pointee = .haveData
            return feed.buffer
        }
        if let conversionError {
            Log.audio.error("Conversion error: \(conversionError.localizedDescription)")
            return
        }

        let frameCount = Int(outBuffer.frameLength)
        guard frameCount > 0, let channel = outBuffer.floatChannelData?[0] else { return }

        // RMS level (0…1, lightly compressed for a livelier waveform).
        var rms: Float = 0
        vDSP_rmsqv(channel, 1, &rms, vDSP_Length(frameCount))
        let level = min(1, sqrt(rms) * 2.5)

        // Re-check isRunning under the lock: stop() may have run during the
        // (lock-free) conversion above, in which case this buffer must not land
        // in the freshly-cleared array.
        lock.lock()
        var hitCap = false
        if isRunning {
            if samples.count < maxSamples {
                samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: frameCount))
            } else if !didHitCap {
                didHitCap = true
                hitCap = true
            }
        }
        let handler = isRunning ? levelHandler : nil
        lock.unlock()

        if hitCap { Log.audio.warning("Capture buffer hit the \(self.maxSamples / 16_000)s cap; dropping further audio") }
        handler?(level)
    }

    // MARK: - Device binding

    /// Pin the engine's input to a specific device (must happen before start).
    private func bindDevice(_ uid: String?, to input: AVAudioInputNode) {
        guard let uid else { return } // no preference → system default
        guard let deviceID = AudioDevices.device(forUID: uid), let unit = input.audioUnit else {
            Log.audio.warning("Selected input device \(uid, privacy: .public) is unavailable; using system default")
            return
        }
        var device = deviceID
        let status = AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &device,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
            Log.audio.error("Failed to bind input device \(uid, privacy: .public): \(status)")
        }
    }
}
