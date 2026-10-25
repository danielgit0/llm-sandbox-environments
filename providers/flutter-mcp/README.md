# Host Flutter MCP egress

A declaration-only egress kit plus an ACP patch:

- allows the sandbox to reach `localhost:3100` (the host `mcp-proxy`);
- installs `/opt/flutter-mcp/mcp.patch.yml`;
- the ACP wrapper passes that patch to `dsh --profile acp`.

The patch registers:

- `dart` over Streamable HTTP at
  `http://host.docker.internal:3100/mcp`;
- `codebase_memory` over stdio at
  `/usr/local/bin/codebase-memory-mcp`.

Both have `failOnStartupError: true`, so a missing bridge or binary fails ACP
startup instead of producing a tool-less agent.
