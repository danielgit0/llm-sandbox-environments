# Host Flutter MCP bridge

Runs the official Dart/Flutter MCP server on macOS and exposes it to the
sandbox over Streamable HTTP. Flutter/Dart never enter the Linux sandbox.

```bash
FLUTTER_PROJECT=/Users/example/flutter_app \
FLUTTER_DART=/Users/example/flutter/bin/dart \
flutter-mcp/run.sh
```

The bridge listens on `127.0.0.1:3100`:

- MCP endpoint and probe: `http://127.0.0.1:3100/mcp`

The sandbox reaches it as `http://host.docker.internal:3100/mcp`; the
`providers/flutter-mcp` kit allows `localhost:3100`.

`mcp-proxy` is pinned in `uv.lock` and started with the repo's pinned uv; no
pip. The bridge spawns `dart mcp-server` with `--cwd "$FLUTTER_PROJECT"`, so
analyzer and runtime tools see the project.

The project's pre-commit stays on the host; this bridge does not install it.
Keep the bridge running while IntelliJ uses the Flutter ACP agent. The ACP
wrapper checks the bridge before starting and exits with the start command if
it is not reachable.
