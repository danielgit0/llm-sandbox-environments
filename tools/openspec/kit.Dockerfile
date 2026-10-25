# syntax=docker/dockerfile:1.7
FROM node:22.22.1-bookworm-slim@sha256:4f77a690f2f8946ab16fe1e791a3ac0667ae1c3575c3e4d0d4589e9ed5bfaf3d AS build

ARG OPENSPEC_VERSION=1.15.0

RUN npm install --global --prefix /out/usr/local \
      --no-audit --no-fund --ignore-scripts \
      "@fission-ai/openspec@${OPENSPEC_VERSION}" \
    && test -x /out/usr/local/bin/openspec \
    && /out/usr/local/bin/openspec --version

FROM scratch
COPY --from=build /out/ /
