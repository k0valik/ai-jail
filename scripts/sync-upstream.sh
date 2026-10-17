#!/usr/bin/env bash
# Fast-forward origin/master to upstream/master and refresh a PR into mine.
# Upstream objects are fetched and inspected as Git data; nothing from upstream
# is checked out or executed.
set -euo pipefail

UPSTREAM_URL=https://github.com/akitaonrails/ai-jail
UPSTREAM_BRANCH=master
FORK_REMOTE=origin
FORK_BRANCH=master
PR_BASE=''
DO_PUSH=0
DO_PR=0

usage() {
  cat <<'EOF'
usage: sync-upstream.sh [--push] [--pr] [--pr-base BRANCH]

Without --push, report what would change. --pr implies --push and creates or
refreshes a pull request from master into the supplied base branch.
EOF
}

while [ "$#" -gt 0 ]; do
  case $1 in
    --push) DO_PUSH=1; shift ;;
    --pr) DO_PUSH=1; DO_PR=1; shift ;;
    --pr-base) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; PR_BASE=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'sync-upstream: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ "$DO_PR" -eq 1 ]; then
  [ -n "$PR_BASE" ] || { echo 'sync-upstream: --pr requires --pr-base' >&2; exit 2; }
  command -v gh >/dev/null 2>&1 || { echo 'sync-upstream: gh is required for --pr' >&2; exit 1; }
fi

repo=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo 'sync-upstream: not inside a git repository' >&2
  exit 1
}
cd "$repo"
[ "$(git branch --show-current)" = mine ] \
  || { echo 'sync-upstream: run from the mine branch' >&2; exit 1; }

git fetch --quiet --no-tags --no-recurse-submodules "$FORK_REMOTE" \
  "+refs/heads/$FORK_BRANCH:refs/remotes/$FORK_REMOTE/$FORK_BRANCH"
git fetch --quiet --no-tags --no-recurse-submodules "$UPSTREAM_URL" \
  "+refs/heads/$UPSTREAM_BRANCH:refs/remotes/fork-upstream/$UPSTREAM_BRANCH"

fork_tip=$(git rev-parse "refs/remotes/$FORK_REMOTE/$FORK_BRANCH^{commit}")
upstream_tip=$(git rev-parse "refs/remotes/fork-upstream/$UPSTREAM_BRANCH^{commit}")

if [ "$fork_tip" = "$upstream_tip" ]; then
  echo "sync-upstream: master is current at ${upstream_tip:0:12}"
elif git merge-base --is-ancestor "$fork_tip" "$upstream_tip"; then
  echo "sync-upstream: master can advance ${fork_tip:0:12} -> ${upstream_tip:0:12}"
  if [ "$DO_PUSH" -eq 1 ]; then
    git push "$FORK_REMOTE" "$upstream_tip:refs/heads/$FORK_BRANCH"
    fork_tip=$upstream_tip
  fi
else
  echo 'sync-upstream: origin/master is not an ancestor of upstream/master; refusing to rewrite master' >&2
  exit 1
fi

if [ "$DO_PR" -eq 0 ]; then
  [ "$DO_PUSH" -eq 0 ] || exit 0
  echo "sync-upstream: dry run; rerun with --push to update origin/$FORK_BRANCH"
  exit 0
fi

git fetch --quiet --no-tags --no-recurse-submodules "$FORK_REMOTE" \
  "+refs/heads/$PR_BASE:refs/remotes/$FORK_REMOTE/$PR_BASE"
base_tip=$(git rev-parse "refs/remotes/$FORK_REMOTE/$PR_BASE^{commit}")

if git merge-base --is-ancestor "$fork_tip" "$base_tip"; then
  echo "sync-upstream: $PR_BASE already contains master; no pull request needed"
  exit 0
fi

repo_name=${GITHUB_REPOSITORY:-k0valik/ai-jail}
pr_number=$(gh pr list --repo "$repo_name" --head master --base "$PR_BASE" \
  --state open --json number --jq '.[0].number // empty')
title='sync: upstream master'
body=$(cat <<EOF
This pull request brings the fork's \`master\` branch into \`$PR_BASE\`.

The \`master\` branch is fast-forwarded from \`akitaonrails/ai-jail:master\` by the scheduled upstream-sync workflow. Review the changes and merge this pull request when ready.
EOF
)

if [ -n "$pr_number" ]; then
  # Updating master above refreshes this PR's source branch automatically.
  # Keep any human-edited PR title and description intact.
  echo "sync-upstream: refreshed pull request #$pr_number; title and body unchanged"
else
  gh pr create --repo "$repo_name" --head master --base "$PR_BASE" \
    --title "$title" --body "$body"
fi
