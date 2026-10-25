# OpenSpec CLI mixin

Installs OpenSpec 1.15.0 into the sandbox image.

- Package: `@fission-ai/openspec@1.15.0` (MIT)
- Runtime: the sandbox's Node.js, which must satisfy `>=20.19.0`
- Command: `openspec`
- The package is installed with `--ignore-scripts`; the image uses the
  pinned Node 22 build stage only to fetch and lay out the CLI.

Initialize each project from inside the sandbox:

```bash
openspec init
openspec list
```

Do not add OpenSpec as an MCP server; it is a CLI the agent runs in the
mounted project.
