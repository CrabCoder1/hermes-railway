FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates git && \
    rm -rf /var/lib/apt/lists/*

# ── Install hermes-agent as an editable Python package at a stable path ──
# WebUI imports run_agent.py from this directory, so the path matters.
RUN git clone --depth 1 https://github.com/NousResearch/hermes-agent.git /opt/hermes-agent && \
    cd /opt/hermes-agent && \
    uv pip install --system --no-cache -e ".[all]" && \
    rm -rf /opt/hermes-agent/.git

# ── Install hermes-webui ──
# Note: hermes-webui's default branch is `master`, not `main`.
RUN git clone --depth 1 https://github.com/nesquena/hermes-webui.git /opt/hermes-webui && \
    uv pip install --system --no-cache -r /opt/hermes-webui/requirements.txt && \
    rm -rf /opt/hermes-webui/.git

# ── Admin server deps (Starlette, Jinja2, uvicorn) ──
COPY requirements.txt /app/requirements.txt
RUN uv pip install --system --no-cache -r /app/requirements.txt

# ── Persistent state directory (mount Railway Volume here) ──
RUN mkdir -p /data/.hermes /data/workspace

# ── Admin server files ──
COPY server.py        /app/server.py
COPY templates/       /app/templates/
COPY start.sh         /app/start.sh
RUN chmod +x /app/start.sh

# ── Environment ──
ENV HOME=/data
ENV HERMES_HOME=/data/.hermes

# WebUI config — point at the cloned hermes-agent and into our state dir
ENV HERMES_WEBUI_AGENT_DIR=/opt/hermes-agent
ENV HERMES_WEBUI_STATE_DIR=/data/.hermes/webui
ENV HERMES_WEBUI_DEFAULT_WORKSPACE=/data/workspace
ENV HERMES_WEBUI_HOST=0.0.0.0

CMD ["/app/start.sh"]
