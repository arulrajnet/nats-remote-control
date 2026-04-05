# NATS CLI Web Shell

## Description

A browser-accessible interactive shell for the NATS CLI, exposed via [ttyd](https://github.com/tsl0922/ttyd). Users can publish messages, subscribe to subjects, and manage JetStream streams directly from a web browser — without installing any local tooling. The shell wraps the `nats` binary in a bash eval loop with readline support, persistent history, and safe Ctrl+C handling.

---

## Key Functionalities

- **Command prefix omission** — commands are typed without the `nats` prefix (e.g., `pub topic hello` instead of `nats pub topic hello`)
- **Readline editing** — arrow-key navigation, line editing, and history recall via rlwrap
- **Persistent command history** — rlwrap history stored on a Docker named volume; survives container restarts and image rebuilds
- **Ctrl+C interrupt** — stops the current running command (e.g., a subscription) without killing the shell session; prints `(Stopped)` on interrupt
- **Blocking command hints** — `sub`, `subscribe`, `bench`, and `reply` display a `(Blocking — press Ctrl+C to stop)` hint before executing
- **Screen clear** — `clear` or `cls` clears the terminal using ANSI escape codes
- **Quoted argument handling** — arguments with spaces or special characters (e.g., `pub topic "hello world"`) are parsed correctly via bash's `eval "args=($cmd)"`
- **System command guard** — `server` and `auth` subcommands print an informational message instead of failing silently, directing users to the monitoring dashboard
- **Session persistence** — typing `exit` or `quit` keeps the session alive; disconnect by closing the browser tab

---

## User Flow

1. Open `http://localhost:7681` in a browser.
2. The shell displays the connected NATS URL and a list of example commands.
3. Type commands **without** the `nats` prefix:
   ```
   nats> pub orders.new '{"id": 1}'
   nats> subscribe orders.>
   nats> stream ls
   nats> kv ls
   ```
4. For blocking commands (`subscribe`, `bench`, `reply`), press **Ctrl+C** to stop and return to the prompt.
5. Use **↑ / ↓** arrow keys to navigate command history. History is saved across sessions.
6. Type `clear` or `cls` to clear the screen.
7. Type `help` to see all available nats-cli commands.
8. Close the browser tab to disconnect. The shell session remains alive on the server.

---

## Technical Implementation

### Shell script — `nats-cli/nats-eval.sh`

| Concern | Approach |
|---|---|
| Readline support | `rlwrap -a -pGreen` wraps the script; `-H /data/.nats_history` for persistent history |
| Prompt injection | `-S` flag intentionally omitted from rlwrap; `printf "nats> "` is printed by the script so rlwrap never injects a prompt mid-output (e.g., during subscription) |
| Argument parsing | `eval "args=($cmd)"` — bash native word-splitting handles quoted strings without invoking xargs |
| SIGINT handling | Parent shell: `trap '' SIGINT` (loop survives Ctrl+C); child process: `(trap - SIGINT; exec nats ...)` resets to default so the `nats` binary receives SIGINT correctly |
| Ctrl+C message | Exit code `130` (SIGINT) detected after the subshell exits; prints `\n(Stopped)` |
| Screen clear | `printf '\033[2J\033[H'` — no dependency on the `clear` binary |
| NATS URL | Read from `NATS_URL` environment variable; nats-cli picks it up automatically, no `--server` flag needed |

### Docker Compose services

| Service | Image | Port | Purpose |
|---|---|---|---|
| `nats` | `nats:{version}` | 4222 / 8222 | NATS server with JetStream (`-js`) and HTTP monitoring |
| `nats-cli` | `arulrajnet/nats-cli:0.3.0` | 7681 | ttyd → nats-eval.sh → nats binary |
| `nats-dashboard` | `mdawar/nats-dashboard` | 8000 | Web UI for server monitoring |

### Dockerfile (`nats-cli/Dockerfile`)

- **Stage 1** (`curlimages/curl`): downloads `ttyd` and `nats` binaries for the target architecture (supports `x86_64`, `aarch64`, `armv7l`)
- **Stage 2** (`alpine:3.19`): installs `rlwrap` and `bash`; copies binaries and `nats-eval.sh`
- `CMD`: `ttyd --port 7681 --writable nats-eval.sh`

### Persistent history

rlwrap writes command history to `/data/.nats_history` inside the container. The `/data` directory is backed by the `nats_cli_data` Docker named volume, which persists independently of the container lifecycle.

```
nats_cli_data volume → /data/.nats_history (inside container)
```

---

## Non-Functional Requirements

| Requirement | Detail |
|---|---|
| **Portability** | Multi-arch Docker image (amd64, arm64, armv7) |
| **Resilience** | Shell loop survives Ctrl+C and accidental `exit`/`quit` commands |
| **Correctness** | Quoted arguments (`pub topic "hello world"`) passed correctly to nats binary |
| **History durability** | Command history survives container restarts via named volume |
| **No auth leakage** | `NATS_URL` carries no credentials for the default anonymous connection |

---

## Open Questions / Decisions

| Topic | Decision / Status |
|---|---|
| **Shell vs Go REPL** | Bash chosen for simplicity; Go alternative (using `nats.go` library directly) was considered but adds complexity without clear benefit for the current scope |
| **`server info` / `server ping`** | Requires a NATS system account with credentials. Not configured by default — the shell intercepts these commands and redirects users to the dashboard at `http://localhost:8000` |
| **Authentication** | Currently anonymous (`no_auth_user`-style, default NATS server with no accounts configured). Credentials support can be added by extending `NATS_URL` to `nats://user:pass@nats:4222` |
| **Tab completion** | Not implemented. rlwrap supports completion via `-f wordlist` but nats-cli subcommand list would need to be maintained manually |
