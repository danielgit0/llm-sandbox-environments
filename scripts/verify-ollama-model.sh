#!/usr/bin/env bash
# Verify a pulled Ollama base model against its pinned registry manifest digest.
# Ollama appends the source manifest as a layer in the local manifest, so the
# registry digest is read from that layer, not from the local file hash.
set -euo pipefail

base="${1:-qwen2.5-coder:7b}"
case "$base" in
  *:*) model="$base" ;;
  *) model="$base:latest" ;;
esac

root="$(cd "$(dirname "$0")/.." && pwd)"
pins="$root/models/ollama-model-digests.txt"

if [ ! -f "$pins" ]; then
  echo "missing $pins" >&2
  exit 1
fi

expected=$(awk -v m="$model" '$1 == m {print $2}' "$pins")
if [ -z "${expected:-}" ]; then
  echo "no pinned digest for $model; skipping verification" >&2
  exit 0
fi

name="${model%:*}"
tag="${model##*:}"
models_dir="${OLLAMA_MODELS:-$HOME/.ollama/models}"
manifest="$models_dir/manifests/registry.ollama.ai/library/$name/$tag"

if [ ! -f "$manifest" ]; then
  echo "missing $manifest" >&2
  echo "run: ollama pull $model" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to read $manifest" >&2
  exit 1
fi

actual=$(python3 - "$manifest" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
for layer in data.get("layers", []):
    if layer.get("mediaType") == "application/vnd.docker.distribution.manifest.v2+json":
        print(layer.get("digest", "").removeprefix("sha256:"))
        break
PY
)

if [ "$actual" != "$expected" ]; then
  echo "$model registry manifest digest mismatch" >&2
  echo "  expected: $expected" >&2
  echo "  actual:   ${actual:-<missing embedded manifest layer>}" >&2
  exit 1
fi

echo "$model registry manifest digest verified"
