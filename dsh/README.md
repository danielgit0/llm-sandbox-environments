# DeepSeek Harness workload

Experimental v3 workload that runs the DSH web UI in a Docker Sandbox.

- `uv` builds Python 3.12.15 and installs `deepseek-harness-sdk==0.2.1rc2`
  from `uv.lock`; pip is not used.
- The entrypoint binds `dsh web` to the sandbox interface and publishes port
  3000 on host loopback.
- Model calls go through the host LiteLLM gateway. No DeepSeek key is placed
  in the sandbox.
- `dsh web` prints a one-time authentication URL with a token. It is written
  to `/home/agent/.dsh/web.log`:

  ```bash
  sbx exec dsh-sandbox cat /home/agent/.dsh/web.log
  ```

  Replace the sandbox IP in that URL with `127.0.0.1:3000`, keeping the token.

The web profile currently logs two optional activation warnings
(`dsh-host-directory-picker` and `libreoffice-kit`). The core agent and UI
start; those optional entries are not installed by the SDK wheel.

Validation:

```bash
../scripts/uv lock --check
docker buildx build --platform linux/arm64 -f kit.Dockerfile \
  -t local/dsh:spike .
docker run --rm --platform linux/arm64 -p 3000:3000 local/dsh:spike
```
