# syntax=docker/dockerfile:1.7
#
# Mixin overlay: ships ONLY /usr/local/bin/codebase-memory-mcp.
#
# Stage 1 runs on the same Ubuntu-based sandbox template the OpenCode workload uses,
# so the `--version` smoke test proves the binary's glibc/libstdc++ needs (glibc >= 2.38)
# are met at runtime. Stage 2 is `scratch`, so nothing else (apt state, /root dotfiles,
# the upstream updater script) leaks into the composed image.
ARG BASE_IMAGE=docker/sandbox-templates:shell-docker

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
# whenever the moving base template updates its package set; the binary itself is
# pinned and checksum-verified.
# hadolint ignore=DL3008
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64|arm64) MCP_ARCH="${TARGETARCH}" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl tar; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /out/usr/local/bin; \
    ARCHIVE="codebase-memory-mcp-linux-${MCP_ARCH}.tar.gz"; \
    BASE_URL="https://github.com/DeusData/codebase-memory-mcp/releases/download/v${MCP_VERSION}"; \
    curl --fail --show-error --location --retry 3 "${BASE_URL}/${ARCHIVE}" -o "${ARCHIVE}"; \
    curl --fail --show-error --location --retry 3 "${BASE_URL}/checksums.txt" -o checksums.txt; \
    test "$(awk -v f="${ARCHIVE}" '$2 == f' checksums.txt | wc -l)" -eq 1; \
    awk -v f="${ARCHIVE}" '$2 == f' checksums.txt | sha256sum --check --strict -; \
    tar -xzf "${ARCHIVE}" codebase-memory-mcp; \
    install -m 0755 codebase-memory-mcp /out/usr/local/bin/codebase-memory-mcp; \
    /out/usr/local/bin/codebase-memory-mcp --version

FROM scratch
COPY --from=build /out/ /
