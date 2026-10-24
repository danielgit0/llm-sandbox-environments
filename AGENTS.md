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
            └─ Ollama 0.40.10 (host, 127.0.0.1:11434)
                 └─ qwen2.5-coder:7b (pinned manifest digest)
```

- `sbxenv.yaml` selects the workload kit, the MCP kit, and the LiteLLM egress
  kit.
- `workspace/opencode.json` defines the LiteLLM provider and registers MCP
  servers with OpenCode.
- `mcps/<name>/` contains self-contained v3 mixins that install MCP binaries
  into the sandbox image.
- `providers/litellm/kit.yaml` is the only model egress rule.
- `litellm/` is a uv project: `pyproject.toml`, `uv.lock`, `config.yaml`,
  `run.sh`.
- `models/` holds the Ollama Modelfile overlay.
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
- **Keep the sandbox egress minimal.** The sandbox may reach only
  `localhost:4000` (LiteLLM). Do not add Ollama or provider APIs to the sandbox;
  add providers behind LiteLLM instead.
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
- Ollama **0.40.10**.
- Trivy, hadolint, pre-commit.

Run `scripts/install-uv.sh` once. Do not rely on the ambient `uv`; the wrapper
uses the checksum-verified binary in `.tools/`.

## Common tasks

### Add an MCP server

Follow [mcps/README.md](mcps/README.md). In short: new `mcps/<name>/` with
`kit.yaml`, `kit.Dockerfile`, `context.md`, `README.md`; pin the base digest and
archive hashes; add the kit to `sbxenv.yaml`; register the binary in
`workspace/opencode.json`.

### Add or change a model

A local model needs an Ollama tag created with `num_ctx`, a `model_list` entry
in `litellm/config.yaml`, and an alias under `provider.litellm.models` in
`workspace/opencode.json`. A hosted provider goes in `litellm/config.yaml`
only; its key stays on the host. Model changes do not need sandbox recreation.

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

# Sandbox configuration resolves.
sbx kit inspect \
  docker.io/docker/sbx-kit-opencode@sha256:11d794b51c3f36be5b1f0b4fe59512970eacf1bff35eec50bf223c0825b0a25d
sbx env plan ./sbxenv.yaml

# Audit. It intentionally fails on the upstream OpenCode image; see below.
scripts/audit.sh

# Model integrity, after pulling the model.
scripts/verify-ollama-model.sh

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

## Style and hygiene

- Markdown must pass `markdownlint-cli2` (80 columns, code blocks exempt).
- A `# hadolint ignore=...` comment must be immediately above the instruction
  it suppresses; another comment in between breaks it.
- Do not commit `.venv`, `.uv-cache`, `.uv-python`, `.tools`, `.trivy-cache`,
  or any secret.
- Update README and SECURITY whenever behavior, pins, or accepted risks change.
