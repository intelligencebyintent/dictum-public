#!/usr/bin/env bash
# Cleanup bakeoff: same prompt, same ten synthetic paragraphs, each model three
# times, then a scored report. Synthetic text only; never put real dictation
# (eval/) in here.
#
# Usage: tools/cleanup-bakeoff/run.sh [models] [runs] [prompt file]
#   models: comma-separated; "apple" is Apple's on-device model, anything else
#           an LM Studio model id that is already loaded (lms load <id>).
#   default: apple,google/gemma-4-12b, 3 runs, system-prompt.txt
set -euo pipefail
cd "$(dirname "$0")"

MODELS="${1:-apple,google/gemma-4-12b}"
RUNS="${2:-3}"
PROMPT="${3:-system-prompt.txt}"
STAMP="$(date +%Y-%m-%d-%H%M%S)-${PROMPT%.txt}"
BIN="${TMPDIR:-/tmp}/dictum-bakeoff"

swiftc -O -parse-as-library -o "$BIN" Bakeoff.swift
"$BIN" --dir . --models "$MODELS" --runs "$RUNS" --prompt "$PROMPT" --out "results/$STAMP.json"
python3 -I score.py "results/$STAMP.json" > "results/$STAMP.md"
echo "Report: tools/cleanup-bakeoff/results/$STAMP.md"
