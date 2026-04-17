#!/usr/bin/env bash
set -euo pipefail

if ! command -v swift-format &>/dev/null; then
  echo "swift-format not installed — run: brew install swift-format" >&2
  exit 1
fi

swift-format lint --recursive --strict \
  Packages TalkNative EnhanceExtension TalkNativeTests TalkNativeUITests DeviceSmokeTests
