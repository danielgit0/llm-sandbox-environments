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
  docker.io/docker/sbx-kit-opencode:1.18.33@sha256:11d794b51c3f36be5b1f0b4fe59512970eacf1bff35eec50bf223c0825b0a25d

echo "== MCP build base image =="
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  --ignore-unfixed \
  --pkg-types os \
  docker/sandbox-templates:shell-docker@sha256:b178ca62ec2e79af2a044e3ec321bdb72188690e1c15d573ea5524b397554d3d
