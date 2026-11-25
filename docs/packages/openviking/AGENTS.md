# `openviking` (`artagon/aitools/openviking`) — Agent Guide

- **Kind:** Homebrew Formula (`Formula/openviking.rb`)
- **Upstream:** `https://github.com/volcengine/OpenViking` (`AGPL-3.0-only`)
- **Binaries:** `openviking`, `ov` (conflicts with Homebrew core `ov` pager), `openviking-server`, `openviking-gateway`
- **Passive assets:** `$(brew --prefix openviking)/share/openviking/` (`agent-plugins/`, `skills/` [7 skills], `plugins/{claude-code,codex,opencode,agent-hook}`, `examples/`, `.claude-plugin/`, `.agents/`)

## Configuration Paths & State

- **Server config (`ov.conf`):** Pass `--config /path/to/ov.conf` (or place at default config path). Template at `$(brew --prefix openviking)/share/openviking/examples/ov.conf.example`.
  - Default server port: `1933`; gateway port: `1935`; local bot gateway: `127.0.0.1:18790`.
  - Storage defaults: `storage.workspace: "./data"`, `vectordb.backend: "local"`, `agfs.backend: "local"`, `encryption.enabled: true` (`~/.openviking/master.key`).
  - Optional external backends (disabled/null by default): Volcengine VikingDB/KMS, S3, Redis, HashiCorp Vault, MinerU (`http://127.0.0.1:8000`).
- **CLI config (`ovcli.conf`):** Override via `OPENVIKING_CLI_CONFIG_FILE=/path/to/ovcli.conf` (default `url`: `http://localhost:1933`, `output`: `table`, `timeout`: `60.0`).
- **Required non-interactive env var:** `OPENVIKING_LANG=en` (or run `ov language en` once). Without a saved display language or `OPENVIKING_LANG`, non-interactive `ov`/`openviking` exits `2`.

## Defaults: Upstream vs. Tap-Hardened

| Behavior | Upstream Default | Tap (`artagon/aitools`) Default |
| :--- | :--- | :--- |
| `openviking-server` bind address | `0.0.0.0:1933` (example `ov.conf.example` also `0.0.0.0`) | Wrapper injects `--host "${OPENVIKING_HOST:-127.0.0.1}"` (unless `--host` or `init`/`doctor`/`ingest` passed); `ov.conf.example` patched to `127.0.0.1` |
| `openviking-gateway` bind address | Unconstrained default | Wrapper defaults `OPENVIKING_GATEWAY_HOST=127.0.0.1` |
| Telemetry & OpenTelemetry export | Prometheus enabled; OTel/LiteLLM/Scarf env vars unset | All 4 wrappers export `DO_NOT_TRACK=1`, `OTEL_SDK_DISABLED=true`, `OTEL_TRACES_EXPORTER=none`, `OTEL_METRICS_EXPORTER=none`, `OTEL_LOGS_EXPORTER=none`, `SCARF_NO_ANALYTICS=true`, `ANONYMIZED_TELEMETRY=false`, `LITELLM_LOCAL_MODEL_COST_MAP=True` |
| Self-updaters | None | Top-level `update`/`self-update`/`upgrade` blocked (`exit 2`); nested `ov skills update` / `ov watch update` preserved |
| `vikingbot` binary | Optional `[bot]` extra | Intentionally omitted from `bin/` to avoid extra runtime deps |

## Opt-In Setup & Agent Rules

1. **Always set `OPENVIKING_LANG=en`** in non-interactive agent shells (or persist once via `ov language en`).
2. **Avoid `./data` pollution:** Set an explicit absolute `storage.workspace` path (e.g. `~/.local/share/openviking/data`) in `ov.conf` before starting `openviking-server`.
3. **Start locally on loopback and verify health:**
   ```sh
   openviking-server --config ~/.config/openviking/ov.conf
   OPENVIKING_LANG=en openviking --output json health
   ```
4. **Binary conflict with `ov` pager:** If `homebrew/core`'s `ov` pager is installed, unlink one formula (`brew unlink ov`) before linking `openviking`.
5. **Opt-in agent plugins/skills:** Register explicitly from `$(brew --prefix openviking)/share/openviking/{skills,plugins,agent-plugins}`.
6. **Security note:** Do not expose `openviking-server` beyond `127.0.0.1` without setting `server.root_api_key` and restricting `server.cors_origins` (upstream example sets `["*"]`).
