# Dart MCP mixin

Installs the Linux arm64 Dart SDK 3.13.5 and the JIT `dart_mcp_server` 1.2.1
package, then registers the server with DSH through `mcp.patch.yml`.

- Archive: `dartsdk-linux-arm64-release.zip`
- SHA-256:
  `19a731647c3ed55058ee46dde00330150e6a8729bb6121b4a31e86084c8a3e6d`
- SDK: `/opt/dart-sdk`
- Pub cache: `/opt/dart-pub-cache`
- MCP command: `/usr/local/bin/dart-mcp-server`

This is Dart-only. Flutter's Linux SDK is not installed; Flutter commands stay
on the host.
