# syntax=docker/dockerfile:1.7
FROM docker/sandbox-templates:shell-docker@sha256:b178ca62ec2e79af2a044e3ec321bdb72188690e1c15d573ea5524b397554d3d AS build

# hadolint ignore=DL3002
USER root

ARG DART_VERSION=3.13.5
ARG DART_SHA256=19a731647c3ed55058ee46dde00330150e6a8729bb6121b4a31e86084c8a3e6d
ARG DART_MCP_VERSION=1.2.1

# hadolint ignore=DL4006
RUN curl --fail --show-error --location --retry 3 \
      "https://storage.googleapis.com/dart-archive/channels/stable/release/${DART_VERSION}/sdk/dartsdk-linux-arm64-release.zip" \
      -o /tmp/dart-sdk.zip \
    && printf '%s  %s\n' "$DART_SHA256" /tmp/dart-sdk.zip | sha256sum -c - \
    && mkdir -p /out/opt \
    && unzip -q /tmp/dart-sdk.zip -d /out/opt \
    && rm -f /tmp/dart-sdk.zip \
    && chown -R agent:agent /out/opt/dart-sdk \
    && mkdir -p /out/usr/local/bin /out/opt/dart-pub-cache \
    && ln -s /opt/dart-sdk/bin/dart /out/usr/local/bin/dart \
    && PUB_CACHE=/out/opt/dart-pub-cache \
       /out/opt/dart-sdk/bin/dart pub global activate dart_mcp_server "${DART_MCP_VERSION}" \
    && PUB_CACHE=/out/opt/dart-pub-cache \
       /out/opt/dart-sdk/bin/dart pub global list \
    && PUB_CACHE=/out/opt/dart-pub-cache \
       /out/opt/dart-sdk/bin/dart pub global run dart_mcp_server --help \
    && chown -R agent:agent /out/opt/dart-pub-cache

RUN printf '%s\n' \
      '#!/bin/sh' \
      'export PUB_CACHE=/opt/dart-pub-cache' \
      'exec /opt/dart-sdk/bin/dart pub global run dart_mcp_server --disable flutter "$@"' \
      > /out/usr/local/bin/dart-mcp-server \
    && chmod 0755 /out/usr/local/bin/dart-mcp-server

FROM scratch
COPY --from=build /out/ /
COPY mcp.patch.yml /opt/dart-mcp/mcp.patch.yml
