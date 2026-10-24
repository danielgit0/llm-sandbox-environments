#!/usr/bin/env bash
# Verify the pulled Ollama model matches the pinned manifest digest.
set -euo pipefail

expected="dae161e27b0e90dd1856c8bb3209201fd6736d8eb66298e75ed87571486f4364"
models_dir="${OLLAMA_MODELS:-$HOME/.ollama/models}"
manifest="$models_dir/manifests/registry.ollama.ai/library/qwen2.5-coder/7b"

if [ ! -f "$manifest" ]; then
  echo "missing $manifest" >&2
  echo "run: ollama pull qwen2.5-coder:7b" >&2
  exit 1
fi

if command -v shasum >/dev/null 2>&1; then
  actual=$(shasum -a 256 "$manifest" | awk '{print $1}')
else
  actual=$(sha256sum "$manifest" | awk '{print $1}')
fi

if [ "$actual" != "$expected" ]; then
  echo "qwen2.5-coder:7b manifest digest mismatch" >&2
  echo "  expected: $expected" >&2
  echo "  actual:   $actual" >&2
  exit 1
fi

echo "qwen2.5-coder:7b manifest digest verified"
