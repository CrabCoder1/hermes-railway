#!/usr/bin/env bash
# Launches both the admin server (background, internal port 8081) and
# hermes-webui (foreground, on Railway's public $PORT).
#
# Railway health-checks the public $PORT, so WebUI's /health is what answers.
# The admin server is reachable only from inside the container.

set -e

# ── Public-facing WebUI port ────────────────────────────────────────────────
# Railway injects $PORT. WebUI reads HERMES_WEBUI_PORT.
export HERMES_WEBUI_PORT="${PORT:-8787}"

# ── Admin server port (internal only) ───────────────────────────────────────
# /app/server.py reads os.environ["PORT"] for its own port.
# We override $PORT just for the admin server so WebUI keeps the public one.
export PORT=8081

# ── Background: admin server (also auto-starts `hermes gateway` subprocess) ─
echo "[start.sh] Launching admin server on internal port ${PORT}..."
python /app/server.py &
ADMIN_PID=$!

# Forward signals so Railway shutdowns are clean
trap "kill -TERM ${ADMIN_PID} 2>/dev/null; exit 0" TERM INT

# Give the admin server a moment to spin up before WebUI starts
sleep 2

# ── Foreground: hermes-webui on the public port ─────────────────────────────
# cd into hermes-agent so run_agent.py's relative imports resolve.
echo "[start.sh] Launching hermes-webui on public port ${HERMES_WEBUI_PORT}..."
cd /opt/hermes-agent
exec python /opt/hermes-webui/server.py
