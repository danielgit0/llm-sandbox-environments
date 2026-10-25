#!/usr/bin/env bash
# Bind the DSH web UI to the sandbox's concrete interface address. DSH rejects
# wildcard binds so that the RCE-capable UI is not exposed on every interface.
set -euo pipefail

host="${DSH_WEB_HOST:-}"
if [ -z "$host" ]; then
  # Prefer IPv4: the published port is tcp4, and hostname -i can return the
  # sandbox's IPv6 address first, which the host cannot reach.
  host="$(hostname -I 2>/dev/null \
    | tr ' ' '\n' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
    | head -n1 || true)"
fi
if [ -z "$host" ]; then
  echo "dsh-web: no IPv4 address found" >&2
  exit 1
fi
port="${DSH_WEB_PORT:-3000}"
log="${DSH_HOME:-/home/agent/.dsh}/web.log"
mkdir -p "$(dirname "$log")"

# Keep the one-time token URL retrievable from inside the sandbox.
exec > >(tee -a "$log") 2>&1
exec dsh --profile web --host "$host" --port "$port" --no-open \
  --public-url "http://127.0.0.1:$port" \
  --trusted-host "127.0.0.1:$port"
