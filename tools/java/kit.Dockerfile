# syntax=docker/dockerfile:1.7
FROM docker/sandbox-templates:shell-docker@sha256:b178ca62ec2e79af2a044e3ec321bdb72188690e1c15d573ea5524b397554d3d AS build

# hadolint ignore=DL3002
USER root

ARG GRAALVM_VERSION=25.0.1
# SHA-256 for graalvm-community-jdk-${GRAALVM_VERSION}_linux-aarch64_bin.tar.gz.
ARG GRAALVM_SHA256=7aa0b9935a80e67f37c6025678393dbd123bb6f2226811decbc1a13093fc8ae2

# hadolint ignore=DL4006,SC2016
RUN curl --fail --show-error --location --retry 3 \
      "https://github.com/graalvm/graalvm-ce-builds/releases/download/jdk-${GRAALVM_VERSION}/graalvm-community-jdk-${GRAALVM_VERSION}_linux-aarch64_bin.tar.gz" \
      -o /tmp/graalvm.tar.gz \
    && printf '%s  %s\n' "$GRAALVM_SHA256" /tmp/graalvm.tar.gz | sha256sum -c - \
    && top_dir="$(tar -tzf /tmp/graalvm.tar.gz | head -1 | cut -d/ -f1)" \
    && mkdir -p /out/opt \
    && tar -xzf /tmp/graalvm.tar.gz -C /out/opt \
    && mv "/out/opt/${top_dir}" /out/opt/graalvm \
    && rm -f /tmp/graalvm.tar.gz \
    && chown -R agent:agent /out/opt/graalvm \
    && mkdir -p /out/usr/local/bin /out/etc/profile.d \
    && for bin in /out/opt/graalvm/bin/*; do \
         name="$(basename "$bin")"; \
         ln -s "/opt/graalvm/bin/${name}" "/out/usr/local/bin/${name}"; \
       done \
    && printf '%s\n' \
         'export JAVA_HOME=/opt/graalvm' \
         'export PATH="/opt/graalvm/bin:$PATH"' > /out/etc/profile.d/java.sh \
    && JAVA_HOME=/out/opt/graalvm /out/opt/graalvm/bin/java -version

FROM scratch
COPY --from=build /out/ /
