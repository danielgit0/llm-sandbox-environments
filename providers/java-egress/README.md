# Java/Gradle egress

Allows the sandbox to fetch the Gradle wrapper distribution and resolve
dependencies from Maven Central, the Gradle Plugin Portal, and Google Maven.

The project's Gradle wrapper controls the Gradle version. This kit does not
install Gradle itself.

Add any private repository or additional host explicitly; do not add broad
provider egress.
