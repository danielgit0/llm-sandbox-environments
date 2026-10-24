# OpenCode Docker Sandbox with MCP Servers

This project runs OpenCode in Docker Sandboxes and gives it local MCP servers
installed into the sandbox image. Each server is an independent Docker Sandbox
Kit v3 mixin under `mcps/`, so the environment is not tied to a single tool:
adding another server is a new directory plus two list entries.

## Layout

```text
.
├── sbxenv.yaml                 # sandbox, workload, workspace, kit list, limits
├── mcps/                       # one self-contained mixin per MCP server
│   ├── README.md               # conventions and add-a-server checklist
│   └── codebase-memory-mcp/
│       ├── kit.yaml            # v3 mixin descriptor: pinned version, agent context
│       ├── kit.Dockerfile      # installs the server binary into the image
│       ├── context.md          # instructions appended to the agent's AGENTS.md
│       └── README.md           # upstream, pin, verification, update notes
└── workspace/
    ├── .gitkeep
    └── opencode.json           # OpenCode project config: registers each server
```

Every `mcps/<name>/` directory is self-contained. The servers can come from
different upstreams, use different install methods, and move on different
release cadences; only the directory conventions are shared. `sbxenv.yaml`
lists the workload first and then one kit per server; `workspace/opencode.json`
registers each installed binary with OpenCode.

Keep `sbxenv.yaml` outside `workspace/`, because the agent can modify its
workspace.

## Add an MCP server

1. Copy `mcps/codebase-memory-mcp/` to `mcps/<name>/` and edit the four files.
   `kit.yaml` and `kit.Dockerfile` must keep the same filename stem (`kit`).
   The directory name, not the filenames, identifies the server.
2. In `mcps/<name>/kit.yaml`, set `displayName`, `description`, `sourceUrl`,
   `licenses`, and the pinned `args.version.default`. Point
   `capabilities[agent-context].config.contentFile` at your `context.md`.
3. In `mcps/<name>/kit.Dockerfile`, install the binary at a stable absolute
   path such as `/usr/local/bin/<name>`, verify any download against its
   published checksum, and smoke-test it (`--version`) during the build.
4. Append the directory to `kits:` in `sbxenv.yaml`:

   ```yaml
   kits:
     - docker.io/docker/sbx-kit-opencode:1.18.31
     - ./mcps/codebase-memory-mcp
     - ./mcps/<name>
   ```

5. Register the same binary in `workspace/opencode.json` so OpenCode starts it
   inside the sandbox:

   ```json
   {
     "mcp": {
       "<name>": {
         "type": "local",
         "command": ["/usr/local/bin/<name>"],
         "enabled": true,
         "timeout": 30000
       }
     }
   }
   ```

Then run `sbx env plan` and inspect the new kit entry before applying. A
minimal descriptor looks like this:

```yaml
schemaVersion: "3"
kind: mixin
displayName: My MCP server
description: Installs my-mcp into the OpenCode sandbox image.
sourceUrl: https://github.com/example/my-mcp
licenses:
  - MIT
dockerfile: ./kit.Dockerfile

args:
  version:
    default: "1.2.3"
    pattern: '^[0-9]+\.[0-9]+\.[0-9]+$'
    buildArg: MCP_VERSION

capabilities:
  - type: com.docker.sandbox/agent-context@1
    config:
      contentFile: ./context.md
```

The `version` argument is passed to the Dockerfile as the `MCP_VERSION` build
argument, so the pin is declared once. `mcps/README.md` has the full checklist
and conventions.

## Why servers are registered in `workspace/opencode.json`

Docker Sandboxes' MCP gateway (`sbx mcp`, `mcp.servers` in `sbxenv.yaml`) runs
local stdio servers on the **host**. The servers in this project are installed
into the **sandbox image**, so they are registered as project-level OpenCode
configuration instead: OpenCode starts them inside the sandbox, where the
binary and its view of the mounted workspace live. The OpenCode workload
separately registers the gateway (when one is active) in
`~/.config/opencode/opencode.json` at startup; OpenCode merges that with the
project configuration.

## Prerequisites

- Docker Sandboxes `sbx` CLI with environment-file and Kit v3 support.
- Docker Buildx.
- An OpenCode provider credential configured through Docker Sandboxes or OpenCode.
- A supported host OS/hypervisor as listed in Docker's current Sandboxes
  installation docs.

Kit v3 and `sbx env` are experimental. Check current Docker docs if your CLI
rejects a field.

## Configure the workspace

The ZIP has a placeholder `workspace/`. Replace it with your repository, or
change `workspace` in `sbxenv.yaml` and copy `workspace/opencode.json` into the
root of the new workspace. OpenCode reads project-level configuration from its
working directory, not automatically from your host's user-level config.

## Plan and run

From this directory:

```bash
sbx env plan ./sbxenv.yaml
sbx env run ./sbxenv.yaml
```

Inspect the plan before approving it. The first run resolves/builds every local
kit and downloads each pinned upstream release during its kit build.

To explicitly build one mixin for validation, run from this directory:

```bash
docker buildx build --platform linux/amd64 \
  -f mcps/codebase-memory-mcp/kit.Dockerfile \
  --build-arg MCP_VERSION=0.12.1 \
  -t local/codebase-memory-mcp:0.12.1 \
  mcps/codebase-memory-mcp
```

Use `--platform linux/arm64` on ARM64. The `sbx env` workflow consumes the local
kit directory directly, so this explicit build is optional.

## Podman

Podman is not used. `sbx` runs each sandbox as a microVM with its own private Docker
engine and does not talk to Podman. The only optional Docker-CLI step is the explicit
`docker buildx build` above; skip it and let `sbx env run` build the kits.

## Provider authentication

For Anthropic:

```bash
sbx secret set anthropic
```

For OpenAI:

```bash
sbx secret set openai
```

Only configure the provider you use. Do not put keys in YAML, `opencode.json`,
or Dockerfiles.

## Verify MCP

In OpenCode, use `/mcp` to inspect server status. Each configured server is a
local stdio process, so OpenCode starts it inside the sandbox. It can read files
available in the mounted workspace and stores its index/cache under the sandbox
user's home by default.

If one fails to start, run in a sandbox shell:

```bash
command -v codebase-memory-mcp
codebase-memory-mcp --help
```

Use the binary path from the server's `mcps/<name>/kit.Dockerfile`.

## Pinning and updating

- OpenCode v3 workload: `docker.io/docker/sbx-kit-opencode:1.18.31`, pinned in
  `sbxenv.yaml`.
- Each MCP server: pinned in `mcps/<name>/kit.yaml` under
  `args.version.default`. The Dockerfile verifies the downloaded release archive
  against the upstream checksums file.

To update a server, raise `args.version.default` in its `kit.yaml`, verify the
upstream release assets/checksums, then remove and recreate the environment
(`sbx env rm`, `sbx env plan`, `sbx env run`): kits take effect only when the
sandbox is next created. To update the workload, change its kit tag in
`sbxenv.yaml` and recreate the environment.

## Security notes

- MCP servers run inside the sandbox, not as host-side processes.
- OpenCode can modify files in the mounted workspace.
- Keep credentials and sandbox configuration outside the writable workspace.
- Review third-party MCP source and release assets before use; pin releases and
  verify checksums.
- Avoid broad privileged settings unless a documented requirement exists.
