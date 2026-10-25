# Security and pinning

This repository pins the runtime components it controls. Pinning prevents
silent upgrades and verifies content; it does not prove that a version has no
vulnerabilities. `scripts/audit.sh` is the gate that checks that.

## Pins

- OpenCode workload:
  `docker.io/docker/sbx-kit-opencode:1.18.33@sha256:11d794b51c3f36be5b1f0b4fe59512970eacf1bff35eec50bf223c0825b0a25d`
  (1.18.33 is the latest published kit; 1.19.4 does not exist)
- codebase-memory-mcp: 0.12.1, with release archive hashes hardcoded in
  `mcps/codebase-memory-mcp/kit.Dockerfile`
  - linux-amd64:
    `8453015145f072c1b9b019cbdd02cea8cc6f18cc5e116036dd20992631c638c7`
  - linux-arm64:
    `8575f126092660b93b170bdc2e06f3ef2dd28d3cc49ad6d0895dc3e4767219cd`
- MCP build base image:
  `docker/sandbox-templates:shell-docker@sha256:b178ca62ec2e79af2a044e3ec321bdb72188690e1c15d573ea5524b397554d3d`
- LiteLLM: 1.106.3, locked in `litellm/uv.lock` and installed with
  `uv sync --frozen`
- Python: 3.12.15, pinned in `litellm/.python-version`
- uv: 0.13.5, installed by `scripts/install-uv.sh` after SHA-256
  verification and invoked via `scripts/uv`
- Ollama: 0.40.10 (optional local fallback)
  - `Ollama-darwin.zip`:
    `0c8ac7dc394a7b6171d8531bdaba60dd8dd2d8ed525ebc6c4526a91497a029ee`
  - `ollama-darwin.tgz`:
    `ac4f4d012a6d156718eef9aa8f2c7dd7e1f5c47362faf84d3eed412d805f2e2b`
  - `ollama-linux-amd64.tar.zst`:
    `1e8ad2d2a394efdd235bee74deec237badd95142ffba77588140ab2a9ecec227`
  - `ollama-linux-arm64.tar.zst`:
    `57dca26f51efc050112b733a65dea6f6c8e68da7a2946afd7c1eb8834d9eeb92`
- qwen2.5-coder base models: digests pinned in `models/ollama-model-digests.txt`
  (0.5b test, 1.5b, 3b, 7b)
- DSH SDK: 0.2.1rc2, locked in `dsh/uv.lock`; the lock also pins
  `deepseek-harness-runtime-bin==0.2.1rc2` and its per-platform hashes
- DSH uv builder:
  `ghcr.io/astral-sh/uv:0.13.5@sha256:32a7bb39b496babbd997b0a39a4d66c126bdaf5661b302bf6f06abda8deca6ff`
- DSH Python: 3.12.15 (`dsh/.python-version`)
- Flutter: 3.47.6 / Dart 3.13.5 on the macOS host (`flutter-mcp`)
- mcp-proxy: 0.13.0, locked in `flutter-mcp/uv.lock`
- OpenSpec: 1.15.0 (`@fission-ai/openspec`, MIT); Node >=20.19
- OpenSpec build stage:
  `node:22.22.1-bookworm-slim@sha256:4f77a690f2f8946ab16fe1e791a3ac0667ae1c3575c3e4d0d4589e9ed5bfaf3d`
- hadolint (dev): `docker.io/hadolint/hadolint:v2.14.0@sha256:27086352fd5e1907ea2b934eb1023f217c5ae087992eb59fde121dce9c9ff21e`
- Tested sandbox CLI: `sbx 0.48.0`

## Audit

Run the gate from the repository root:

```bash
scripts/audit.sh
```

The DSH spike image is built separately and can be scanned manually:

```bash
docker buildx build --platform linux/arm64 -f dsh/kit.Dockerfile \
  -t local/dsh:audit dsh
trivy image --pkg-types os --scanners vuln \
  --severity HIGH,CRITICAL local/dsh:audit
```

It runs:

- `trivy fs` for repository vulnerabilities, secrets, misconfiguration, and
  the hashed LiteLLM lockfile
- `trivy image` (OS packages only) on the pinned OpenCode workload and MCP
  base image

The same gate is available as a manual pre-commit hook:
`pre-commit run --hook-stage manual trivy-audit`. The default pre-commit stage
also runs `uv lock --check`, shellcheck, yamllint, JSONC validation, codespell,
hadolint, and gitleaks; it stays fast and offline.

The gate fails on HIGH or CRITICAL findings. Image scans use
`--ignore-unfixed`, so fixable findings fail the run and unfixed OS findings
must be recorded below. Accepted findings go into `.trivyignore.yaml` with a
scoped path, a statement, and an expiry date.

## Advisory status at pin time

- LiteLLM 1.106.3: OSV/PyPI query returns 0 advisories (released 2026-10-24).
  Its lock still contains filelock 3.32.7 (CVE-2026-112940); see below.
- OpenCode 1.18.33: OSV queries for the npm and Go packages return 0, but the
  image's Debian 13.7 base has 54 HIGH OS-package CVEs with fixes available
  (bind9, curl, libexpat, linux-libc-dev). No newer kit is published, so the
  pinned workload cannot be patched from this repository. The audit gate fails
  on it intentionally; see the README Known issue.
- codebase-memory-mcp 0.12.1: OSV Go query returns 0.
- Ollama 0.40.10: OSV returns Go advisories whose GHSA ranges end at
  `<= 0.20.2`, `<= 0.13.5`, `<= 0.9.6`, and `<= 0.3.14`. The OSV records lack
  `fixed` events, so the query looks broader than the GHSA data. 0.40.10 is
  newer than every listed range; re-check this on each bump.

The MCP build base image scans clean. The OpenCode workload image does not;
that finding is recorded above and in the README Known issue.

## Accepted risks

- **LiteLLM runs without a master key and binds 127.0.0.1.** LiteLLM 1.106.3
  refuses to start unauthenticated unless
  `LITELLM_DANGEROUSLY_PERMIT_WEAK_OR_UNSET_MASTER_KEY=true`; `run.sh` sets it
  deliberately. Only host processes and the sandbox proxy can reach the
  gateway. On a shared host, set `LITELLM_MASTER_KEY` and give the sandbox the
  key instead.
- **Host secrets live in `litellm/.env` or the invoking environment.** `.env`
  is gitignored and loaded by `run.sh`; it is never mounted into the sandbox.
- **DSH is experimental and not security-audited.** DSH ACP executes
  model-generated code and commands inside the microVM. The microVM is the
  boundary; DSH's own SAFETY.md does not claim secure or production-ready
  behavior. IntelliJ reaches ACP only through local `sbx exec` stdio; no
  network port is published.
- **DSH ACP defaults to hosted DeepSeek.** Prompts routed to `deepseek` leave
  the host through LiteLLM and are billed by the provider. `DEEPSEEK_API_KEY`
  stays in `litellm/.env`; the sandbox receives only `not-needed`.
- **Flutter host bridge is a deliberate host capability.** Flutter's Linux
  SDK is x86_64-only, so `flutter-mcp` runs Flutter/Dart MCP on macOS and
  allows the Flutter sandbox to reach `localhost:3100`. Flutter commands and
  the project pre-commit execute on the host, outside the microVM; the sandbox
  can invoke them through MCP. Pin `mcp-proxy==0.13.0` in
  `flutter-mcp/uv.lock` and keep the bridge on `127.0.0.1`.
- **DSH SDK is a pre-release.** `deepseek-harness-sdk==0.2.1rc2` is pinned
  exactly. Its web profile has missing directory-picker peers; the ACP profile
  is used instead.
- **filelock CVE-2026-112940 (HIGH, fixed in 4.2.1).** LiteLLM 1.106.3
  requires `filelock<4.0`, so the fixed release cannot be installed without
  overriding an upstream constraint. The vulnerable `ReadWriteLock` path is
  not used by LiteLLM or huggingface-hub here (they use `FileLock`), and this
  setup does not download Hugging Face models. The scoped exception in
  `.trivyignore.yaml` expires 2027-01-24; re-check LiteLLM's pin when updating.
- **Ollama binds 127.0.0.1 and is not reachable from the sandbox.** The only
  sandbox egress entry is `localhost:4000` (LiteLLM). Ollama's model-management
  API is therefore host-local, not sandbox-visible.
- **Model verification is post-pull.** `scripts/verify-ollama-model.sh <base>`
  reads the registry manifest digest recorded in the local manifest (Ollama
  appends it as a layer) and compares it with
  `models/ollama-model-digests.txt`; a tag without a pin is skipped with a
  warning, so experimental sizes remain usable.
  If Ollama re-tags a pinned model, the script fails closed.
- **The host OS, Docker, `sbx`, and Trivy are outside the lock.** Keep them
  patched and record the tested `sbx` version.
- **Dev tooling is rev-pinned, not hash-locked.** Pre-commit hooks pin their
  repository revisions; the npm and Python tool dependencies they install are
  not covered by `litellm/uv.lock`.

## Updating

1. Pick a new version and obtain its digest or release hash.
2. Update `sbxenv.yaml`, `kit.Dockerfile`, `litellm/pyproject.toml`, or the
   Ollama/model pins as applicable.
3. Regenerate and install the lock:

   ```bash
   cd litellm && ../scripts/uv lock && ../scripts/uv sync --frozen --no-dev
   ```

4. Run `scripts/audit.sh`; record new advisories and exceptions here.
5. Recreate the sandbox (`sbx env rm`, `sbx env run`) and re-run the validation
   commands in the README.
