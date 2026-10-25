# AGENTS.md

Instructions for AI agents editing this repository. Read
[README.md](README.md), [SECURITY.md](SECURITY.md), and
[mcps/README.md](mcps/README.md) before changing behavior or pins.

## Scope

This repository is a sandbox *template*, not an application. It defines how
OpenCode runs in Docker Sandboxes with MCP servers baked into the image and a
host-side LiteLLM gateway.

The sandboxed OpenCode agent only sees the mounted `workspace/` directory. This
file is for agents editing the template itself; if the sandboxed agent needs
project rules, put them in the mounted workspace or in an MCP `context.md`.

## Architecture

```text
OpenCode (sandbox)
  └─ http://host.docker.internal:4000/v1     (only egress: localhost:4000)
       └─ LiteLLM 1.106.3   (host uv project, 127.0.0.1:4000)
            └─ DeepSeek API (host egress; key in litellm/.env)
```

- `sbxenv.yaml` selects the workload kit, the MCP kit, and the LiteLLM egress
  kit.
- `workspace/opencode.json` defines the LiteLLM provider and registers MCP
  servers with OpenCode.
- `mcps/<name>/` contains self-contained v3 mixins that install MCP binaries
  into the sandbox image.
- `flutter-mcp/` is the host-side stdio-to-HTTP bridge for Flutter/Dart MCP;
  `providers/flutter-mcp` allows the sandbox to reach it.
- `providers/litellm/kit.yaml` is the only model egress rule.
- `tools/openspec/` installs the pinned OpenSpec CLI into active sandboxes.
- `dsh/` is an experimental v3 DeepSeek Harness workload; `sbxenv.dsh.yaml`
  selects it. It shares LiteLLM and the egress mixin but has its own workspace.
- `litellm/` is a uv project: `pyproject.toml`, `uv.lock`, `config.yaml`,
  `run.sh`.
- `models/` holds inactive local Qwen assets.
- `scripts/` holds the audit gate and model digest check.

## Non-negotiables

- **Pin everything.** OCI images by digest, MCP archives by SHA-256, Python
  dependencies in `uv.lock`, Python by patch version, and `uv` by
  `required-version`.
- **No floating tags** in runtime paths (`latest`, moving base images, unpinned
  npm/Python tools used at runtime).
- **Never weaken a gate to make it pass.** Do not delete `scripts/audit.sh`
  scans, lower severities, or add broad `.trivyignore.yaml` entries. An
  exception needs an exact path, a statement, and an expiry.
- **Keep the sandbox egress minimal.** The default sandbox may reach only
  `localhost:4000` (LiteLLM). The Flutter host-bridge environment additionally
  allows `localhost:3100` for the MCP bridge. Do not add Ollama or provider
  APIs to the sandbox; add providers behind LiteLLM instead.
- **Keep keys off the sandbox.** Provider keys stay in LiteLLM's host
  environment. Never put keys in YAML, JSON, Dockerfiles, or `uv.lock`.
- **Keep MCP registration in `workspace/opencode.json`.** These servers are
  installed into the sandbox image; `sbx mcp`/`mcp.servers` would run them on
  the host instead.
- **Keep `sbxenv.yaml` outside `workspace/`.** The agent can write the workspace.

## Toolchain

- `uv` **0.13.5**, installed by `scripts/install-uv.sh` and invoked via
  `scripts/uv`.
- `required-version` in `litellm/pyproject.toml` also enforces it.
- Python **3.12.15** (`litellm/.python-version`).
- `sbx` 0.48.0 tested.
- Ollama **0.40.10** (inactive local assets).
- Flutter **3.47.6** / Dart **3.13.5** on the host for the local Flutter bridge.
- `mcp-proxy` **0.13.0** in `flutter-mcp/uv.lock`.
- OpenSpec **1.15.0** (`@fission-ai/openspec`), Node >=20.19.
- Trivy, hadolint, pre-commit.

Run `scripts/install-uv.sh` once. Do not rely on the ambient `uv`; the wrapper
uses the checksum-verified binary in `.tools/`.

## Environment

Required LiteLLM variables live in `litellm/run.sh`; sandbox variables live in
`sbxenv.yaml`. The LiteLLM egress host:port is literal in
`providers/litellm/kit.yaml` because sbx resolves it before `sbxenv` env is
visible to `kit.env`. Optional host secrets go in `litellm/.env` (gitignored,
loaded by `run.sh`); never commit it or mount it into the sandbox.

## Common tasks

### Add an MCP server

Follow [mcps/README.md](mcps/README.md). In short: new `mcps/<name>/` with
`kit.yaml`, `kit.Dockerfile`, `context.md`, `README.md`; pin the base digest and
archive hashes; add the kit to `sbxenv.yaml`; register the binary in
`workspace/opencode.json`.

### DSH workload

`dsh/` is a separate v3 workload selected by `sbxenv.dsh.yaml`. It uses the
pinned uv image, installs `deepseek-harness-sdk` with `uv sync --frozen`, and
keeps the sandbox alive. IntelliJ launches `dsh --profile acp` through
`scripts/dsh-acp-sandbox.sh`, which bridges ACP stdio with `sbx exec -i`.
Keep it additive: do not change the OpenCode workload or workspace when
iterating on DSH.

The agent's model traffic still goes through LiteLLM. DSH's `deepseek-*`
model IDs are mapped to hosted LiteLLM aliases; `DEEPSEEK_API_KEY` belongs in
`litellm/.env`. The SDK web profile is not used; it is incomplete in 0.2.1rc2.

### Flutter workload (local host bridge)

Flutter/Dart run on the macOS host, not in the sandbox. `flutter-mcp/run.sh`
starts `mcp-proxy` on `127.0.0.1:3100` and spawns `dart mcp-server` with the
project as cwd. `providers/flutter-mcp` allows `localhost:3100` from the
sandbox and installs the ACP MCP patch.

`sbxenv.flutter.yaml` is the local environment: DSH,
codebase-memory, LiteLLM, and the host Flutter egress. Set its `workspace` to
the project path. The ACP wrapper auto-detects `/opt/flutter-mcp/mcp.patch.yml`
and registers both MCP servers. Flutter/Dart and the project's pre-commit stay
on the host; do not add Flutter hooks to this repo.

### OpenSpec

`tools/openspec` installs `@fission-ai/openspec@1.15.0` into the active
sandboxes. It is a project CLI, not an MCP server. Run `openspec init` once in
a project, then commit the generated `openspec/` tree and instructions.
OpenSpec requires Node.js >=20.19; the DSH base provides Node 22.22.1.

### Add or change a model

The default is hosted DeepSeek through LiteLLM. Set `DEEPSEEK_API_KEY` in
`litellm/.env`; OpenCode selects `litellm/deepseek-flash`, and DSH advertises
`deepseek-flash` (V4.1 Flash) and `deepseek-v4-pro` (V4 Pro).

Only hosted DeepSeek is active (`deepseek-flash` and `deepseek-v4-pro`).
The local Qwen scripts and assets remain in the repository but are not
referenced by LiteLLM, OpenCode, or DSH.

### Update a pin

1. Change the digest, version, or hash in the owning file.
2. For Python, edit `litellm/pyproject.toml` and run `../scripts/uv lock` in
   `litellm/`.
3. Run `scripts/audit.sh`; record new advisories in `SECURITY.md`.
4. Recreate the sandbox when a kit or env changed.
5. Update the README/SECURITY pin lists.

## Validation

Run from the repository root:

```bash
# Python project: lock is current and installs frozen.
cd litellm
../scripts/uv lock --check
../scripts/uv sync --frozen --no-dev
../scripts/uv run --frozen --no-dev litellm --version
cd ..

# DSH lock and environment resolve.
cd dsh
../scripts/uv lock --check
cd ..
sbx env plan ./sbxenv.dsh.yaml

# Local Flutter host-bridge environment; set workspace first.
sbx env plan ./sbxenv.flutter.yaml

# Sandbox configuration resolves.
sbx kit inspect \
  docker.io/docker/sbx-kit-opencode@sha256:11d794b51c3f36be5b1f0b4fe59512970eacf1bff35eec50bf223c0825b0a25d
sbx env plan ./sbxenv.yaml

# Audit. It intentionally fails on the upstream OpenCode image; see below.
scripts/audit.sh

# Optional local assets only; not part of the active setup.
# scripts/verify-ollama-model.sh qwen2.5-coder:7b

# Fast lint suite (default pre-commit stage).
pre-commit run --all-files

# Vulnerability audit (manual stage; needs Trivy, Docker, and a fresh DB).
pre-commit run --hook-stage manual trivy-audit
```

The default hooks are fast and mostly offline: file hygiene, shellcheck,
yamllint, JSONC validation, markdownlint, codespell, hadolint,
`uv lock --check`, and gitleaks. The `uv lock --check` hook uses the pinned uv
via `scripts/uv`; run `scripts/install-uv.sh` once first.

MCP image build check:

```bash
docker buildx build --platform linux/amd64 \
  -f mcps/codebase-memory-mcp/kit.Dockerfile \
  --build-arg MCP_VERSION=0.12.1 \
  -t local/codebase-memory-mcp:0.12.1 \
  mcps/codebase-memory-mcp
```

## Known issues

- **Upstream OpenCode image has 54 HIGH CVEs with fixes available** in its
  Debian 13.7 base. `1.18.33` is the latest published kit; no newer kit exists,
  so it cannot be patched here. `scripts/audit.sh` fails on it by design. Do not
  suppress this finding; see the README "Known issue" section.
- **filelock CVE-2026-112940** is a scoped, expiring exception in
  `.trivyignore.yaml`. LiteLLM 1.106.3 requires `filelock<4.0`, so 4.2.1 cannot
  be installed. Re-check when LiteLLM relaxes the constraint.
- **`docker.io/docker/sbx-kit-opencode:1.19.4` does not exist.** The pin is
  `1.18.33`.
- **Flutter runs on the host by design.** Flutter's Linux SDK is x86_64-only,
  so the local setup uses the host MCP bridge. iOS/Android SDKs and the project
  pre-commit remain on the host.
- **DSH is an experimental RC.** `deepseek-harness-sdk==0.2.1rc2` is a
  pre-release with no security audit. Its web profile has missing
  directory-picker peers in this wheel; use the ACP profile for IntelliJ.

## Change management

- **Never commit, amend, tag, or push without explicit user approval.**
- Keep changes in incremental, logically grouped working sets; do not mix
  unrelated edits.
- Group uncommitted changes into separate Git changelists by concern (for
  example runtime config, documentation, tooling). Each group must be
  independently reviewable.
- Present the changelist grouping and wait for approval before staging or
  committing.

## Style and hygiene

- Markdown must pass `markdownlint-cli2` (80 columns, code blocks exempt).
- A `# hadolint ignore=...` comment must be immediately above the instruction
  it suppresses; another comment in between breaks it.
- Do not commit `.venv`, `.uv-cache`, `.uv-python`, `.tools`, `.trivy-cache`,
  or any secret.
- Update README and SECURITY whenever behavior, pins, or accepted risks change.
