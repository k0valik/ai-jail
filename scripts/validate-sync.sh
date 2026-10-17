#!/usr/bin/env bash
# Check that this checkout has the expected fork and branch layout.
set -euo pipefail

repo=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo 'sync setup: not inside a git repository' >&2
  exit 1
}
cd "$repo"

fail() {
  printf 'sync setup: %s\n' "$1" >&2
  exit 1
}

[ "$(git branch --show-current)" = mine ] \
  || fail 'run from the mine branch'
[ "$(git remote get-url origin)" = 'https://github.com/k0valik/ai-jail' ] \
  || fail 'origin must be https://github.com/k0valik/ai-jail'
git rev-parse --verify --quiet refs/remotes/origin/mine^{commit} >/dev/null \
  || fail 'origin/mine is missing; fetch the fork before syncing'

echo 'sync setup: origin and mine branch are configured'
