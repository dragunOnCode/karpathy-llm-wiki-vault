#!/usr/bin/env bash
set -euo pipefail

script_name="$(basename "$0")"
default_worktree="${TMPDIR:-/tmp}/karpathy-llm-wiki-vault-light-ingest-eval"

worktree="$default_worktree"
dry_run=0

usage() {
  cat <<USAGE
Usage: $script_name [options]

Remove the disposable git worktree used by /ingest --light evals.

Options:
  --worktree PATH   Eval worktree path.
                    Default: $default_worktree
  --dry-run         Print the cleanup action without removing anything.
  -h, --help        Show this help.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

quote_cmd() {
  local arg
  printf '+'
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
}

normalize_worktree_path() {
  local path="$1"
  local parent base

  parent="$(dirname "$path")"
  base="$(basename "$path")"

  if [[ -d "$parent" ]]; then
    parent="$(cd "$parent" && pwd -P)"
  fi

  printf '%s/%s\n' "$parent" "$base"
}

is_registered_worktree() {
  local target="$1"
  local line path

  while IFS= read -r line; do
    case "$line" in
      worktree\ *)
        path="${line#worktree }"
        if [[ "$path" == "$target" ]]; then
          return 0
        fi
        ;;
    esac
  done < <(git -C "$main_repo" worktree list --porcelain)

  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --worktree)
      [[ $# -ge 2 ]] || die "--worktree requires PATH"
      worktree="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

git_common_dir="$(git rev-parse --git-common-dir 2>/dev/null)" || die "run this script inside the wiki git repository or one of its worktrees"
main_repo="$(cd "$git_common_dir/.." && pwd -P)"
main_root="$(git -C "$main_repo" rev-parse --show-toplevel 2>/dev/null)" || die "cannot resolve main repository root"

if [[ "$worktree" != /* ]]; then
  worktree="$main_root/$worktree"
fi
worktree="$(normalize_worktree_path "$worktree")"

if [[ "$worktree" == "$main_root" ]]; then
  die "refusing to remove the main repository: $main_root"
fi

if ! is_registered_worktree "$worktree"; then
  if [[ -e "$worktree" ]]; then
    die "path exists but is not a registered git worktree: $worktree"
  fi

  printf 'No registered eval worktree found at: %s\n' "$worktree"
  exit 0
fi

if (( dry_run )); then
  quote_cmd git -C "$main_repo" worktree remove --force "$worktree"
  if [[ -d "$worktree" ]]; then
    printf '\nCurrent worktree status:\n'
    git -C "$worktree" status --short || true
  fi
  exit 0
fi

case "$(pwd -P)/" in
  "$worktree"/*)
    cd "$main_root"
    ;;
esac

git -C "$main_repo" worktree remove --force "$worktree"
git -C "$main_repo" worktree prune

printf 'Removed eval worktree: %s\n' "$worktree"
