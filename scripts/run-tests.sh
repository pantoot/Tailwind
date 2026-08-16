#!/bin/bash
# Standalone test harness for pure logic (the Xcode project has no test target).
# Compiles the model + service layer for macOS with swiftc and runs assertions.
set -euo pipefail
cd "$(dirname "$0")/.."

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
SDK=$(xcrun --sdk macosx --show-sdk-path)
BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT

SOURCES=("Tailwind/Models/TrainingLoad.swift")
if [ -f "Tailwind/Services/TrainingDirectiveService.swift" ]; then
  SOURCES+=("Tailwind/Services/TrainingDirectiveService.swift")
fi

xcrun swiftc -sdk "$SDK" -o "$BUILD_DIR/tests" \
  "${SOURCES[@]}" \
  scripts/TestShims.swift \
  scripts/TrainingDirectiveTests.swift

"$BUILD_DIR/tests"
