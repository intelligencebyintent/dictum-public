#!/usr/bin/env bash
# Network Guard: run a dictation with an
# outbound-connection monitor and fail if anything connects to an address other
# than 127.0.0.1.
#
# How: the built Debug app runs real dictations (`-selfTestWAV`), from a
# synthesized clip through Parakeet, then replacements: one with cleanup through
# a stand-in LLM server on 127.0.0.1, and one with cleanup on Apple's on-device
# model. It runs under a macOS sandbox profile that
# SIGKILLs the app the instant it tries to open a connection to any non-loopback
# address, or even to ask the system DNS resolver for a hostname. So:
#   1. any outbound attempt kills the dictation (exit 137 = FAIL), and nothing
#      gets out; and
#   2. lsof samples the app's sockets every 100 ms (any non-loopback peer = FAIL).
# A canary first proves the kill rule fires (macOS 27 doesn't log sandbox
# network denials, so the guard can't rely on the log), so a pass means
# "clean", not "not looking".
#
# Usage: scripts/network-guard.sh   (build Dictum Debug first)
# Exit: 0 pass, 1 fail, 2 couldn't run.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${APP:-build/DerivedData/Build/Products/Debug/Dictum.app}"
BIN="$APP/Contents/MacOS/Dictum"
[[ -x "$BIN" ]] || { echo "Network Guard: build Dictum (Debug) first; $BIN not found." >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dictum-netguard.XXXXXX")"
STUB_PID=""; APP_PID=""
cleanup() {
    [[ -n "$APP_PID" ]] && kill "$APP_PID" 2>/dev/null || true
    [[ -n "$STUB_PID" ]] && kill "$STUB_PID" 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

fail() { echo "NETWORK GUARD: FAIL: $*"; exit 1; }

# --- Sandbox profile: everything allowed except leaving the Mac ---
# Outbound IP to anything but loopback, and DNS lookups through mDNSResponder,
# kill the process on the spot.
cat > "$WORK/netguard.sb" <<'SB'
(version 1)
(allow default)
(deny network-outbound (with send-signal SIGKILL) (remote ip "*:*"))
(deny network-outbound (with send-signal SIGKILL) (remote unix-socket (path-literal "/private/var/run/mDNSResponder")))
(allow network-outbound (remote ip "localhost:*"))
SB

# --- 1. Canaries: the kill rule must fire, and loopback must still work ---
# 192.0.2.1 is TEST-NET-1 (reserved, unroutable); an IP literal means no DNS.
# (Inside $(…) with stderr closed, so bash's "Killed: 9" job notice stays quiet.)
CANARY_STATUS=$(exec 2>/dev/null; sandbox-exec -f "$WORK/netguard.sb" /usr/bin/curl -s -m 3 -o /dev/null http://192.0.2.1/; echo $?)
[[ "$CANARY_STATUS" -eq 137 ]] || { echo "NETWORK GUARD: CAN'T RUN: canary to 192.0.2.1 exited $CANARY_STATUS, not 137 (killed); the guard would be blind." >&2; exit 2; }
DNS_STATUS=$(exec 2>/dev/null; sandbox-exec -f "$WORK/netguard.sb" /usr/bin/curl -s -m 3 -o /dev/null http://example.com/; echo $?)
[[ "$DNS_STATUS" -eq 137 ]] || { echo "NETWORK GUARD: CAN'T RUN: DNS canary exited $DNS_STATUS, not 137 (killed)." >&2; exit 2; }
echo "canaries: outbound connection and DNS lookup were both killed (guard works)"

# --- 2. Fixtures: a synthesized clip and the loopback stand-in LLM ---
say -o "$WORK/probe.aiff" "Network guard check. Dictum should only talk to this Mac."
afconvert -f WAVE -d LEI16@16000 -c 1 "$WORK/probe.aiff" "$WORK/probe.wav"

python3 -I scripts/netguard_stub_llm.py "$WORK/port" "$WORK/stub.log" &
STUB_PID=$!
disown "$STUB_PID"   # no "Terminated" notice when cleanup stops it
for _ in $(seq 1 50); do [[ -s "$WORK/port" ]] && break; sleep 0.1; done
[[ -s "$WORK/port" ]] || { echo "NETWORK GUARD: CAN'T RUN: stub LLM server didn't start." >&2; exit 2; }
PORT="$(cat "$WORK/port")"

# --- 3. Run the dictations in the sandboxed app, sampling its sockets ---
run_dictation() {   # run_dictation <label> <self-test flags...>: result in $WORK/<label>.json
    local label="$1"; shift
    sandbox-exec -f "$WORK/netguard.sb" "$BIN" -selfTestWAV "$WORK/probe.wav" "$@" \
        > "$WORK/$label.json" 2> "$WORK/$label.err" &
    APP_PID=$!
    local deadline=$((SECONDS + 180))
    while kill -0 "$APP_PID" 2>/dev/null; do
        lsof -nP -a -p "$APP_PID" -i 2>/dev/null | tail -n +2 >> "$WORK/sockets.log" || true
        if (( SECONDS > deadline )); then fail "the $label self-test didn't finish within 180 s"; fi
        sleep 0.1
    done
    local status=0; wait "$APP_PID" || status=$?
    APP_PID=""
    echo "$label dictation: $(cat "$WORK/$label.json")"
    [[ "$status" -ne 137 ]] || fail "the sandbox killed the app during the $label dictation: it tried to reach a non-loopback address or resolve a hostname"
    [[ "$status" -eq 0 ]] || fail "$label self-test exited $status: $(cat "$WORK/$label.json" "$WORK/$label.err" | head -5)"
    grep -q '"ok":true' "$WORK/$label.json" || fail "$label self-test didn't report ok"
}

run_dictation server -selfTestLLM "http://127.0.0.1:$PORT/v1" -selfTestModel netguard-stub
run_dictation apple -selfTestLLM apple

# --- 4. Verdict ---
PEERS="$(awk '{print $9}' "$WORK/sockets.log" 2>/dev/null | grep -- '->' | sed 's/.*->//' | sort -u || true)"
FOREIGN="$(printf '%s\n' "$PEERS" | grep -vE '^(127\.[0-9]+\.[0-9]+\.[0-9]+|\[::1\]):[0-9]+$' | grep -v '^$' || true)"

echo "socket peers seen: ${PEERS:-none}"
echo "stub LLM requests: $(tr '\n' ';' < "$WORK/stub.log" 2>/dev/null || echo none)"

[[ -z "$FOREIGN" ]] || fail "non-loopback peer(s): $FOREIGN"
grep -q '"final":"Network guard stub reply."' "$WORK/server.json" \
    || fail "cleanup didn't go through the loopback LLM (expected the stub's reply)"
grep -q "POST /v1/chat/completions from 127.0.0.1" "$WORK/stub.log" \
    || fail "the stub LLM never received the cleanup request"

echo "NETWORK GUARD: PASS (two dictations, local server and Apple's model; no connection to anything but 127.0.0.1)"
