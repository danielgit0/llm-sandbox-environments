# GraalVM JDK 25 mixin

Installs GraalVM Community JDK 25.0.1 for Linux arm64 sandboxes.

- Archive:
  `graalvm-community-jdk-25.0.1_linux-aarch64_bin.tar.gz`
- SHA-256:
  `7aa0b9935a80e67f37c6025678393dbd123bb6f2226811decbc1a13093fc8ae2`
- Location: `/opt/graalvm`
- `JAVA_HOME` is supplied by the sandbox environment
- Native image capability is included in GraalVM but not required by this setup

The mixin is arm64-only, matching the local Docker Sandbox. The project's
Gradle wrapper remains authoritative; this image does not install a separate
Gradle distribution.
