---
name: upstream-maintenance
description: Maintain the ai-jail fork against upstream, preserve confirmed local behavior, and validate fork changes.
---

# ai-jail fork maintenance

Use this workflow for upstream syncs, behavior changes that may overlap
upstream, and reviews of fork-only code.

## Before changing code

1. Read `AGENTS.md`, `MINE.md`, and the relevant fork notes. Inspect the work
   tree and branch refs; preserve unrelated user changes.
2. Fetch current upstream and compare the affected code, tests, CLI, config,
   documentation, and relevant issue/PR history. Check whether upstream already
   fixes the behavior or offers a config option. A fork convenience is not an
   upstream defect.
3. Review the full changed function and nearby call paths. Keep only confirmed
   fork behavior that remains necessary, and put black-box fork regressions in
   `tests/fork_features.rs` where practical.

## Upstream sync

- `master` tracks upstream and may only advance by fast-forward.
- Review the sync PR into `mine`, inspect the complete diff, and preserve
  upstream fixes alongside any still-needed fork behavior.
- Run formatting, clippy, the test suite, and release build. The hosted Linux
  workflows are authoritative for the fork's supported Linux target.
- Never create upstream issues or PRs under the current project instructions.
- Do not create fork-only version tags or install a build artifact from a
  different commit than the one being validated.

## History rebuilds

A history rewrite is a separate, explicitly requested operation, not a normal
sync step. Before rebuilding, preserve the original branch in a backup ref and
Git bundle, then work in a separate worktree based on current upstream. Replay
only reviewed changes as focused commits and run the full validation plan.
Update the published branch only after the user has reviewed the resulting tree
and commit list. Use a guarded `--force-with-lease` only for that explicitly
authorized rewrite; never rewrite upstream history.

## Test environment

Integration launches must use an empty temporary `HOME` unless the test
explicitly exercises global config, because `--clean` does not ignore trusted
global config. In nested rootless containers, system bubblewrap may appear
owned by overflow UID 65534; trusted-binary validation can then fail and poison
shared test locks. Compare host-limited failures against the baseline and use
the hosted Linux workflow for authoritative results.
