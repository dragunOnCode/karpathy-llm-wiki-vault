#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

prepare_script="$repo_root/scripts/evals/prepare-light-ingest-eval.sh"
cleanup_script="$repo_root/scripts/evals/cleanup-light-ingest-eval.sh"
fixture="raw/05-operation-guides/gitlab-runner-troubleshooting.md"

# 默认路径必须在当前仓库内，避免落到 macOS 的 /private/var 临时目录。
default_worktree="$repo_root/.gitworktree/light-ingest-eval"

# 自测使用独立子目录，避免误清理用户正在观察的默认 eval 现场。
worktree="$repo_root/.gitworktree/light-ingest-script-test"

cleanup() {
  # 测试失败时也尽量清理临时 worktree，保持工作区可重复运行。
  if [[ -e "$worktree" && -x "$cleanup_script" ]]; then
    "$cleanup_script" --worktree "$worktree" >/dev/null 2>&1 || true
  fi
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
assert_contains "$prepare_help" "$default_worktree"

cleanup_help="$("$cleanup_script" --help)"
assert_contains "$cleanup_help" "Usage:"
assert_contains "$cleanup_help" "--worktree PATH"
assert_contains "$cleanup_help" "$default_worktree"

# 默认 dry-run 应该只打印仓库内路径，不创建任何文件。
default_dry_run="$("$prepare_script" --dry-run --fixture "$fixture")"
assert_contains "$default_dry_run" "$default_worktree"
if [[ "$default_dry_run" == *"/private/"* ]]; then
  printf 'Default worktree unexpectedly points under /private:\n%s\n' "$default_dry_run" >&2
  exit 1
fi

# 指定路径的 dry-run 也不能创建 worktree。
dry_run="$("$prepare_script" --dry-run --worktree "$worktree" --fixture "$fixture")"
assert_contains "$dry_run" "git worktree add --detach"
if [[ -e "$worktree" ]]; then
  printf 'Dry run unexpectedly created worktree: %s\n' "$worktree" >&2
  exit 1
fi

# prepare 正式执行要求 tracked clean；开发脚本时只校验到 dry-run，提交后再跑完整闭环。
if ! git diff --quiet || ! git diff --cached --quiet; then
  printf 'tracked changes exist; skipped worktree create/remove integration check\n'
  exit 0
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
