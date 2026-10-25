#!/usr/bin/env bash
# Expose the host Flutter/Dart MCP server to the sandbox over Streamable HTTP.
set -euo pipefail
cd "$(dirname "$0")"

# Reuse the existing host env file. Never forward the LiteLLM key to the
# Flutter/Dart MCP process.
if [ -f ../litellm/.env ]; then
  set -a
  # shellcheck disable=SC1091
  . ../litellm/.env
  set +a
  unset DEEPSEEK_API_KEY
fi

: "${FLUTTER_PROJECT:?set FLUTTER_PROJECT to the absolute Flutter project path}"
dart_bin="${FLUTTER_DART:-$(command -v dart || true)}"
if [ -z "$dart_bin" ]; then
  echo "dart not found; set FLUTTER_DART to the Flutter SDK's dart binary" >&2
  exit 1
fi

../scripts/uv sync --frozen --no-dev

exec ../scripts/uv run --frozen --no-dev mcp-proxy \
  --host 127.0.0.1 \
  --port "${FLUTTER_MCP_PORT:-3100}" \
  --cwd "$FLUTTER_PROJECT" \
  --pass-environment \
  -- "$dart_bin" mcp-server
