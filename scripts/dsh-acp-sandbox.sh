#!/usr/bin/env bash
# Run DSH ACP inside the dsh-sandbox for IntelliJ's ACP client.
set -euo pipefail

# Start the sandbox first so sbx's startup notice does not enter the ACP
# JSON-RPC stream.
/opt/homebrew/bin/sbx exec dsh-sandbox true </dev/null >/dev/null 2>&1 || true

exec /opt/homebrew/bin/sbx exec -i \
  -w /home/agent/workspace \
  dsh-sandbox \
  dsh --profile acp --patch /opt/dsh/acp.patch.yml
