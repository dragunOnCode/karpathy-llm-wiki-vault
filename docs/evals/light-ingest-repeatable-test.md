# Light Ingest 可重复测试 runbook

## 目标

这个 runbook 用来反复验证 `/ingest --light <raw-path>` 是否真的降低了 LLM Wiki ingest 的上下文占用和写入膨胀。

这里不把 skill 当成普通 API 来测，因为 skill 没有稳定的函数返回值。我们测的是一次 agent 操作带来的工作区状态变化：从同一个 base commit 出发，处理同一篇 raw，观察 `wiki/`、`raw/`、`index.md`、`log.md` 的 diff 是否符合预期。

## 核心原则

- 每轮测试都从一次性 git worktree 开始，不在主工作区直接跑。
- 测试前只固定三件事：base commit、raw fixture、skill 版本。
- 测试后不写回滚脚本，不手工反向删除 wiki 页面；直接删除一次性 worktree。
- 评估结果看结构 diff 和内容抽样，不依赖 agent 自述。
- `raw/09-archive/` 是已处理区，轻量 ingest 的 fixture 必须来自 `raw/` inbox，不从 archive 重新 ingest。

## 相关脚本

- `scripts/evals/prepare-light-ingest-eval.sh`：创建一次性测试 worktree。
- `scripts/evals/cleanup-light-ingest-eval.sh`：移除一次性测试 worktree。
- `scripts/evals/test-light-ingest-scripts.sh`：验证上面两个脚本的基本行为。

默认 fixture 是：

```text
raw/05-operation-guides/gitlab-runner-troubleshooting.md
```

这篇资料是操作指导书，适合验证轻量模式是否只提取高价值风险、前置条件、排障判断，而不是把每个小标题都展开成 Claim。

如果要验证更严格的 source-only 场景，可以通过 `--fixture <path>` 换成低信号 raw：例如产品手册中的短章节、只描述位置/入口/普通功能的指导页。source-only 场景的预期是只新增或更新 Source，且不新增 Claims / Concepts / Entities；若没有任何已有页面可链接，允许创建最小必要 Domain 来避免孤岛。

## 测试前预置步骤

在主工作区执行：

```bash
scripts/evals/prepare-light-ingest-eval.sh
```

脚本会输出一次性 worktree 路径、base commit 和 fixture。默认路径通常是：

```text
${TMPDIR:-/tmp}/karpathy-llm-wiki-vault-light-ingest-eval
```

如果要指定 fixture：

```bash
scripts/evals/prepare-light-ingest-eval.sh \
  --fixture raw/04-design-docs/kep-3140-cronjob-timezone-support.md
```

如果要固定某个历史提交：

```bash
scripts/evals/prepare-light-ingest-eval.sh \
  --ref <commit-sha> \
  --fixture raw/05-operation-guides/gitlab-runner-troubleshooting.md
```

如果上一次现场没有清理，先运行 cleanup，或显式覆盖已注册的测试 worktree：

```bash
scripts/evals/prepare-light-ingest-eval.sh --force
```

脚本会拒绝以下情况：

- 当前主工作区存在 tracked dirty changes。
- fixture 指向 `raw/09-archive/`。
- fixture 不是 repo-relative 的 `raw/` 路径。
- 目标路径已存在但不是 git worktree。

## 执行测试

进入脚本输出的 worktree：

```bash
cd "${TMPDIR:-/tmp}/karpathy-llm-wiki-vault-light-ingest-eval"
```

然后在 agent 会话里执行，不是在 shell 里执行：

```text
/ingest --light raw/05-operation-guides/gitlab-runner-troubleshooting.md
```

如果使用了自定义 fixture，把路径替换成 prepare 脚本的 `fixture` 输出。

## 观察结果

先看文件级变化：

```bash
git status --short
git diff --name-status
```

再看 wiki 结构变化：

```bash
git diff -- wiki/sources wiki/claims wiki/concepts wiki/entities wiki/domains wiki/index.md wiki/log.md
```

重点检查：

| 检查项 | 通过标准 |
| --- | --- |
| Source | 每篇 raw 恰好有一个对应 `wiki/sources/摘要-*.md`，摘要短、准确、有 `## 资料定位` 和 `## 关联连接`。 |
| Claims | 只为独立、可核验、可复用的规则、限制、设计取舍、操作风险创建；source-only fixture 应为 0 个新增 Claim。 |
| Concepts / Entities | 只有出现新对象或对已有页有实质补充时才新增/更新；不为普通章节标题造概念页。 |
| Domains | 优先更新已有 Domain；只有资料集合形成稳定主题时才新建。source-only 场景允许最小 Domain 防孤岛。 |
| Provenance | `sources:` 指向归档后的 raw 路径；Claim 有 `## 出处锚点`，Source 能回到 raw。 |
| Index / Log | `wiki/index.md` 注册新增页面；`wiki/log.md` 只追加本轮 ingest 记录。 |
| Archive | fixture 被移动到 `raw/09-archive/`；原文正文不被改写。 |

对默认 GitLab Runner fixture，合理结果通常是：

- 新增或更新 1 个 Source。
- 可以有少量高价值 Claim，例如 debug logging 泄露 secrets、Shell executor debug 模式的权限风险、artifact upload 网络路径差异。
- 不应把每个 FAQ 小节都变成 Claim。
- 不应创建大量一次性 Concepts / Entities。

## 记录结果

建议把每轮结果追加到 `docs/evals/llm-wiki-pilot-results.csv` 或单独记录一份实验表。至少记录：

```text
run_id,base_commit,skill_commit,fixture,mode,source_delta,claim_delta,concept_delta,entity_delta,domain_delta,pass,notes
```

其中：

- `base_commit` 是 prepare 脚本输出的 commit。
- `skill_commit` 是本轮测试使用的 skill 修改所在 commit；prepare 脚本要求 tracked clean，所以每版 skill 先提交再测。
- `*_delta` 用 `git diff --name-status` 统计。
- `notes` 写人工抽样结论，例如“Claim 数量过多”“Source 摘要遗漏安全风险”“出处锚点不可定位”。

## 测试后清理现场

回到主工作区执行：

```bash
scripts/evals/cleanup-light-ingest-eval.sh
```

如果用了自定义 worktree 路径：

```bash
scripts/evals/cleanup-light-ingest-eval.sh \
  --worktree /path/to/eval-worktree
```

cleanup 会使用：

```bash
git worktree remove --force <worktree>
```

它只移除已注册的 git worktree。如果目标路径存在但不是 git worktree，脚本会拒绝处理，避免误删普通目录。

## 重新验证一版 skill

典型循环是：

1. 在主工作区修改 `.opencode/skills/ingest/SKILL.md`。
2. 提交这版 skill 修改，保证本轮有明确 `skill_commit`。
3. 运行 `scripts/evals/prepare-light-ingest-eval.sh` 创建新现场。
4. 在新 worktree 里执行 `/ingest --light <fixture>`。
5. 用 `git diff --name-status` 和上面的检查项评分。
6. 运行 `scripts/evals/cleanup-light-ingest-eval.sh` 清理现场。
7. 如果结果不好，回主工作区继续改 skill，再重复 2-6。

不要在 eval worktree 里继续修 skill。eval worktree 是测试现场，不是开发现场；这样可以保证每一轮都从同一个预置条件出发。

## 常见失败信号

- 轻量 ingest 扫描了整个 `raw/` inbox，而不是只处理指定文件。
- Source 摘要很长，几乎复制原文，导致没有降低上下文和维护成本。
- 对普通小标题、背景介绍、一次性命令都创建 Claim。
- 新增 Concepts / Entities 与已有页面同义或重复。
- Claim 没有 `## 出处锚点`，或只写了泛泛来源。
- raw 被移动到 archive 后，wiki 页里的 `sources:` 仍指向旧 inbox 路径。
- `wiki/log.md` 被重写或插入旧日期，而不是 append-only。

## 为什么这样能复现

一次性 worktree 相当于把测试现场做成快照：raw 还在 inbox、wiki 处于 base commit、skill 处于当前版本。跑完 ingest 后，现场会被污染，这是测试本身要观察的结果。清理时直接删除整个 worktree，下次再从同一个 commit 创建，就回到了完全相同的预置条件。
