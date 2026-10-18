# `mine` fork guide

This branch belongs to `k0valik/ai-jail` and tracks
`akitaonrails/ai-jail` through the `master` branch. `upstream/master` is the
base for this branch; the scheduled sync workflow opens a review PR from the
fork's `master` into `mine`.

## Scope

This fork is maintained for WSL2 and Linux x86_64. It keeps Linux pull request
checks, an attested Linux binary artifact, and upstream sync automation. It
does not publish releases, packages, Homebrew formulas, or macOS artifacts.
Version tags stay aligned with upstream.

## Fork-only behavior

The product change retained on `mine` is optional persistence for selected
`/tmp` cache leaves. It is configured only in trusted global config or on the
command line; project `.ai-jail` files cannot enable it.

```toml
persistent_tmp = ["/tmp/jiti", "/tmp/node-compile-cache"]
```

```sh
ai-jail --persistent-tmp /tmp/jiti pi
```

Each path must be a simple absolute path below `/tmp`. Its backing directory is
stored under `~/.local/share/ai-jail/persistent-tmp/`, created without
following symlinked parents, and mounted after the sandbox `/tmp` tmpfs. This
keeps selected caches across launches without sharing the host `/tmp` tree.

Integration tests also isolate the child process `HOME`. `--clean` still reads
trusted global config, so integration tests must not inherit a developer's
global `~/.ai-jail` settings unless a test is explicitly exercising them.

## Personal settings covered by upstream

The following preferences are configured for this host and do not need fork
patches:

- OpenCode standalone mode: `[commands.opencode] command = ["opencode", "--standalone"]`.
- Disable automatic project config writes: `no_save_config = true`.
- Forward OSC 52 through terminal passthrough: `terminal_passthrough = true`.
- Fail Git credential prompts fast: `env_pass = ["GIT_TERMINAL_PROMPT=0"]`.
- Select the local bubblewrap build: `BWRAP_BIN=/usr/local/bin/bwrap`.

`no_save_config = true` disables all automatic project config writes, including
writes that contain settings beyond the remembered command. `--save-config`
can opt a particular invocation back in. Upstream documents OpenCode's
`command` override in global config; `BWRAP_BIN` is its supported binary
selection override.

## Fork maintenance

- Fork-only black-box regressions belong in `tests/fork_features.rs` when
  possible.
- Run `cargo fmt --check`, `cargo clippy --locked --all-targets -- -D warnings`,
  `cargo test --locked --features test-hooks`, and
  `cargo build --locked --release` before accepting a behavior change.
- `.github/workflows/ci.yml` checks pull requests targeting `mine`.
  `.github/workflows/build-linux.yml` validates source/build changes pushed to
  `mine`, then packages, checksums, and attests the Linux x86_64 artifact.
- `.github/workflows/sync-upstream.yml` fast-forwards the fork's `master` and
  creates or refreshes its review PR into `mine`.
- Upstream issues and PRs are not part of the normal fork workflow. Follow
  `AGENTS.md` and get the user's explicit authorization before any upstream
  publication.
