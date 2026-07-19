#!/usr/bin/env bash
set -euo pipefail

# retire 是一个 workflow/skill 契约，不是普通 API。
# 这个脚本用文本断言固定关键行为，避免后续改 skill 时把治理语义改丢。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file() {
  local file="$1"
  local label="$2"
  [[ -f "$file" ]] || fail "$label: 缺少文件 $file"
}

assert_contains_regex() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  assert_file "$file" "$label"
  grep -Eq -- "$pattern" "$file" || fail "$label: $file 中缺少正则 $pattern"
}

assert_contains_fixed() {
  local file="$1"
  local text="$2"
  local label="$3"
  assert_file "$file" "$label"
  grep -Fq -- "$text" "$file" || fail "$label: $file 中缺少文本 $text"
}

RETIRE_SKILL="$ROOT_DIR/.opencode/skills/retire/SKILL.md"
QUERY_SKILL="$ROOT_DIR/.opencode/skills/query/SKILL.md"
LINT_SKILL="$ROOT_DIR/.opencode/skills/lint/SKILL.md"
AGENTS="$ROOT_DIR/AGENTS.md"

# 新 skill 必须存在并可由用户显式调用。
assert_contains_regex "$RETIRE_SKILL" '^name: retire$' "retire skill frontmatter"
assert_contains_regex "$RETIRE_SKILL" '^user-invocable: true$' "retire skill frontmatter"

# retire 的三个入口：单页、source 批量候选、关键词候选。
assert_contains_fixed "$RETIRE_SKILL" "/retire [[PageName]]" "retire 单页入口"
assert_contains_fixed "$RETIRE_SKILL" "/retire --source" "retire source 入口"
assert_contains_fixed "$RETIRE_SKILL" "/retire --match" "retire 关键词入口"
assert_contains_fixed "$RETIRE_SKILL" "/retire --confirm" "retire 确认写入入口"

# 交互式确认不能依赖上一轮聊天上下文；必须通过落盘计划文件恢复方案内容。
assert_contains_fixed "$RETIRE_SKILL" "wiki/_ops/retire-plans" "retire 计划文件目录"
assert_contains_fixed "$RETIRE_SKILL" "/retire --confirm <plan_id> <option>" "retire plan_id 确认入口"
assert_contains_regex "$RETIRE_SKILL" '读取.*计划文件|计划文件.*读取' "retire 确认时读取计划文件"
assert_contains_regex "$RETIRE_SKILL" '禁止.*只.*方案字母|不得.*只.*方案字母|不接受.*--confirm A' "retire 禁止裸方案确认"
assert_contains_regex "$RETIRE_SKILL" 'status: pending|status: applied|status: cancelled' "retire 计划状态"

# 没有替代页也必须能退役，不能强行生成新页面。
assert_contains_fixed "$RETIRE_SKILL" "status: retired" "retire 页面状态"
assert_contains_fixed "$RETIRE_SKILL" "needs_review" "retire 待复核状态"
assert_contains_fixed "$RETIRE_SKILL" "superseded_by: []" "retire 无替代页语义"

# retire 只治理 wiki 编译层，不修改 raw 原文。
assert_contains_regex "$RETIRE_SKILL" '禁止.*修改.*raw|不.*修改.*raw' "retire raw 只读边界"
assert_contains_fixed "$RETIRE_SKILL" "wiki/retired.md" "retire 历史索引"
assert_contains_regex "$RETIRE_SKILL" '反向链接|backlink' "retire 影响分析"

# AGENTS.md 必须把 retire 纳入全局 workflow、日志类型和 frontmatter 契约。
assert_contains_fixed "$AGENTS" "/retire" "AGENTS workflow"
assert_contains_regex "$AGENTS" '操作类型：.*retire' "AGENTS 日志动作类型"
assert_contains_regex "$AGENTS" 'status: active \| retired \| needs_review' "AGENTS status schema"
assert_contains_regex "$AGENTS" 'superseded_by' "AGENTS 替代页字段"
assert_contains_fixed "$AGENTS" "wiki/_ops/" "AGENTS 操作状态目录"

# query 默认不使用 retired 页面，除非用户明确查历史。
assert_contains_fixed "$QUERY_SKILL" "status: retired" "query 跳过 retired"
assert_contains_regex "$QUERY_SKILL" '默认.*跳过.*retired|默认.*跳过.*退役' "query 默认跳过 retired"
assert_contains_regex "$QUERY_SKILL" '包含退役|查历史|历史.*退役' "query 历史查询例外"
assert_contains_fixed "$QUERY_SKILL" "wiki/_ops/" "query 跳过操作状态目录"

# lint 要能区分普通孤岛和 retired 页面，并检查退役说明/活跃依赖。
assert_contains_fixed "$LINT_SKILL" "status: retired" "lint retired 状态"
assert_contains_fixed "$LINT_SKILL" "## 退役说明" "lint 退役说明"
assert_contains_fixed "$LINT_SKILL" "wiki/retired.md" "lint retired 索引"
assert_contains_regex "$LINT_SKILL" '活跃页面.*retired|retired.*活跃页面|退役页面.*活跃页面' "lint 活跃依赖检查"
assert_contains_fixed "$LINT_SKILL" "wiki/_ops/" "lint 跳过操作状态目录"

printf 'retire contract checks passed\n'
