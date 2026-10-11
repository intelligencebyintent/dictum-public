# Changelog

All notable changes to Dictum, and to Murmur before the fork, are documented
here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Dictum 0.3.2] - 2026-10-11

### Changed
- Cleanup now runs on Apple's on-device model by default (the bakeoff's
  pick), so LM Studio doesn't need to be running.
- After cleanup drops a leading "um, so", the first word keeps its capital.

## [Dictum 0.3.1] - 2026-10-11

Apple's on-device model and the cleanup bakeoff.

### Added
- Apple's on-device model (Apple Intelligence) as a cleanup provider, on this
  Mac only. Its cloud model is banned by a privacy test, and the Network Guard
  covers it.
- `tools/cleanup-bakeoff/`: ten synthetic paragraphs, scored runs of Apple's
  model against LM Studio models, and the results.

### Changed
- Cleanup uses the prompt that tested best in the bakeoff, with per-app
  styles, and gives up after 4 s (the raw transcript goes in).
- LM Studio requests turn thinking off, so Gemma 4 answers in about a second
  instead of six.

## [Dictum 0.3.0] - 2026-10-10

Insertion hardening and the full hotkey table.

### Added
- Double-tap Right ⌘ for hands-free dictation (stops on the next tap or 3 s of
  silence); hold Right ⌥ for high-accuracy dictation (Parakeet for now).
- Esc cancels while recording or processing; ⌃⌥V and a menu item paste the last
  result; ⌃⌥C is Command Mode's default.
- Password fields are refused. If ⌘V goes nowhere, Dictum inserts through
  Accessibility, then falls back to the clipboard with a notice.
- `scripts/insertion-test.sh` and DEBUG insertion and cancel-key self-tests.

### Changed
- Presses under 250 ms, and Right ⌘ used in a shortcut, no longer start a
  dictation. The HUD appears after 250 ms; a lock icon marks hands-free.
- The clipboard is restored 500 ms after pasting (was 250 ms), and never before
  the app has read the dictation. Dictum's clipboard writes stay off Universal
  Clipboard.
- The Activation setting is gone: holding and double-tapping replace it.

## [Dictum 0.2.0] - 2026-10-10

Forked from Murmur 0.1.1 and stripped to local-only.

### Removed
- All cloud transcription engines and cloud LLM providers, API-key storage,
  WhisperKit, Sparkle auto-update, and the Developer ID release tooling.

### Added
- Loopback-only enforcement for every LLM request; system proxies ignored.
- `scripts/network-guard.sh`: a real dictation under a kill-on-egress sandbox.
- Privacy unit tests, including a source scan for cloud hosts and the updater.
- Clipboard writes marked transient/concealed so clipboard managers skip them.

### Changed
- Renamed to Dictum (`com.intelligencebyintent.dictum`); data now lives in
  `~/Library/Application Support/Dictum/`. Default LLM provider is LM Studio at
  `http://127.0.0.1:1234/v1`.

## [0.1.1] - 2026-06-29

A reliability, robustness, and polish release. No new top-level features — every
README capability from 0.1.0 is intact — but the app is meaningfully harder to
break and nicer to use.

### Fixed
- **No longer crashes on a corrupt/unreadable database.** If the on-disk store
  can't be opened, Murmur falls back to an in-memory store and keeps running
  (dictation still works); the History pane explains that saving is paused for
  the session instead of the app failing to launch.
- **Local Parakeet (the default engine) now downloads into Murmur's own models
  directory** (`~/Library/Application Support/Murmur/models/parakeet`) instead of
  FluidAudio's library default, matching where Whisper models already live.
- **Audio capture survives a mid-recording input-format change** (e.g. a
  Bluetooth headset switching profiles): the sample-rate converter is rebuilt on
  the fly instead of silently dropping audio.
- **Cloud transcription no longer times out on long recordings** over a slow
  connection — uploads get a generous 10-minute resource budget.
- **Command Mode / Transforms no longer clobber the clipboard** if you copy
  something while Murmur is reading your selection.
- **HUD no longer flashes a stray idle icon** for a beat after each dictation —
  it holds the completed frame while animating out.
- **History save failures are logged** instead of silently ignored.
- **API error messages in the HUD are now compact** — provider HTML/JSON error
  pages are summarized to a single short line rather than dumped verbatim.

### Changed
- **Dictionary, Snippets, and History rows have explicit delete controls**
  (a remove button plus a right-click "Delete"), since macOS has no
  swipe-to-delete.
- **Onboarding scrolls and resizes** so large accessibility text never clips the
  action button, and the permission cards have clearer contrast.
- **Recording pill border adapts to light/dark mode** (was a fixed white hairline
  that vanished in light mode).
- **VoiceOver labels** added to icon-only buttons (show/hide API key, refresh
  models, copy) and to the recording HUD states.
- The HUD no longer hard-clips at large Dynamic Type sizes.
- "View on GitHub" in About now points at the correct repository.

## [0.1.0] - 2026-01-01

- Initial open-source release.
