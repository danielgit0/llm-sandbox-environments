#!/usr/bin/env bash
# Audit pinned dependencies and images. Fails on HIGH/CRITICAL findings.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .trivy-cache

export TRIVY_CACHE_DIR="${TRIVY_CACHE_DIR:-$PWD/.trivy-cache}"

# Scans litellm/uv.lock and the repository for vulnerabilities,
# committed secrets, and misconfiguration.
echo "== repository and lockfiles =="
trivy fs \
  --scanners vuln,secret,misconfig \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  --ignorefile .trivyignore.yaml \
  --skip-dirs .git \
  --skip-dirs .trivy-cache \
  --skip-dirs .uv-cache \
  --skip-dirs .uv-python \
  --skip-dirs .tools \
  --skip-dirs .pre-commit-cache \
  --skip-dirs .go-cache \
  --skip-dirs .npm-cache \
  --skip-dirs litellm/.venv \
  .

# OS packages only: language packages are covered by the lockfile scan, and
# image language analysis would force a ~1 GB Java DB download.
echo "== OpenCode workload kit =="
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  --ignore-unfixed \
  --pkg-types os \
  docker.io/docker/sbx-kit-opencode:1.19.5@sha256:f5dcf771efda91c2fe37a5280b93124e03d69a66f14242fb15ed4036e668be3b

echo "== MCP build base image =="
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  --ignore-unfixed \
  --pkg-types os \
  docker/sandbox-templates:shell-docker@sha256:b178ca62ec2e79af2a044e3ec321bdb72188690e1c15d573ea5524b397554d3d
