#!/usr/bin/env bash
# Run the pinned LiteLLM gateway on the host loopback.
set -euo pipefail
cd "$(dirname "$0")"
umask 077

# --frozen refuses to change the lock and verifies the hashes in uv.lock.
../scripts/uv sync --frozen --no-dev

# No usage telemetry leaves the host.
export LITELLM_TELEMETRY_DISABLED=true

exec ../scripts/uv run --frozen --no-dev litellm \
  --config config.yaml \
  --host 127.0.0.1 \
  --port 4000
