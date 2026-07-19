#!/usr/bin/env bash
set -euo pipefail

script_name="$(basename "$0")"
default_worktree="${TMPDIR:-/tmp}/karpathy-llm-wiki-vault-light-ingest-eval"
default_fixture="raw/05-operation-guides/gitlab-runner-troubleshooting.md"

worktree="$default_worktree"
ref="HEAD"
fixture="$default_fixture"
force=0
dry_run=0

usage() {
  cat <<USAGE
Usage: $script_name [options]

Create a disposable git worktree for repeating /ingest --light evals.

Options:
  --worktree PATH   Eval worktree path.
                    Default: $default_worktree
  --ref REF         Commit/ref to test from. Default: HEAD
  --fixture PATH    Repo-relative inbox raw file to ingest.
                    Default: $default_fixture
  --force           Remove an existing registered eval worktree first.
  --dry-run         Print actions without changing files.
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

run_cmd() {
  if (( dry_run )); then
    quote_cmd "$@"
  else
    "$@"
  fi
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
  done < <(git worktree list --porcelain)

  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --worktree)
      [[ $# -ge 2 ]] || die "--worktree requires PATH"
      worktree="$2"
      shift 2
      ;;
    --ref)
      [[ $# -ge 2 ]] || die "--ref requires REF"
      ref="$2"
      shift 2
      ;;
    --fixture)
      [[ $# -ge 2 ]] || die "--fixture requires PATH"
      fixture="$2"
      shift 2
      ;;
    --force)
      force=1
      shift
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

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "run this script inside the wiki git repository"
cd "$repo_root"

if [[ "$worktree" != /* ]]; then
  worktree="$repo_root/$worktree"
fi
worktree="$(normalize_worktree_path "$worktree")"

case "$fixture" in
  /*)
    die "--fixture must be a repo-relative path under raw/"
    ;;
  *..*)
    die "--fixture must not contain '..'"
    ;;
  raw/09-archive/*)
    die "--fixture must point to inbox raw, not raw/09-archive/"
    ;;
  raw/*)
    ;;
  *)
    die "--fixture must start with raw/"
    ;;
esac

if ! git diff --quiet || ! git diff --cached --quiet; then
  die "tracked changes exist in the current worktree; commit or stash them before preparing a repeatable eval"
fi

base_commit="$(git rev-parse --verify "$ref^{commit}" 2>/dev/null)" || die "ref is not a commit: $ref"
git cat-file -e "$base_commit:$fixture" 2>/dev/null || die "fixture does not exist at $ref: $fixture"

if is_registered_worktree "$worktree"; then
  if (( force )); then
    run_cmd git worktree remove --force "$worktree"
  else
    die "eval worktree is already registered at $worktree; run cleanup first or pass --force"
  fi
elif [[ -e "$worktree" ]]; then
  die "path already exists but is not a registered git worktree: $worktree"
fi

run_cmd mkdir -p "$(dirname "$worktree")"
run_cmd git worktree add --detach "$worktree" "$base_commit"

if (( dry_run )); then
  cat <<INFO

Dry run only. No eval worktree was created.
INFO
  exit 0
fi

if [[ ! -f "$worktree/$fixture" ]]; then
  die "created worktree but fixture is missing: $worktree/$fixture"
fi

cat <<INFO
Eval worktree ready:
  path: $worktree
  base_commit: $base_commit
  fixture: $fixture

Next:
  cd "$worktree"
  /ingest --light $fixture

Observe:
  git status --short
  git diff --name-status
  git diff -- wiki/sources wiki/claims wiki/concepts wiki/entities wiki/domains wiki/index.md wiki/log.md

Cleanup from the main repo:
  "$repo_root/scripts/evals/cleanup-light-ingest-eval.sh" --worktree "$worktree"
INFO
