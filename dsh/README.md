# DeepSeek Harness workload

Experimental v3 workload that runs DSH's ACP profile inside a Docker Sandbox
for IntelliJ.

- `uv` builds Python 3.12.15 and installs `deepseek-harness-sdk==0.2.1rc2`
  from `uv.lock`; pip is not used.
- The sandbox entrypoint is a keepalive. IntelliJ launches
  `dsh --profile acp` through `scripts/dsh-acp-sandbox.sh`, which bridges
  ACP stdio into the sandbox with `sbx exec -i`.
- Model calls go through the host LiteLLM gateway. No DeepSeek key is placed
  in the sandbox. `acp.patch.yml` defaults the ACP model to `qwen-coder`;
  change it after enabling a hosted model in LiteLLM.
- The SDK's `web` profile in 0.2.1rc2 is incomplete (missing directory-picker
  peers). ACP does not depend on those packages and is the supported interface.

IntelliJ configuration (`~/.jetbrains/acp.json`):

```json
{
  "agent_servers": {
    "DSH Sandbox": {
      "command": "/Users/daniel/Documents/projects/opencode-sandbox/scripts/dsh-acp-sandbox.sh",
      "args": []
    }
  }
}
```

Validation:

```bash
../scripts/uv lock --check
docker buildx build --platform linux/arm64 -f kit.Dockerfile \
  -t local/dsh:spike .
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,"clientCapabilities":{}}}' \
  | ../scripts/dsh-acp-sandbox.sh
```
