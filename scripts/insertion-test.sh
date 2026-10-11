#!/usr/bin/env bash
# Insertion test: paste synthetic text into scratch targets through
# Dictum's real insertion path, and check that it lands, that a password field
# is refused, and that a multi-item, multi-type clipboard comes back exactly.
#
# TAKES OVER THE SCREEN for about 30 seconds: it brings each app forward and
# pastes into it. Don't type while it runs. Your real clipboard is saved and
# put back.
#
# Targets are scratch files that don't sync anywhere: a text file in TextEdit,
# local pages in Chrome (a text box and a password box), and an RTF file in
# Word. Mail, Outlook, Slack, Notes and Claude save drafts to servers, so test
# those by hand.
#
# Safety: the self-test types only if the focused window's title is the scratch
# target's, and this script closes a window (⌘W, then "Don't Save") only after
# checking the same title, so your own documents and tabs are never touched.
# Uses `open` and System Events only, so no app-automation consent prompts.
#
# Usage: scripts/insertion-test.sh [textedit] [chrome] [password] [word]
#        [fallback]  (skips ⌘V in TextEdit to exercise the Accessibility fallback)
#        (default: all five; build Dictum Debug first)
# Exit: 0 pass, 1 fail, 2 couldn't run.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${APP:-build/DerivedData/Build/Products/Debug/Dictum.app}"
BIN="$APP/Contents/MacOS/Dictum"
[[ -x "$BIN" ]] || { echo "Insertion test: build Dictum (Debug) first; $BIN not found." >&2; exit 2; }

TARGETS=("$@")
[[ ${#TARGETS[@]} -gt 0 ]] || TARGETS=(textedit fallback chrome password word)

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dictum-insert.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

sysevents() { osascript -e "tell application \"System Events\" to $1" 2>/dev/null || true; }
front_app() { sysevents 'get name of first application process whose frontmost is true'; }
front_title() { sysevents 'get name of front window of (first application process whose frontmost is true)'; }

FRONT="$(front_app)"
TEXT="Dictum insertion probe $(date +%s)"
FAILED=0

printf '' > "$WORK/dictum-probe.txt"
printf '{\\rtf1\\ansi }' > "$WORK/dictum-probe.rtf"
cat > "$WORK/field.html" <<'HTML'
<!doctype html><title>Dictum insertion test</title>
<textarea autofocus rows="6" cols="60"></textarea>
HTML
cat > "$WORK/password.html" <<'HTML'
<!doctype html><title>Dictum password test</title>
<input type="password" autofocus>
HTML

insert() {   # insert <label> <window title part> [extra self-test flags]
    local label="$1" window="$2" result
    shift 2
    result="$("$BIN" -selfTestInsert "$TEXT" -selfTestExpectWindow "$window" -selfTestDelay 1.2 "$@" 2>/dev/null || true)"
    echo "$label: ${result:-no result}"
    [[ "$result" == *'"ok":true'* ]] || FAILED=1
    case "$label" in
    password) [[ "$result" == *'"outcome":"refusedSecureField"'* ]] || FAILED=1 ;;
    fallback) [[ "$result" == *'"outcome":"accessibility"'* ]] || FAILED=1 ;;
    esac
}

close_front() {   # close_front <window title part>: ⌘W, and "Don't Save" if asked
    if [[ "$(front_title)" != *"$1"* ]]; then
        echo "  (left open: front window is \"$(front_title)\", not the scratch target)"
        return
    fi
    local app; app="$(front_app)"
    sysevents 'keystroke "w" using command down'
    sleep 0.8
    # "Don’t Save" (curly apostrophe), on the scratch window's sheet only.
    sysevents "tell process \"$app\" to click (first button whose name starts with \"Don\") of sheet 1 of (first window whose name contains \"$1\")" >/dev/null
}

for target in "${TARGETS[@]}"; do
    case "$target" in
    textedit|fallback)
        textedit_was_running=0; pgrep -xq TextEdit && textedit_was_running=1
        open -a TextEdit "$WORK/dictum-probe.txt"; sleep 1.5
        if [[ "$target" == fallback ]]; then
            insert fallback dictum-probe -selfTestSkipPaste
        else
            insert textedit dictum-probe
        fi
        close_front dictum-probe
        [[ $textedit_was_running -eq 1 ]] || pkill -x TextEdit || true
        ;;
    chrome)
        open -a "Google Chrome" "$WORK/field.html"; sleep 2
        insert chrome "Dictum insertion test"
        close_front "Dictum insertion test"
        ;;
    password)
        open -a "Google Chrome" "$WORK/password.html"; sleep 2
        insert password "Dictum password test"
        close_front "Dictum password test"
        ;;
    word)
        open -a "Microsoft Word" "$WORK/dictum-probe.rtf"; sleep 4
        insert word dictum-probe
        close_front dictum-probe
        ;;
    *)
        echo "unknown target: $target" >&2; exit 2 ;;
    esac
done

[[ -n "$FRONT" ]] && open -a "$FRONT" 2>/dev/null || true

if [[ $FAILED -eq 0 ]]; then
    echo "INSERTION TEST: PASS (${TARGETS[*]})"
else
    echo "INSERTION TEST: FAIL"
    exit 1
fi
