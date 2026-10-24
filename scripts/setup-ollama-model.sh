#!/usr/bin/env bash
# Pull a base model, verify its pinned digest when known, and create the
# stable local tag used by LiteLLM. Change sizes by passing another base tag.
set -euo pipefail

base="${1:-qwen2.5-coder:7b}"
tag="${OLLAMA_LOCAL_TAG:-qwen-coder-local}"
default_base="qwen2.5-coder:7b"
root="$(cd "$(dirname "$0")/.." && pwd)"

echo "pulling $base"
ollama pull "$base"

"$root/scripts/verify-ollama-model.sh" "$base"

if [ "$base" = "$default_base" ]; then
  # The committed Modelfile stays the canonical 7B overlay.
  modelfile="$root/models/qwen-coder-7b.Modelfile"
else
  modelfile="$(mktemp)"
  trap 'rm -f "$modelfile"' EXIT
  cat > "$modelfile" <<EOF
FROM $base
PARAMETER num_ctx ${OLLAMA_NUM_CTX:-32768}
PARAMETER temperature 0.2
EOF
fi

echo "creating $tag (from $base)"
ollama create "$tag" -f "$modelfile"
ollama list | grep -F "$tag" || true
