#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

prepare_script="$repo_root/scripts/evals/prepare-light-ingest-eval.sh"
cleanup_script="$repo_root/scripts/evals/cleanup-light-ingest-eval.sh"
fixture="raw/05-operation-guides/gitlab-runner-troubleshooting.md"
tmp_parent="$(mktemp -d "${TMPDIR:-/tmp}/light-ingest-script-test.XXXXXX")"
worktree="$tmp_parent/worktree"

cleanup() {
  if [[ -e "$worktree" && -x "$cleanup_script" ]]; then
    "$cleanup_script" --worktree "$worktree" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp_parent"
}
trap cleanup EXIT

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'Expected output to contain: %s\n' "$needle" >&2
    printf 'Actual output:\n%s\n' "$haystack" >&2
    exit 1
  fi
}

if [[ ! -x "$prepare_script" ]]; then
  printf 'Missing executable prepare script: %s\n' "$prepare_script" >&2
  exit 1
fi

if [[ ! -x "$cleanup_script" ]]; then
  printf 'Missing executable cleanup script: %s\n' "$cleanup_script" >&2
  exit 1
fi

prepare_help="$("$prepare_script" --help)"
assert_contains "$prepare_help" "Usage:"
assert_contains "$prepare_help" "--fixture PATH"

cleanup_help="$("$cleanup_script" --help)"
assert_contains "$cleanup_help" "Usage:"
assert_contains "$cleanup_help" "--worktree PATH"

dry_run="$("$prepare_script" --dry-run --worktree "$worktree" --fixture "$fixture")"
assert_contains "$dry_run" "git worktree add --detach"
if [[ -e "$worktree" ]]; then
  printf 'Dry run unexpectedly created worktree: %s\n' "$worktree" >&2
  exit 1
fi

"$prepare_script" --worktree "$worktree" --fixture "$fixture"
git -C "$worktree" rev-parse --is-inside-work-tree >/dev/null

if [[ ! -f "$worktree/$fixture" ]]; then
  printf 'Fixture missing from eval worktree: %s\n' "$worktree/$fixture" >&2
  exit 1
fi

"$cleanup_script" --worktree "$worktree"

if [[ -e "$worktree" ]]; then
  printf 'Cleanup did not remove worktree: %s\n' "$worktree" >&2
  exit 1
fi

printf 'light ingest eval script tests passed\n'
