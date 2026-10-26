<!-- markdownlint-disable MD041 -->

## Java / GraalVM

GraalVM Community JDK 25.0.1 is installed at `/opt/graalvm`; `java`, `javac`,
and the other JDK tools are on `PATH`. `JAVA_HOME` is set to `/opt/graalvm` by
the environment.

Use the project's Gradle wrapper (`./gradlew`) for build and test. The wrapper
may download Gradle and dependencies through the Java egress policy.
Native-image builds are not required for the normal JVM workflow.
