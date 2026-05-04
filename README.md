# hermes-railway

Hermes Agent + Hermes WebUI deployed together on Railway as a single Docker service.

Based on [`praveen-ks-2001/hermes-agent-template`](https://github.com/praveen-ks-2001/hermes-agent-template), modified to also run [`nesquena/hermes-webui`](https://github.com/nesquena/hermes-webui) in the same container.

## What you get

- **Public URL** (Railway-generated domain) → hermes-webui chat interface, file browser, sessions, skills, memory.
- **Internal admin server** → manages env vars, runs the messaging gateway (Telegram/Discord/Slack/Matrix/etc.) as a subprocess. Not exposed publicly.
- **Persistent state** in a Railway Volume so sessions/memory survive redeploys.

## Deploy

1. **Fork or clone this repo** to your own GitHub account.
2. **Create a Railway service** pointed at your fork (New Project → Deploy from GitHub repo).
3. **Add a Volume** to the service, mounted at `/data`.
4. **Set environment variables** in the Variables tab:
   - `LLM_MODEL` — e.g. `openai/gpt-4o-mini`
   - At least one provider API key, e.g. `OPENROUTER_API_KEY` or `OPENAI_API_KEY`
   - `ADMIN_USERNAME` and `ADMIN_PASSWORD` (for the admin UI; see below)
   - `HERMES_WEBUI_DEFAULT_MODEL` — same as `LLM_MODEL`
5. **Generate a public domain** (Settings → Networking → Generate Domain).
6. Wait for the build (~5–10 min on first deploy) and visit the domain.

## What's where

- **Public domain** → hermes-webui chat UI.
- **Admin UI** → only accessible from inside the container (port 8081). You generally don't need it because Railway's Variables tab covers env-var management. If you need it for messaging-channel pairing, see `CLAUDE.md`.

## Configuration

See `CLAUDE.md` for full environment variable reference, architecture details, and gotchas.

## Files

- `Dockerfile` — clones hermes-agent and hermes-webui, installs both
- `start.sh` — launches admin server (background, port 8081) and WebUI (foreground, `$PORT`)
- `server.py` — admin server from upstream template
- `templates/` — admin UI HTML
- `railway.toml` — Railway build/deploy config
- `requirements.txt` — admin server Python deps
- `CLAUDE.md` — architecture context for working on this repo

## License

Inherits licensing from the upstream repos. See those for details.
