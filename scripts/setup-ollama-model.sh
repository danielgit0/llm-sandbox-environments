#!/usr/bin/env bash
# Pull a base model, verify its pinned digest when known, and create the
# stable local tag used by LiteLLM. Change sizes by passing another base tag.
set -euo pipefail

base="${1:-qwen3:0.6b}"
tag="${OLLAMA_LOCAL_TAG:-local-llm}"
default_base="qwen3:0.6b"
root="$(cd "$(dirname "$0")/.." && pwd)"

echo "pulling $base"
ollama pull "$base"

"$root/scripts/verify-ollama-model.sh" "$base"

if [ "$base" = "$default_base" ] && [ -z "${OLLAMA_NUM_CTX:-}" ]; then
  # The committed overlay sets a 32k context window for qwen3:0.6b.
  modelfile="$root/models/qwen3-0.6b.Modelfile"
else
  modelfile="$(mktemp)"
  trap 'rm -f "$modelfile"' EXIT
  cat > "$modelfile" <<EOF
FROM $base
PARAMETER num_ctx ${OLLAMA_NUM_CTX:-32768}
PARAMETER temperature 0.1
PARAMETER top_p 0.95
PARAMETER top_k 20
EOF
fi

echo "creating $tag (from $base)"
ollama create "$tag" -f "$modelfile"
ollama list | grep -F "$tag" || true
