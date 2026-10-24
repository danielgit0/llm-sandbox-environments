# syntax=docker/dockerfile:1.7
#
# Mixin overlay: ships ONLY /usr/local/bin/codebase-memory-mcp.
#
# Stage 1 runs on the same Ubuntu-based sandbox template the OpenCode workload uses,
# so the `--version` smoke test proves the binary's glibc/libstdc++ needs (glibc >= 2.38)
# are met at runtime. Stage 2 is `scratch`, so nothing else (apt state, /root dotfiles,
# the upstream updater script) leaks into the composed image.
#
# Supply-chain pins: the base image is pinned by digest and the release archives are
# verified against hashes committed here (not against a checksums file downloaded at
# build time). Bump both together with args.version in kit.yaml.
ARG BASE_IMAGE=docker/sandbox-templates:shell-docker@sha256:b178ca62ec2e79af2a044e3ec321bdb72188690e1c15d573ea5524b397554d3d

FROM ${BASE_IMAGE} AS build
# Fail the build when any stage of a pipeline fails, not just the last command.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# The base template runs as a non-root user; apt and /out need root. This is a
# build stage only: the published mixin is `scratch` and adds no user.
# hadolint ignore=DL3002
USER root
ARG TARGETARCH
# Supplied by the kit descriptor (args.version -> buildArg MCP_VERSION), so the
# release version is declared once, in kit.yaml. A standalone build must pass
# --build-arg MCP_VERSION=<version>.
ARG MCP_VERSION

WORKDIR /tmp/mcp

# apt installs build-time download tools only. Pinning their versions would break
# whenever the pinned base image updates its package set; the binary itself is
# version-pinned and hash-pinned below.
# hadolint ignore=DL3008
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) \
        MCP_ARCH=amd64; \
        MCP_SHA256=8453015145f072c1b9b019cbdd02cea8cc6f18cc5e116036dd20992631c638c7; \
        ;; \
      arm64) \
        MCP_ARCH=arm64; \
        MCP_SHA256=8575f126092660b93b170bdc2e06f3ef2dd28d3cc49ad6d0895dc3e4767219cd; \
        ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl tar; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /out/usr/local/bin; \
    ARCHIVE="codebase-memory-mcp-linux-${MCP_ARCH}.tar.gz"; \
    BASE_URL="https://github.com/DeusData/codebase-memory-mcp/releases/download/v${MCP_VERSION}"; \
    curl --fail --show-error --location --retry 3 "${BASE_URL}/${ARCHIVE}" -o "${ARCHIVE}"; \
    echo "${MCP_SHA256}  ${ARCHIVE}" | sha256sum --check --strict -; \
    tar -xzf "${ARCHIVE}" codebase-memory-mcp; \
    install -m 0755 codebase-memory-mcp /out/usr/local/bin/codebase-memory-mcp; \
    /out/usr/local/bin/codebase-memory-mcp --version

FROM scratch
COPY --from=build /out/ /
