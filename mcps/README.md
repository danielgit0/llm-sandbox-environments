# MCP mixins

Each subdirectory is one MCP server, packaged as a Docker Sandbox Kit v3
mixin. A mixin installs exactly one server into the sandbox image and adds
agent instructions for it. Directories are independent: they can use different
upstreams, install methods, and version numbers.

```text
mcps/<name>/
├── kit.yaml          # v3 descriptor: identity, pinned version, agent context
├── kit.Dockerfile    # installs the binary into the image (same stem as kit.yaml)
├── context.md        # text appended to AGENTS.md by the OpenCode workload
└── README.md         # upstream link, pin, update and verification notes
```

`<name>` is the server name used in `workspace/opencode.json`. Use lowercase
letters, digits, and hyphens (`codebase-memory-mcp`, not `CodebaseMemoryMCP`).

## Add a server

1. Create `mcps/<name>/` with the four files above. Keep the descriptor and
   Dockerfile filename stems identical (`kit.yaml` + `kit.Dockerfile`); the kit
   identity comes from the directory, not the filenames.
2. In `kit.yaml`, declare the pinned version as an argument and pass it to the
   Dockerfile as a build argument:

   ```yaml
   args:
     version:
       default: "1.2.3"
       pattern: '^[0-9]+\.[0-9]+\.[0-9]+$'
       buildArg: MCP_VERSION
   ```

   The `default` is the pin; it is the only place the version is written. If
   the descriptor needs the version itself (for example in a `provides` entry),
   reference it as `${{ kit.args.version }}`.
3. In `kit.Dockerfile`, declare `ARG MCP_VERSION` and install the binary at a
   stable path such as `/usr/local/bin/<name>`. Prefer a multi-stage build that
   ends at `FROM scratch` so the mixin adds only the binary, not a package
   manager or download tools. Verify downloaded archives against upstream
   checksums and run the binary's `--version` as a build-time smoke test.
4. Write `context.md`: a short note telling the agent when to use the server
   and to verify its output. Start it with a `## <name>` heading so fragments
   stay grouped when appended to the workload's `AGENTS.md`, and do not repeat
   general sandbox rules there. Prefix the file with
   `<!-- markdownlint-disable MD041 -->` so the lint does not require a
   top-level heading.
5. List the directory in `sbxenv.yaml` after the workload entry:

   ```yaml
   kits:
     - docker.io/docker/sbx-kit-opencode:1.18.31
     - ./mcps/codebase-memory-mcp
     - ./mcps/<name>
   ```

6. Register the command in `workspace/opencode.json`:

   ```json
   "<name>": {
     "type": "local",
     "command": ["/usr/local/bin/<name>"],
     "enabled": true,
     "timeout": 30000
   }
   ```

7. Copy `workspace/opencode.json` into the real workspace if you mount a
   different repository, because OpenCode reads project configuration from its
   working directory.

## Check your work

```bash
sbx env plan ./sbxenv.yaml         # resolves the kit and shows the new entry
docker buildx build --platform linux/amd64 \
  -f mcps/<name>/kit.Dockerfile \
  --build-arg MCP_VERSION=<version> \
  -t local/<name>:<version> mcps/<name>
```

Use `--platform linux/arm64` on ARM64. The plan is authoritative for how
`sbx env` resolves the directory; the explicit build catches Dockerfile errors
without creating a sandbox.

Kits are applied when a sandbox is created. After changing a kit, run
`sbx env rm` and recreate the environment; attaching to an existing sandbox
does not rebuild it.

## Conventions

- **Pinned versions only.** Never track `latest`. The version lives in
  `kit.yaml`; the Dockerfile takes it as a build argument.
- **Checksums.** Verify every downloaded archive against the upstream
  `checksums.txt` (or equivalent) and fail the build on mismatch.
- **One server per directory.** Do not bundle several tools in one mixin; a
  separate directory keeps pins, checksums, and agent instructions independent.
- **Binary path is part of the contract.** `workspace/opencode.json` and
  `context.md` refer to it, so pick a stable absolute path.
- **Do not register these servers through `sbx mcp` / `mcp.servers`.** The
  sandbox MCP gateway runs local stdio servers on the host; these servers are
  installed inside the sandbox image and must be registered in the project's
  OpenCode configuration instead.
- **No credentials.** Do not put API keys in descriptors, Dockerfiles, or
  `opencode.json`; use `sbx secret set` and the kit credential capability.
