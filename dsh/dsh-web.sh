#!/usr/bin/env bash
# Bind the DSH web UI to the sandbox's concrete interface address. DSH rejects
# wildcard binds so that the RCE-capable UI is not exposed on every interface.
set -euo pipefail

host="${DSH_WEB_HOST:-}"
if [ -z "$host" ]; then
  host="$(hostname -i | awk '{print $1}')"
fi
port="${DSH_WEB_PORT:-3000}"
log="${DSH_HOME:-/home/agent/.dsh}/web.log"
mkdir -p "$(dirname "$log")"

# Keep the one-time token URL retrievable from inside the sandbox.
exec > >(tee -a "$log") 2>&1
exec dsh --profile web --host "$host" --port "$port" --no-open
