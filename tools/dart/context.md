<!-- markdownlint-disable MD041 -->

## Dart MCP

Dart SDK 3.13.5 and `dart_mcp_server` 1.2.1 are installed inside the sandbox.
The DSH MCP client starts it from `/usr/local/bin/dart-mcp-server`; it runs in
the mounted project.

This is a Dart-only toolchain. It does not replace the host Flutter SDK:
`flutter` commands, Flutter widget analysis, and builds remain outside the
sandbox.
