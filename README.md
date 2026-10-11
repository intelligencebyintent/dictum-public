# Dictum

Private push-to-talk dictation for macOS. Hold **Right ⌘**, speak, release, and
the text appears at your cursor in any app. Speech is transcribed on your Mac
by NVIDIA Parakeet (via [FluidAudio](https://github.com/FluidInference/FluidAudio),
on the Neural Engine). Cleanup (filler words, punctuation, self-corrections)
runs on Apple's on-device model by default, or on a local LLM server (LM Studio
or Ollama) on your Mac. **Audio and text never leave the machine.**

Dictum is a fork of [Murmur](https://github.com/robzilla1738/Murmur) by Robert
Courson (MIT License), stripped to local-only, with hardened text insertion and
a tested cleanup prompt.

## Privacy

- **No cloud code.** Murmur's OpenAI, Groq, Deepgram, AssemblyAI, ElevenLabs and
  Anthropic providers and the Sparkle auto-updater are removed from the build,
  not disabled. A unit test fails if any of their hostnames reappear in the
  source.
- **Loopback only.** The LLM client refuses any server address that isn't
  `127.0.0.1`, `localhost` or `::1`, before opening a socket, and ignores
  system proxies.
- **Apple's model stays on the Mac.** Cleanup on Apple's model uses the
  on-device model only. Apple's framework can also reach Apple's cloud model
  (Private Cloud Compute); a unit test fails if the source ever uses it.
- **Network Guard.** `scripts/network-guard.sh` runs real dictations (cleanup
  through a loopback server, and on Apple's model) in the built app under a
  macOS sandbox that kills the app if it tries to reach any non-loopback
  address or resolve a hostname.
- **Clipboard.** Dictated text is pasted through the clipboard, marked with the
  `org.nspasteboard` transient/concealed types so clipboard managers (Raycast,
  Maccy, Paste, Alfred) don't record it, and marked current-host-only so
  Universal Clipboard doesn't sync it to your other devices. The previous
  clipboard (every item and type) is restored. Password fields are refused.
- **No telemetry, analytics, crash reporting or update checks.**
- **Network use during setup only.** The Parakeet model (~600 MB) downloads
  once from Hugging Face on first run. After that, nothing goes out.
- **History is on.** Dictations are saved in
  `~/Library/Application Support/Dictum/Dictum.store`, unencrypted. Delete
  entries or clear it in Settings → History.

## Permissions

| Permission | Why Dictum needs it |
|---|---|
| **Microphone** | To hear you while you hold the dictation key. Audio is kept in memory and discarded after transcription. |
| **Accessibility** | To paste the transcript into the app you're typing in (a synthesized ⌘V) and to read the frontmost app and selected text. |
| **Input Monitoring** | To notice the **Right ⌘** and **Right ⌥** hold keys from any app, and whether another key is pressed while one is held (so ⌘C doesn't start a dictation). Dictum doesn't record or log which keys you press. The ⌃⌥ shortcuts work without it. |

On macOS 27, Accessibility and Input Monitoring are both granted under
**System Settings → Privacy & Security → Device Control and Data Access**. If a
grant doesn't take after a rebuild, clear the stale entry with
`tccutil reset All com.intelligencebyintent.dictum` and grant again.

Dictum is unsandboxed, as Murmur was: a global event tap and synthesized paste
are impossible under the App Sandbox. It lives in the menu bar with no Dock icon.

## Hotkeys

All rebindable in Settings → Shortcuts.

| Action | Default | Behavior |
|---|---|---|
| Push-to-talk | Hold Right ⌘ | Record while held; insert on release. |
| Hands-free | Double-tap Right ⌘ (or ⌃⌥D) | Record until the next tap or 3 s of silence. |
| High-accuracy | Hold Right ⌥ | Push-to-talk reserved for a high-accuracy engine (currently Parakeet). |
| Command Mode | ⌃⌥C | Press, say how to change the selected text, press again. |
| Cancel | Esc while dictating | Discard. Insert nothing. Esc is claimed only while dictating. |
| Paste last | ⌃⌥V | Insert the last result again. |

Presses under 250 ms do nothing, and neither does Right ⌘ when it's part of a
shortcut (⌘C, ⌘-click, ⌘-Tab).

## Cleanup

Cleanup removes filler words, fixes punctuation, resolves spoken corrections
("Tuesday, no, Wednesday" becomes "Wednesday"), and applies spoken formatting
("new paragraph", numbered lists), with a style per app (email, documents,
chat, prompts to AI assistants). It never answers or acts on what you dictate.
If cleanup fails or takes longer than 4 seconds, the raw transcript goes in.

`tools/cleanup-bakeoff/` holds the test that picked the default: ten synthetic
paragraphs run through Apple's on-device model and Gemma 4 12B (LM Studio),
scored for facts kept, invented words, leftover corrections and latency. Apple's
model was about twice as fast (1.1 s median) and needs nothing running; Gemma 4
was slightly more accurate. Switch providers in Settings → AI Polish.

## Build

Requires macOS 26+ on Apple silicon, Xcode 26+, and
[XcodeGen](https://github.com/yonaskolb/XcodeGen). Apple's on-device model
needs Apple Intelligence turned on.

```bash
xcodegen generate
xcodebuild -project Dictum.xcodeproj -scheme Dictum -configuration Debug \
  -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' build
cd MurmurKit && swift test        # unit tests, including the privacy tests
scripts/network-guard.sh          # end-to-end Network Guard (needs the Debug build)
scripts/insertion-test.sh         # paste into scratch TextEdit/Chrome/Word targets (takes over the screen)
tools/cleanup-bakeoff/run.sh      # compare cleanup models on ten synthetic paragraphs
```

The app target is signed with a self-signed certificate named "Dictum Local
Code Signing", so macOS keeps the permission grants across rebuilds. Create one
in Keychain Access (Certificate Assistant → Create a Certificate, type Code
Signing), or set `CODE_SIGN_IDENTITY` to `-` in `project.yml` for ad-hoc
signing (you'll then re-grant Accessibility and Input Monitoring after each
rebuild). There is no notarized build.

## Layout

- `MurmurKit/`: the UI-free engine package (transcription, local LLM client,
  audio, settings). The module keeps its upstream name.
- `Murmur/`: the app shell (menu bar, HUD, hotkeys, insertion, Settings).
- `scripts/`: `bootstrap.sh`, `network-guard.sh` and its loopback stub server,
  and `insertion-test.sh`.
- `tools/cleanup-bakeoff/`: the cleanup model bakeoff (synthetic test
  paragraphs, the tested prompt, scored results).

## License

MIT. See [LICENSE](LICENSE). Dictum is based on Murmur, copyright Robert
Courson; Dictum's changes are copyright Intelligence by Intent.
