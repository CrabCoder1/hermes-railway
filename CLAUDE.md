# Hermes + Hermes WebUI on Railway

## What this repo is

A fork of [`praveen-ks-2001/hermes-agent-template`](https://github.com/praveen-ks-2001/hermes-agent-template) modified to **also run [`nesquena/hermes-webui`](https://github.com/nesquena/hermes-webui)** in the same Railway service. One container, two processes, one shared `~/.hermes` directory.

Deployed to Railway as a single Docker service.

## Why this is non-trivial

`hermes-webui` was designed to run on the same host as `hermes-agent`, sharing its Python environment. It imports `run_agent.py` directly (in-process), not over HTTP. So you cannot point a separately-deployed WebUI at a separately-deployed gateway — they have to live in the same filesystem and Python environment.

The original template runs only `hermes gateway` (the messaging-channels backend: Telegram, Discord, Slack, etc.) plus a small admin UI on `$PORT`. This fork adds hermes-webui as the public-facing chat interface, demotes the admin server to an internal port, and exposes WebUI on Railway's `$PORT` instead.

## Architecture inside the container

```
Railway $PORT (public, HTTPS via Railway proxy)
        │
        ▼
┌───────────────────────────────────┐
│ hermes-webui (foreground process) │  ← chat UI, sessions, file browser
│ /opt/hermes-webui/server.py       │
└───────────────────────────────────┘
        │ imports run_agent.py from
        ▼
┌───────────────────────────────────┐
│ /opt/hermes-agent (Python pkg)    │  ← installed via `uv pip install -e .[all]`
└───────────────────────────────────┘
        │ shares state with
        ▼
┌───────────────────────────────────┐
│ /data/.hermes (Railway Volume)    │  ← sessions, memory, skills, approvals
└───────────────────────────────────┘
        ▲
        │ also writes to
┌───────────────────────────────────┐
│ admin server (background)         │  ← /app/server.py, port 8081 internal
│  └─ spawns `hermes gateway`       │  ← Telegram/Discord/Slack subprocess
└───────────────────────────────────┘
```

The admin server is what the original template was built around. It manages env vars, runs the gateway as a subprocess, and handles pairing codes for messaging channels. We keep it because the messaging-channel features depend on it. We just don't expose it publicly.

## Critical paths

| Path | Purpose |
|---|---|
| `/opt/hermes-agent` | hermes-agent checkout, installed as a Python package. **Don't move this** — `HERMES_WEBUI_AGENT_DIR` points here. |
| `/opt/hermes-webui` | hermes-webui checkout. Run via `python /opt/hermes-webui/server.py`. |
| `/app/server.py` | Admin server (from original template). |
| `/app/templates/` | Jinja templates for admin UI. **Required** — admin server crashes without this. |
| `/data/.hermes` | All persistent state. Mount the Railway Volume here. |
| `/data/workspace` | Default WebUI workspace (file browser root). |

## Process startup

`/app/start.sh` does:

1. Sets `HERMES_WEBUI_PORT=$PORT` (Railway's port) — that's what WebUI listens on publicly.
2. Sets `PORT=8081` for the admin server (it reads `os.environ["PORT"]` directly).
3. Backgrounds `python /app/server.py` (admin + gateway).
4. `cd /opt/hermes-agent` (required for `run_agent.py`'s relative imports).
5. `exec python /opt/hermes-webui/server.py` (foreground — Railway health-checks this).

Health check is `GET /health` which both services expose. Railway hits the public `$PORT`, so the WebUI is what answers.

## Required environment variables

Set these in Railway's **Variables** tab:

| Variable | Required? | Notes |
|---|---|---|
| `LLM_MODEL` | yes | e.g. `openai/gpt-4o-mini`, `anthropic/claude-sonnet-4-5`, etc. |
| `OPENROUTER_API_KEY` *(or other provider)* | yes | At least one provider key. Without it the gateway won't start. See `.env.example` for the full list (DeepSeek, GLM, Kimi, etc.) |
| `ADMIN_USERNAME` | recommended | Defaults to `admin`. |
| `ADMIN_PASSWORD` | recommended | If unset, a random one is generated and printed to logs only on first boot. |
| `HERMES_WEBUI_DEFAULT_MODEL` | optional | Same value as `LLM_MODEL` so the dropdown defaults sensibly. |

Messaging channel tokens (`TELEGRAM_BOT_TOKEN`, `DISCORD_BOT_TOKEN`, `SLACK_BOT_TOKEN`, etc.) are optional — only needed if you want those channels active.

## Railway-specific setup checklist

- [ ] Service source pointed at this fork
- [ ] Volume created and mounted at `/data` (otherwise sessions wipe on every redeploy)
- [ ] Required env vars set
- [ ] Public domain generated (Settings → Networking → Generate Domain)
- [ ] Health check path: `/health` (already in `railway.toml`)

First build is slow — 5–10 minutes — because it clones hermes-agent and pip-installs the `[all]` extras. Subsequent builds reuse Docker layers.

## Common gotchas

- **Gateway never starts**: check logs for `No provider key found`. Set a provider API key env var.
- **Admin password unknown**: if `ADMIN_PASSWORD` isn't set, the random one is only printed to deploy logs on first boot. Just set it explicitly.
- **WebUI loads but model calls fail**: gateway didn't start (see above), or the model name in `LLM_MODEL` doesn't match what your provider key supports. Format is `provider/model`, e.g. `openai/gpt-4o-mini`.
- **Templates not found error from admin server**: the `COPY templates/ /app/templates/` line in the Dockerfile must remain. Don't drop it.
- **State wipes on redeploy**: volume isn't mounted at `/data`, or `HERMES_HOME` env var doesn't point inside the volume.
- **WebUI can't find agent**: `HERMES_WEBUI_AGENT_DIR` must be `/opt/hermes-agent` and that directory must contain `run_agent.py`. Verify with `docker exec ls /opt/hermes-agent/run_agent.py` (or check build logs).

## Local development

This repo is built to run on Railway, not locally. If you want to test changes before pushing:

```bash
docker build -t hermes-railway .
docker run --rm -p 8787:8787 \
  -e PORT=8787 \
  -e LLM_MODEL=openai/gpt-4o-mini \
  -e OPENROUTER_API_KEY=sk-... \
  -e ADMIN_PASSWORD=test \
  -v hermes-data:/data \
  hermes-railway
```

Then visit `http://localhost:8787`.

## When making changes

- Editing `Dockerfile`: triggers a full rebuild (slow, ~10min).
- Editing `start.sh`, `server.py`, `templates/`: rebuilds but Docker layer cache makes it fast.
- Editing env vars in Railway: redeploys without rebuilding.
- The two upstream repos (`hermes-agent`, `hermes-webui`) are cloned `--depth 1` at build time, so they pin to whatever `HEAD` is at build time. If you need a specific version, change the `git clone` lines in the Dockerfile to use `--branch <tag>` or check out a specific SHA.

## Upstream repos

- `hermes-agent`: https://github.com/NousResearch/hermes-agent
- `hermes-webui`: https://github.com/nesquena/hermes-webui (note: branch is `master`, not `main`)
- Original template: https://github.com/praveen-ks-2001/hermes-agent-template

## Tasks Claude Code may be asked to do

- Pin the upstream repos to specific commits/tags (edit Dockerfile `git clone` lines).
- Add additional Python dependencies (edit `requirements.txt`).
- Move the admin UI behind a Railway private network instead of just a different port.
- Switch to a different LLM provider (mostly an env-var change, but check the provider list in `.env.example`).
- Add a second Railway service for hermes-webui only, sharing a volume with this one (this is harder — see "Path B" considerations: WebUI still needs hermes-agent installed in its image, and concurrent writes to shared SQLite-style files in `/data/.hermes` from both containers can corrupt state).
