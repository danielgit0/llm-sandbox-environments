#!/usr/bin/env bash
# Run DSH ACP inside the selected sandbox for IntelliJ's ACP client.
set -euo pipefail

sandbox="${DSH_SANDBOX_NAME:-dsh-sandbox}"
sbx=(/opt/homebrew/bin/sbx)

# Start the sandbox first so sbx's startup notice does not enter the ACP
# JSON-RPC stream.
"${sbx[@]}" exec "$sandbox" true </dev/null >/dev/null 2>&1 || true

if [ -z "${DSH_ACP_PATCH:-}" ] \
  && "${sbx[@]}" exec "$sandbox" test -f /opt/flutter-mcp/mcp.patch.yml </dev/null >/dev/null 2>&1; then
  DSH_ACP_PATCH=/opt/flutter-mcp/mcp.patch.yml
fi

if [ -n "${DSH_ACP_PATCH:-}" ]; then
  if ! curl --silent --show-error --max-time 2 \
      --output /dev/null http://127.0.0.1:3100/mcp; then
    printf 'Flutter MCP bridge is not reachable at http://127.0.0.1:3100/mcp\n' >&2
    printf 'Start it with: %s/flutter-mcp/run.sh\n' \
      "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" >&2
    exit 1
  fi
  exec "${sbx[@]}" exec -i \
    "$sandbox" \
    dsh --profile acp --patch "$DSH_ACP_PATCH"
fi

exec "${sbx[@]}" exec -i \
  "$sandbox" \
  dsh --profile acp
