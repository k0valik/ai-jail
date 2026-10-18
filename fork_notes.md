# Fork audit notes

Audit and rebuild record for `k0valik/ai-jail:mine`. This note records why
each fork difference is retained or removed; `MINE.md` is the shorter
operator-facing guide.

## Comparison point

- Original `mine`/`origin/mine`: `1c2594d8bbfceb6cf9ec314962c87837e41b019e`.
- Upstream base: `akitaonrails/ai-jail:master` at
  `7dfd34ff66b914a41b05f79b12b6b117d5ce9fe0`.
- Original branch had 24 commits ahead and no commits behind upstream.
- Rebuild started in a separate worktree from that upstream commit. The old
  branch is preserved locally as `archive/mine-pre-clean-20261018`, with a Git
  bundle at `/tmp/ai-jail-mine-pre-clean-20261018.bundle`.

## Retained product and test changes

### Persistent `/tmp` leaves

Keep this as the only fork-specific runtime feature in the rebuilt source.
Upstream has no equivalent flag, config field, mount behavior, or matching
issue/PR at the comparison point. Pi receives `/tmp/jiti` by default so jailed
Pi agents can reuse the Jiti cache; `--no-persistent-tmp` opts out for one
launch. Other selected leaves remain opt-in through trusted global config or
the CLI. All persisted leaves use a jail-owned store under
`~/.local/share/ai-jail/persistent-tmp/`.

The implementation accepts trusted global config and repeatable CLI flags,
ignores project-config attempts, validates paths below `/tmp`, refuses
symlinked store parents, creates missing parents safely on first use, and emits
binds after the `/tmp` tmpfs. Regression coverage belongs in
`tests/fork_features.rs` and the relevant unit tests.

### Isolated integration-test HOME

Keep `TestHome` and convert ordinary ai-jail integration launches to use it.
The CLI reads trusted global config even with `--clean`, so inheriting a
developer's global config made integration tests host-dependent. Tests that
exercise global config, missing HOME, or their own fixture HOME remain explicit.

## Behavior moved to user config

These fork patches duplicate supported upstream configuration or behavior and
are removed from the rebuilt product source:

| Removed fork behavior | User config / upstream status |
| --- | --- |
| OpenCode `--standalone` injection and argument parser | Upstream supports a command override; configured globally as `[commands.opencode] command = ["opencode", "--standalone"]`. |
| Skip only command-only auto-saves | No narrow upstream setting exists. User chose global `no_save_config = true`, which disables all automatic project config writes and replaces the narrower fork behavior. |
| Forward OSC 52 set forms without terminal passthrough | Upstream's `terminal_passthrough` option is enabled globally; upstream intentionally keeps it opt-in. |
| Force `GIT_TERMINAL_PROMPT=0` in bwrap | `env_pass = ["GIT_TERMINAL_PROMPT=0"]` is configured globally. |
| Prefer `/usr/local/bin/bwrap` during discovery | `BWRAP_BIN=/usr/local/bin/bwrap` is exported in shell startup; upstream supports `BWRAP_BIN`. |
| Broad Codex command-path filter | Superseded by upstream's symlink-aware mount handling; no local production patch is needed. |

The live global config and chezmoi source are private (mode `0600`). Changes
were pushed to `k0valik/dotfiles`: OpenCode override in `92cb277`, then
`no_save_config = true` in `907f6ba`.

## Fork repository operations retained

- `AGENTS.md` replaces upstream's `CLAUDE.md` as the agent-neutral project
  guide.
- Linux PR checks, Linux x86_64 artifact build/attestation, and upstream sync
  automation remain fork policy, not product behavior.
- The upstream release workflow is removed because this fork does not publish
  packages, macOS artifacts, or GitHub releases.
- `.gitignore`, sync scripts, the maintenance skill, `MINE.md`, and these audit
  notes document and support the fork's workflow.

## Rebuild commit plan

The clean branch is based directly on the fetched upstream commit. Current
rebuild commits:

1. `feat(sandbox): persist selected /tmp leaves`
2. `test: isolate subprocesses from global config`

Planned remaining commits group Linux CI/build, upstream sync automation, and
the rewritten fork docs. Do not update the published `mine` ref until the full
diff, checks, and commit list have been reviewed. Preserve the archive branch
and bundle as rollback points.

## Upstream publication rule

Upstream issues and PRs are not part of normal maintenance. Follow `AGENTS.md`;
do not publish upstream discussions under the current project instructions.
