#!/usr/bin/env bash
# Run the pinned LiteLLM gateway on the host loopback.
set -euo pipefail
cd "$(dirname "$0")"
umask 077

# Optional local secrets, for example DEEPSEEK_API_KEY. The file is ignored by
# git; required defaults below always win.
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

# --frozen refuses to change the lock and verifies the hashes in uv.lock.
../scripts/uv sync --frozen --no-dev

# No usage telemetry leaves the host.
export LITELLM_TELEMETRY_DISABLED=true

# LiteLLM 1.106.3 refuses to start without authentication. This gateway is
# loopback-only and the sandbox reaches it through the host proxy, so opt in
# to the documented local-only override instead of putting a key in the
# workspace. On a shared host, set LITELLM_MASTER_KEY and give the sandbox a
# key instead.
export LITELLM_DANGEROUSLY_PERMIT_WEAK_OR_UNSET_MASTER_KEY=true

exec ../scripts/uv run --frozen --no-dev litellm \
  --config config.yaml \
  --host 127.0.0.1 \
  --port 4000
