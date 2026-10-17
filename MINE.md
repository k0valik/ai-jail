# MINE.md — fork divergence manifest (`mine` branch)

This checkout is the `k0valik/ai-jail` fork, `mine` branch, tracking
`akitaonrails/ai-jail` (`upstream` remote). Everything in here documents
what we changed, why, and how to keep upstream merges painless.

## Scope

**This fork targets WSL2 and pure Linux only.** macOS/Darwin (seatbelt
backend), AUR/Homebrew packaging, release signing, and build/test/release CI
are explicitly out of scope and were removed or are simply ignored. The one
GitHub Actions workflow is fork maintenance: it syncs `master` from upstream
and opens or refreshes a PR into `mine`. Do not spend effort on
cross-platform concerns here; do not upstream anything.

## Relationship to upstream

- `origin` = `https://github.com/k0valik/ai-jail` (default branch: `mine`)
- `upstream` = `https://github.com/akitaonrails/ai-jail`
- **NEVER open upstream issues or PRs.** Changes live on `mine` only.
- `master` tracks upstream `master`. The `upstream-sync` Actions workflow
  fast-forwards fork `master` and opens or refreshes a PR into `mine`; review
  and merge that PR to integrate upstream changes into the fork. Locally, run
  `scripts/sync-upstream.sh` for a dry run or use `--push --pr --pr-base mine`
  to publish the update.
- To run the hosted workflow, enable GitHub Actions for this repository and
  allow Actions to create pull requests under Settings → Actions → General.
- Our touch points are small and additive, so conflicts should be rare. The
  files we deliberately touched upstream-hot code in:
  `src/sandbox/bwrap.rs` (two small insertions), `src/sandbox/mod.rs`
  (nothing yet), `src/cli.rs` + `src/config.rs` (one field each).

## Divergences from upstream (chronological)

| Commit | Change | Why |
| --- | --- | --- |
| `rename CLAUDE.md to AGENTS.md` | agent-agnostic guideline file | cross-agent (pi, codex, ...) |
| `chore(ci): remove GitHub Actions workflows` | no build/release CI runners | local builds only; fork-maintenance sync is the sole Actions workflow |
| `feat(sandbox): persistent /tmp leaves` | new `persistent_tmp` config field + `--persistent-tmp` flag | fresh `/tmp` per launch re-transpiles pi extensions every start; jiti/node-compile caches now persist in a jail-owned store |
| `fix(sandbox): drop command-binary re-binds beneath agent-state mounts` | group-14 exemption filtered against agent-state binds | codex's auto-update symlink (`current -> releases/<v>`) made bwrap refuse the mountpoint; killed every codex launch |
| `fix(sandbox): prefer /usr/local/bin/bwrap` | candidate order | local bwrap builds must override the distro package |
| `fix(pty): forward OSC 52 clipboard writes without terminal passthrough` | `OscForwarder` set/query split | jailed fullscreen TUIs (pi) had no copy/yank at all: OSC 52 was the only clipboard path (no DISPLAY inside) and the forwarder dropped it unless `--terminal-passthrough`; sets now always forward, clipboard-read queries stay gated |
| `fix(config): auto-save no longer creates command-only .ai-jail files` | `save_auto` command-only skip | upstream persists the positional command so bare `ai-jail` remembers the agent — that littered every project root with near-empty `.ai-jail` files; we only skip *creating* them, existing files still update |
| `fix(sandbox): force GIT_TERMINAL_PROMPT=0 in the sandbox` | forced setenv (normal + lockdown) | git's interactive `Username for 'https://github.com':` prompt runs on the PTY the jailed TUI owns → frozen terminal; now git fails fast; explicit `--env GIT_TERMINAL_PROMPT=...` still wins |
| `chore(fork): add scheduled upstream sync` | `.github/workflows/sync-upstream.yml`, `scripts/sync-upstream.sh`, `scripts/validate-sync.sh` | keep fork `master` fast-forwarded to upstream and maintain a review PR into `mine` |

## persistent_tmp (the one fork feature)

```toml
# ~/.ai-jail (trusted layer; project .ai-jail cannot enable it)
persistent_tmp = ["/tmp/jiti", "/tmp/node-compile-cache"]
```

Each entry is validated (absolute, under `/tmp`, simple components) and
backed by `~/.local/share/ai-jail/persistent-tmp/<slug>/`. Landlock
already grants `/tmp` read-write. CLI: `--persistent-tmp /tmp/jiti`
(repeatable). Never serialized into saved configs.

Note: pi 0.87 populates `node-compile-cache` (~2 MB, ~1 s faster second
run); it no longer writes a jiti cache to `$TMPDIR` (the 1.3 MB jiti
cache seen under the older hand-rolled wrapper came from an earlier pi).
The leaf stays — future pi versions land there automatically.

## Host prerequisites (WSL2, Ubuntu 24.04)

- **bubblewrap >= 0.13.0 at `/usr/local/bin/bwrap`** (Ubuntu ships 0.9.0
  without `--overlay-src`; ai-jail's copy-on-write `overlay_maps` needs
  it, and our candidate order prefers `/usr/local`):

  ```bash
  sudo apt install -y build-essential meson ninja-build libcap-dev pkg-config
  git clone https://github.com/containers/bubblewrap.git /tmp/bubblewrap
  cd /tmp/bubblewrap && git checkout v0.13.0
  meson setup build --prefix=/usr/local -Dselinux=disabled -Dman=disabled
  ninja -C build && sudo ninja -C build install
  ```

- AppArmor unprivileged-userns relaxation is in place on this host (the
  old hand-rolled bwrap sandbox worked, so it is already relaxed).

## Global config (`~/.ai-jail`, chezmoi-managed as `dot_ai-jail`)

Posture: **unrestricted network by default** (`network = true`), `no_mise`,
agent state RW (upstream default: `~/.pi`, `~/.codex`), WSL/TUI env
forwarded via `env_pass`, persistent tmp leaves.

pi's pnpm tree (`~/.local/share/pnpm`, where the `pi` binary + node
runtimes live) is mounted **copy-on-write**:

```toml
[commands.pi]
overlay_maps = ["~/.local/share/pnpm"]
```

Reads come from the warm host tree; in-jail package installs land in a
per-project overlay layer (`.ai-jail-overlays/`, masked) and never touch
the host. Requires bubblewrap >= 0.13 (`--overlay-src`). Without it, fall
back to `ro_maps = ["~/.local/share/pnpm"]` (works on 0.9.0; in-jail
installs stay read-only, and the toolchains feature prints a one-line
overlap warning it safely rejects).

## Quickstart

```bash
ai-jail pi                      # daily driver: unrestricted network
ai-jail codex                   # same for codex
ai-jail pi -- --webagent        # pi's own flags go after `--`
ai-jail --no-network pi         # fully offline
ai-jail --dry-run -- pi -v      # inspect the bwrap invocation
```

### Filtered egress (browser agent / web work)

Filtered mode keeps a private netns whose only egress is a CONNECT proxy
dials exactly the allowed hosts (subdomains included). No UDP, no DNS
inside the sandbox — the proxy resolves host-side, so HTTPS API clients
work; browsers need DNS unless given literal IPs, so prefer `--network`
for full-browser work.

```bash
# per-launch, on top of the default config:
ai-jail --allow-host api.tavily.com --allow-host api.exa.ai \
        --allow-host api.firecrawl.dev --allow-host github.com \
        --allow-host api.anthropic.com \
        pi -- --webagent

# or pin it in ~/.ai-jail:
[commands.pi-webagent]
command = ["pi"]
network = false
allow_hosts = [
  "api.tavily.com", "api.exa.ai", "api.firecrawl.dev",
  "github.com", "api.anthropic.com",
]
# then: ai-jail pi-webagent -- --webagent
```

The toolchain registry list (crates.io, npmjs, pypi, ...) is unioned in
automatically when toolchains are on. Tavily/Exa/Firecrawl are plain
HTTPS APIs, so CONNECT-only egress covers them.

### Chrome DevTools / Playwright

Headless Playwright: filtered egress can work if you enumerate the hosts
it touches (browser CDNs, your targets) — or just use `--network`.
Headed Chrome additionally needs `--display` (Wayland) or `--x11`, and
audio needs `--audio`.

## Known issues

- `tests/sandbox_escape.rs::netlink_route_is_blocked_without_network`
  fails on pristine upstream too on this host (WSL kernel/seccomp
  interaction). Pre-existing, not ours; ignore in test runs.
- `sandbox::bwrap::tests::persistent_tmp_dry_run_places_binds_after_tmpfs`
  is flaky on pristine upstream too (pid-named fake-home dirs in /tmp
  racing across test binaries). Pre-existing, not ours.
- pi 0.87: the `/tmp/jiti` leaf is currently unused (see above).
- `ai-jail status` and `--init` write per-project `.ai-jail` files; keep
  them tightening-only (they are untrusted by design). Ordinary runs no
  longer create one just to remember the command (see divergence table).
- For real GitHub auth inside the jail use `--github` (read-only
  `~/.config/gh`) and/or `--env GITHUB_TOKEN`; git now fails fast
  instead of prompting.
