#!/usr/bin/env bash
# Run DSH ACP inside the selected sandbox for IntelliJ's ACP client.
set -euo pipefail

sandbox="${DSH_SANDBOX_NAME:-dsh-sandbox}"
sbx=(/opt/homebrew/bin/sbx)

# Start the sandbox first so sbx's startup notice does not enter the ACP
# JSON-RPC stream.
"${sbx[@]}" exec "$sandbox" true </dev/null >/dev/null 2>&1 || true

patch_args=()
if [ -z "${DSH_ACP_PATCH:-}" ]; then
  if "${sbx[@]}" exec "$sandbox" test -f /opt/flutter-mcp/mcp.patch.yml </dev/null >/dev/null 2>&1; then
    DSH_ACP_PATCH=/opt/flutter-mcp/mcp.patch.yml
  fi
fi
if [ -n "${DSH_ACP_PATCH:-}" ]; then
  patch_args+=(--patch "$DSH_ACP_PATCH")
fi

exec "${sbx[@]}" exec -i \
  "$sandbox" \
  dsh --profile acp "${patch_args[@]}"
