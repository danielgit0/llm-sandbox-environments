# Codebase Memory MCP

[DeusData/codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp)
as a Docker Sandbox Kit v3 mixin. The build downloads the official Linux
release, verifies it against the release's `checksums.txt`, installs it at
`/usr/local/bin/codebase-memory-mcp`, and runs `--version` as a smoke test.

| File             | Purpose                                                   |
| ---------------- | --------------------------------------------------------- |
| `kit.yaml`       | v3 descriptor; pins the release in `args.version.default` |
| `kit.Dockerfile` | multi-stage build; the final image is `scratch`           |
| `context.md`     | instructions appended to the workload's `AGENTS.md`       |

`args.version.default` is the single source of truth: the descriptor passes it
to the Dockerfile as `MCP_VERSION`, so do not add a second version constant.

## Build

From the repository root:

```bash
docker buildx build --platform linux/amd64 \
  -f mcps/codebase-memory-mcp/kit.Dockerfile \
  --build-arg MCP_VERSION=0.12.1 \
  -t local/codebase-memory-mcp:0.12.1 \
  mcps/codebase-memory-mcp
```

Use `--platform linux/arm64` on ARM64. `sbx env` builds the kit itself, so this
explicit build is only for checking the Dockerfile without creating a sandbox.

## Update

1. Check the upstream release assets and `checksums.txt` for the new tag.
2. Raise `args.version.default` in `kit.yaml`.
3. Rebuild or run `sbx env plan` followed by `sbx env rm` and `sbx env run` to
   recreate the sandbox with the new image.
4. In OpenCode, run `/mcp` and confirm the server reports the expected version.

## Notes

- The binary needs glibc 2.38 or newer; the build stage uses the same
  Ubuntu-based template as the OpenCode workload, so the smoke test proves the
  sandbox can run it.
- The index/cache is written under the sandbox user's home by default. Keep it
  out of the mounted workspace, or ignore the tool's data directory there.
- The mixin contributes no network or credential capabilities: the server runs
  locally against the mounted workspace.
