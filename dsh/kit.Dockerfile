# syntax=docker/dockerfile:1.7
FROM ghcr.io/astral-sh/uv:0.13.5@sha256:32a7bb39b496babbd997b0a39a4d66c126bdaf5661b302bf6f06abda8deca6ff AS uv

FROM docker/sandbox-templates:shell-docker@sha256:b178ca62ec2e79af2a044e3ec321bdb72188690e1c15d573ea5524b397554d3d

USER root
COPY --from=uv /uv /uvx /usr/local/bin/

ENV UV_PYTHON_INSTALL_DIR=/opt/python \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_CACHE_DIR=/tmp/uv-cache

RUN uv --version \
    && uv python install 3.12.15

WORKDIR /opt/dsh
COPY pyproject.toml uv.lock .python-version ./
RUN uv sync --frozen --no-dev --python 3.12.15 \
    && chmod -R a+rX /opt/dsh /opt/python \
    && rm -rf "$UV_CACHE_DIR"

ENV PATH="/opt/dsh/.venv/bin:$PATH" \
    UV_PYTHON_DOWNLOADS=never \
    DSH_HOME=/home/agent/.dsh

RUN mkdir -p /home/agent/workspace /home/agent/.dsh \
    && chown -R agent:agent /home/agent

USER agent
RUN dsh --profile acp --dump-default-config >/dev/null
COPY --chown=agent:agent acp.patch.yml /home/agent/.dsh/profiles/acp/cordis.patch.yml
WORKDIR /home/agent/workspace

# IntelliJ starts `dsh --profile acp` through scripts/dsh-acp-sandbox.sh.
# Keep the sandbox alive between ACP sessions.
ENTRYPOINT ["sleep", "infinity"]
