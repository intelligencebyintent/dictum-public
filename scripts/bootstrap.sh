#!/usr/bin/env bash
# Generate the Xcode project from project.yml. Run after cloning or whenever
# project.yml changes.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "XcodeGen not found. Install with: brew install xcodegen" >&2
    exit 1
fi

xcodegen generate
echo "✅ Generated Dictum.xcodeproj — open it, or build with the command in README.md."
