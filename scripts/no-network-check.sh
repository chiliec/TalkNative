#!/usr/bin/env bash
set -euo pipefail

FORBIDDEN='URLSession|\bNetwork\b|NWConnection|URLRequest|URLProtocol'
TARGETS=(Packages TalkNative EnhanceExtension)

hits=$(grep -rnE "$FORBIDDEN" "${TARGETS[@]}" --include='*.swift' || true)
if [[ -n "$hits" ]]; then
  echo "ERROR: network API usage detected (app is on-device only):"
  echo "$hits"
  exit 1
fi
echo "OK: no network API usage found"
