#!/usr/bin/env bash
set -euo pipefail

FORBIDDEN='URLSession|\bNetwork\b|NWConnection|URLRequest|URLProtocol'
TARGETS=(Packages TalkNative EnhanceExtension TalkNativeKeyboard)
# The cloud tier's provider is the one place networking is allowed, plus its tests.
ALLOW='^Packages/EnhancerCore/Sources/EnhancerCore/GatewayProvider\.swift:|^Packages/EnhancerCore/Tests/'

hits=$(grep -rnE "$FORBIDDEN" "${TARGETS[@]}" --include='*.swift' | grep -vE "$ALLOW" || true)
if [[ -n "$hits" ]]; then
  echo "ERROR: network API usage outside GatewayProvider.swift:"
  echo "$hits"
  exit 1
fi
echo "OK: network API usage confined to GatewayProvider.swift"
