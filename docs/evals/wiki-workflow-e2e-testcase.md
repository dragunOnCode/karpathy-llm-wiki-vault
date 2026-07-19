# LLM Wiki 小样本端到端测试用例

## 目标

验证当前 LLM Wiki workflow 在小样本企业文档形态上是否可用，重点覆盖：

- `/ingest --light` 是否避免全量 raw 扫描和页面膨胀。
- `/query` 是否能基于 wiki/index.md 和 wiki 页面回答，而不是凭模型记忆。
- `/lint` 是否能发现结构问题，且能正确处理 retired 页面。
- `/retire` 是否能把过时知识从活跃知识库下架，并保留审计入口。

本用例不全量 ingest `raw/`。raw 下文档太多，全量验证会把问题混在一起，也会消耗大量上下文。推荐选 3 篇覆盖不同类型的 fixture。

## 测试样本

| 样本 | 类型 | 路径 | 选择原因 |
|------|------|------|----------|
| TC-A | 产品手册拆章 | `raw/01-articles/014-将外接显示器连接到-MacBook-Air.md` | 短章节，适合验证 source-first、少 Claim、不制造大量概念。 |
| TC-B | 设计文档 | `raw/04-design-docs/kep-3140-cronjob-timezone-support.md` | 有 goals、proposal、risk、test plan，适合验证设计取舍和风险是否被提炼为少量可审计 Claim。 |
| TC-C | 操作指导书 | `raw/05-operation-guides/gitlab-runner-troubleshooting.md` | 有排障步骤和安全警告，适合验证操作风险、前置条件、异常路径是否被提炼。 |

## 执行环境

所有测试都在一次性 git worktree 中执行，不在主工作区直接跑 ingest/retire。这样每次测试结束后可以直接删除 worktree，还原到干净预置条件。

### 预置条件

在主工作区执行：

```bash
git status --short
```

预期结果：

- 输出为空。
- 如果有 tracked 修改，先提交或处理干净，再继续。

创建一次性测试 worktree：

```bash
scripts/evals/prepare-light-ingest-eval.sh \
  --worktree .gitworktree/wiki-workflow-e2e \
  --fixture raw/05-operation-guides/gitlab-runner-troubleshooting.md \
  --force
```

预期结果：

- 输出 `Eval worktree ready`。
- 输出 `path` 为当前仓库内 `.gitworktree/wiki-workflow-e2e`。
- 输出 `base_commit`。
- 输出 `fixture`。

进入测试 worktree：

```bash
cd .gitworktree/wiki-workflow-e2e
```

如果使用 Codex/OpenCode 执行 slash skill，请确保 agent 的当前工作区也是这个 worktree。最简单的做法是新开一个任务，工作区选择：

```text
/opt/project/karpathy-llm-wiki-vault/.gitworktree/wiki-workflow-e2e
```

如果继续使用当前任务，每次执行 skill 前都要明确说明“接下来在 `.gitworktree/wiki-workflow-e2e` 这个 worktree 中执行”，并在观察命令里用 `git -C .gitworktree/wiki-workflow-e2e ...` 交叉确认。

确认初始状态：

```bash
git status --short
find wiki -maxdepth 2 -type f | sort
find raw/09-archive -maxdepth 2 -type f | sort
```

预期结果：

- `git status --short` 输出为空。
- `wiki/` 只有空白骨架、`.gitkeep`、`wiki/index.md`、`wiki/log.md`。
- `raw/09-archive` 下没有本轮测试样本。

## TC-01：轻量 ingest 产品手册拆章

在 agent 会话中执行，不是在 shell 中执行：

```text
/ingest --light raw/01-articles/014-将外接显示器连接到-MacBook-Air.md
```

观察命令：

```bash
git status --short
git diff --name-status
git diff -- wiki/sources wiki/claims wiki/concepts wiki/entities wiki/domains wiki/index.md wiki/log.md
```

预期结果：

| 检查项 | 预期 |
|--------|------|
| raw 移动 | `raw/01-articles/014-...md` 被移动到 `raw/09-archive/`，原文正文不被改写。 |
| Source | 新增 1 个 `wiki/sources/摘要-*.md`，摘要说明外接显示器连接、显示器数量/分辨率边界、线缆/转换器要求。 |
| Claims | 允许 0 到少量 Claim；不应把 5 个步骤分别做成 Claim。 |
| Concepts/Entities | 不应为普通步骤、小标题、链接标题制造大量页面。 |
| Domain | 若没有已有页面可链接，允许创建最小必要 Domain；Domain 不应写成长摘要。 |
| Index | `wiki/index.md` 注册新增 Source，以及必要的 Claim/Domain。 |
| Log | `wiki/log.md` append 一条 `ingest`，不得重写旧日志。 |

失败信号：

- 一篇短手册拆章生成大量 Claim/Concept/Entity。
- Source 摘要接近复制原文。
- `sources:` 仍指向旧 inbox 路径。

## TC-02：轻量 ingest 设计文档

在 agent 会话中执行：

```text
/ingest --light raw/04-design-docs/kep-3140-cronjob-timezone-support.md
```

观察命令：

```bash
git diff --name-status
git diff -- wiki/sources wiki/claims wiki/concepts wiki/entities wiki/domains wiki/index.md wiki/log.md
```

预期结果：

| 检查项 | 预期 |
|--------|------|
| Source | 新增 1 个 Source，定位为 design-doc / design-proposal。 |
| Claims | 可创建少量高价值 Claim，例如 `.spec.timeZone` 新字段、未指定时沿用 controller-manager 时区、时区数据库过期风险、恶意用户配额风险。 |
| 出处锚点 | 每个 Claim 必须能定位到 Summary / Proposal / Risks / Design Details 等章节。 |
| Domain | 可创建或更新 Kubernetes CronJob / CronJob TimeZone 相关 Domain。 |
| 非目标 | 不应把 Release Signoff Checklist、Test Plan 每一项都变成 Claim。 |

失败信号：

- 设计文档被当成普通文章，只生成泛泛摘要，没有设计取舍或风险 Claim。
- Claim 没有章节锚点。
- 为 checklist 每一行生成页面。

## TC-03：轻量 ingest 操作指导书

在 agent 会话中执行：

```text
/ingest --light raw/05-operation-guides/gitlab-runner-troubleshooting.md
```

观察命令：

```bash
git diff --name-status
git diff -- wiki/sources wiki/claims wiki/concepts wiki/entities wiki/domains wiki/index.md wiki/log.md
```

预期结果：

| 检查项 | 预期 |
|--------|------|
| Source | 新增 1 个 Source，定位为 operation-guide / troubleshooting-runbook。 |
| Claims | 可创建少量高价值 Claim，例如 debug logging 可能泄露 secrets、Shell executor debug 模式有 root/文件属主风险、correlation ID 可跨组件追踪请求、Docker executor DNS 可能与宿主机不同。 |
| Concepts/Entities | 可有 GitLab Runner、Runner coordinator、debug logging 等必要页面；不应为每个错误标题建概念页。 |
| 出处锚点 | Claim 锚点应指向 warning、section heading 或关键错误消息。 |
| Archive | fixture 移到 `raw/09-archive/`。 |

失败信号：

- 把 FAQ 小节逐条变成 Claim。
- 遗漏安全警告。
- 操作步骤被改写成没有来源定位的通用排障建议。

## TC-04：query 验证当前知识可回答

在 agent 会话中执行：

```text
/query GitLab Runner 开 debug 日志有什么风险？
```

预期结果：

| 检查项 | 预期 |
|--------|------|
| 入口 | 回答前先读取 `wiki/index.md`，再读取相关 Source / Claim。 |
| 回答 | 明确说明 debug logging 可能输出变量和 secrets，Shell executor 场景还有 root/文件属主风险。 |
| 引用 | 使用 `[[页面名称]]` 双链引用相关 Source/Claim。 |
| 不确定性 | 如果 wiki 没有对应 Claim，应说明缺口，并按 query/update 规则处理，不直接凭模型记忆补答。 |
| Log | `wiki/log.md` append 一条 `query`。 |

失败信号：

- 回答没有双链引用。
- 回答使用了 raw 原文但没有触发 update 补编。
- 明明 wiki 有相关页面，却说知识库未找到。

## TC-05：lint 健康检查

在 agent 会话中执行：

```text
/lint
```

预期结果：

| 检查项 | 预期 |
|--------|------|
| Index | 不应报告新增页面未同步 index。 |
| Links | 不应有明显死链；若有，应列出来源页面和目标页面。 |
| Claims | 所有 Claim 都有 `sources:`、Source 回链、`## 出处锚点`。 |
| Domains | Domain 有 `## 概述` 和非空 `## 关联连接`。 |
| Sources | `sources:` 指向存在的 raw archive 路径。 |
| Retired | 此时尚未 retire，通常不应出现 retired 治理问题。 |
| Log | 如果执行了修复才 append `lint` 修复日志；纯报告不应静默改文件。 |

失败信号：

- lint 读取 `raw/09-archive/` 正文。
- lint 未区分 report 和 fix，直接修改文件。
- Claim 缺锚点但未报红灯。

## TC-06：retire 候选计划，不确认不写入

在 agent 会话中执行：

```text
/retire --source raw/09-archive/gitlab-runner-troubleshooting.md
```

如果实际 archive 路径包含原分类子目录或文件名不同，以 `git diff --name-status` 中移动后的路径为准。

预期结果：

| 检查项 | 预期 |
|--------|------|
| 候选发现 | 输出退役候选计划，至少包含 GitLab Runner troubleshooting 的 Source 和只由该 source 支撑的 Claim。 |
| 影响分析 | 列出活跃反向链接，例如 Domain / Concept 是否链接这些候选页。 |
| Concept/Domain | 对仍有其他来源或依赖的 Concept/Domain，建议 `needs_review`，不要自动退役。 |
| 计划文件 | 写入 `wiki/_ops/retire-plans/<plan_id>.md`，状态为 `status: pending`，并列出 A/B 等方案的完整动作。 |
| 知识页写入 | 未输入 `/retire --confirm <plan_id> <option>` 前，不应修改知识页、index、retired 索引或 log。 |
| raw | 不修改、不移动任何 raw 文件。 |

观察命令：

```bash
git diff --name-status
git diff -- wiki/_ops/retire-plans
```

失败信号：

- 未确认就修改 wiki。
- 只在聊天里展示方案，没有把完整计划落盘。
- 尝试删除 raw 或移动 archive。
- 把所有相关 Concept/Domain 都直接退役，没有区分其他来源和活跃依赖。

## TC-07：retire 确认写入

在 agent 会话中执行：

```text
/retire --confirm <plan_id> A
```

`<plan_id>` 使用 TC-06 输出的计划 ID，例如 `retire-20260720-001`。不要只执行 `/retire --confirm A`；确认阶段必须能从 `wiki/_ops/retire-plans/<plan_id>.md` 读取方案 A 的完整动作。

预期结果：

| 检查项 | 预期 |
|--------|------|
| 计划读取 | retire skill 先读取 `wiki/_ops/retire-plans/<plan_id>.md`，不依赖上一轮聊天上下文。 |
| 计划状态 | 执行后计划文件从 `status: pending` 改为 `status: applied`，并写入 `selected_option` / `applied_at`。 |
| Retired frontmatter | 确认退役页包含 `status: retired`、`retired_at`、`retired_reason`、`superseded_by: []` 或替代页。 |
| 退役说明 | 每个退役页正文包含 `## 退役说明`。 |
| Active index | `wiki/index.md` 活跃分类移除退役页。 |
| Retired index | 创建或更新 `wiki/retired.md`，登记退役页、类型、原因、替代页。 |
| 活跃双链 | 活跃页面不再在“当前依据/关联连接/核心结论”中依赖 retired 页；需要保留时移到“历史/退役引用”。 |
| Log | `wiki/log.md` append 一条 `retire`。 |
| raw | raw 和 archive 原文不被修改。 |

观察命令：

```bash
git diff -- wiki/sources wiki/claims wiki/concepts wiki/entities wiki/domains wiki/index.md wiki/retired.md wiki/log.md
git diff -- wiki/_ops/retire-plans
git diff --name-status raw
```

失败信号：

- 物理删除 wiki 页面。
- `/retire --confirm A` 这种裸方案确认也被接受。
- 确认时没有读取计划文件，只凭聊天上下文执行。
- 退役页仍在 `wiki/index.md` 活跃分类。
- 没有替代页时强行生成替代页面。
- 活跃 Domain 仍把 retired Claim 放在当前依据里。

## TC-08：query 默认跳过 retired 页面

在 agent 会话中执行：

```text
/query GitLab Runner 开 debug 日志有什么风险？
```

预期结果：

| 检查项 | 预期 |
|--------|------|
| 默认行为 | 不把 `status: retired` 页面作为当前可信依据。 |
| 回答 | 如果相关知识都已退役且没有 active 替代页，应说明当前知识库没有 active 可信结论，可提示存在退役历史。 |
| 引用 | 不应把 retired 页面当普通 Claim 引用。 |

再执行：

```text
/query 包含退役内容，GitLab Runner 开 debug 日志有什么风险？
```

预期结果：

| 检查项 | 预期 |
|--------|------|
| 历史例外 | 可以读取 retired 页面。 |
| 标注 | 回答必须明确说明引用的是退役内容，不代表当前可信结论。 |
| 引用 | 可以引用 retired 页面，但要标注 retired。 |

失败信号：

- 普通 query 仍直接引用 retired Claim。
- 历史 query 读取 retired 页面但不标注状态。

## TC-09：lint 验证 retired 治理

在 agent 会话中执行：

```text
/lint
```

预期结果：

| 检查项 | 预期 |
|--------|------|
| Retired 说明 | retired 页面有 `## 退役说明`，不报缺失。 |
| Retired index | retired 页面登记在 `wiki/retired.md`。 |
| Active index | retired 页面不在 `wiki/index.md` 活跃分类。 |
| 活跃依赖 | 活跃页面不应继续把 retired 页面当当前依据。 |
| 孤岛处理 | retired 页面不应被当作普通孤岛误报，只要可从 `wiki/retired.md` 或 `wiki/log.md` 找到。 |

失败信号：

- retired 页面被当普通孤岛大量误报。
- active 页面依赖 retired 页面但 lint 没报。
- retired 页面仍在 active index 但 lint 没报。

## TC-10：清理现场并复跑

回到主工作区执行：

```bash
scripts/evals/cleanup-light-ingest-eval.sh \
  --worktree .gitworktree/wiki-workflow-e2e
```

预期结果：

- 输出 `Removed eval worktree`。
- 主工作区 `git status --short` 仍为空。
- 下次重新运行 prepare 脚本，会回到相同 base commit 的干净现场。

## 通过标准

本轮测试通过需要同时满足：

1. 三篇 fixture 都只处理指定 raw，不扫描全量 raw。
2. 每篇 fixture 至少生成一个准确 Source，且 Source 可追溯到 archive 路径。
3. Claim 数量克制，只保留可审计、可复用、可定位的判断。
4. query 能回答 active 知识，并默认跳过 retired 页面。
5. lint 能发现 Claim/Domain/provenance/retired 治理问题。
6. retire 能在无替代页时下架页面，并维护 `wiki/retired.md`、`wiki/log.md` 和活跃双链。
7. cleanup 后不需要手工回滚 wiki/raw。

## 结果记录模板

建议每轮测试结束后记录：

```text
run_id,base_commit,skill_commit,fixtures,source_delta,claim_delta,concept_delta,entity_delta,domain_delta,query_pass,lint_pass,retire_pass,notes
```

人工 notes 至少写三类问题：

- 是否页面膨胀。
- 是否有来源或出处锚点缺失。
- retire 后 query/lint 是否仍把退役页当活跃知识。
