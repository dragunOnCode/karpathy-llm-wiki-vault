# LLM Wiki 迭代路线图 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不破坏现有 LLM Wiki 工作流的前提下，先验证“轻量编译的 wiki”是否能降低跨文档问答的上下文与人工维护成本，再逐步加入来源治理、内网试点和派生检索层。

**Architecture:** `raw/` 保持不可变证据层；每篇 raw 都有一个轻量 Source；Claim、Concept、Entity、Domain 只在有新增、可复用、可审计的知识价值时创建或更新。`wiki/` 和 `index.md` 是日常查询的首选面，raw 回读和 SQLite/FTS 等工具均为按需的辅助能力。

**Tech Stack:** Markdown、Obsidian 双链、OpenCode skills、Git、SHA-256；后续可选 Node.js 本地 intake 脚本和 SQLite FTS5/qmd，但不在第一轮引入。

## Global Constraints

- 所有面向用户的内容和知识库内容使用简体中文。
- 不修改 raw 正文；`/ingest` 只能在成功后移动 inbox 文件到 `raw/09-archive/`。
- `wiki/` 页面遵循 `AGENTS.md` 的 frontmatter、双链、index 和 append-only log 契约。
- 保留当前 `.opencode/skills/{ingest,query,update,lint}` 的入口和正常模式；第一轮只添加兼容的轻量模式。
- 任何 Claim 必须有 Source 回链与出处锚点；没有独立、可核验判断时不得为了凑数量创建 Claim。
- Markdown 是知识真相层；manifest、SQLite、FTS、向量索引和图谱都是可重建的派生层。
- 不将社区报告、GitHub 热度或单次公开样本实验当作企业效果结论；必须用内部试点复验。

---

## 总体路线图

| 迭代 | 目标 | 主要产物 | 前置条件 | 退出条件 |
|---|---|---|---|---|
| 0. 试点定义 | 先确定“什么算有效”，避免事后挑指标。 | 问题集、评分规则、结果表。 | 当前公开样本 raw 可读。 | 团队确认题目、来源锚点和成本统计口径。 |
| 1. 轻量 ingest 试点 | 验证 Source-first 是否减少重复页面与上下文。 | `--light` 兼容模式；公开样本的轻量 wiki；结果记录。 | 迭代 0 完成。 | 跨文档问题质量不低于直接读 raw，且没有为省 token 丢失关键证据。 |
| 2. 资料治理 | 用确定性 intake 管理版本、去重与 stale。 | manifest 契约、SHA-256、变更与 stale 报告。 | 迭代 1 有可接受收益。 | 一份来源变更只标记相关 wiki 页，且能定位回源。 |
| 3. 内网试点 | 在受控的企业资料和权限下复验。 | 文档分级、审核责任、只读查询边界、试点报告。 | 迭代 2 完成。 | 资料可追溯、更新可控、业务 reviewer 接受输出。 |
| 4. 规模化检索 | 仅在 Markdown 索引不足时提高定位能力。 | 可重建 FTS5/qmd 索引和检索评估。 | 迭代 3 的规模与查询数据证明需要。 | 检索质量或时延相对 `index.md` 查询有可测量改善。 |

## 不在第一轮实施的内容

- 不引入向量数据库、reranker、qmd、SQLite FTS5 或图谱服务。
- 不为 ingest 增加 subagent；它不能天然减少总 token，且会增加调度与固定开销。
- 不修改 `/query` 的“`index.md` 优先、缺口时按需回读单篇 archive、再走 update”的基本流程。
- 不重写现有 `AGENTS.md` 或替换已有 skills。
- 不将公开资料试点的结论直接外推到内网生产环境。

## 子项目 A：迭代 0-1，轻量 ingest 试点

### 文件结构与职责

| 文件 | 变更 | 职责 |
|---|---|---|
| `.opencode/skills/ingest/SKILL.md` | 修改 | 保留既有 ingest；新增明确的轻量模式和生成触发条件。 |
| `docs/evals/llm-wiki-pilot-questions.md` | 新建 | 固定样本范围、问题集、来源答案和人工评分规则。 |
| `docs/evals/llm-wiki-pilot-results.csv` | 新建 | 记录每轮问答的模式、正确性、引用、token、工具读取和耗时。 |
| `docs/evals/llm-wiki-pilot-review.md` | 新建 | 汇总结论、失败案例和是否进入迭代 2 的决定。 |
| `wiki/` | 由试点 ingest 产生变更 | 试点样本的 Source、必要的 Claim/Concept/Entity/Domain、index 和 log。 |

### Task 1：固化试点问题集和评分口径

**Files:**
- Create: `docs/evals/llm-wiki-pilot-questions.md`
- Create: `docs/evals/llm-wiki-pilot-results.csv`

**Interfaces:**
- Consumes: `raw/09-archive/` 中的 MacBook 手册章节，以及 `raw/04-design-docs/`、`raw/05-operation-guides/` 的公开试点资料。
- Produces: 每题唯一 `question_id`，供直接 raw、检索型知识库和 LLM Wiki Lite 三种运行记录共用。

- [x] **Step 1: 创建固定问题集文档**

在 `docs/evals/llm-wiki-pilot-questions.md` 写入以下结构，并至少为每类资料各准备 5 题：

```markdown
# LLM Wiki 试点问题集

## 范围
- 产品手册：MacBook Air
- 设计文档：Kubernetes KEP-3140
- 操作指导书：Kubernetes Debug Running Pods、GitLab Runner Troubleshooting

## 评分规则
- 正确性：0=错误或无依据；1=部分正确；2=正确且覆盖关键限制。
- 来源锚点：0=无来源；1=只有 Source；2=可定位章节、页码或原文片段。
- 风险完整性：0=遗漏关键前置条件/风险/回滚；1=部分覆盖；2=完整覆盖。

## Q-PM-001
- 类型：产品手册单文档事实
- 问题：<填写问题>
- 标准答案要点：<填写可验证要点>
- 可接受来源：<raw 路径和章节锚点>
```

- [x] **Step 2: 创建空结果表并锁定字段**

创建 `docs/evals/llm-wiki-pilot-results.csv`，首行必须为：

```csv
run_id,question_id,mode,answer_correctness,source_anchor,risk_completeness,input_tokens,output_tokens,tool_read_bytes,tool_calls,elapsed_seconds,reviewer_notes
```

- [ ] **Step 3: 评审问题集**

由至少一位熟悉资料的 reviewer 检查每题的标准答案和可接受来源；删除无法在公开原文中定位的题目。

- [ ] **Step 4: 验收**

确认问题集同时包含：单文档事实、跨文档综合、操作前置条件/风险、设计约束、来源变更后回源五类问题；每一题都有唯一 `question_id` 和原文锚点。

### Task 2：给 ingest 增加兼容的轻量模式

**Files:**
- Modify: `.opencode/skills/ingest/SKILL.md:39-55`
- Modify: `.opencode/skills/ingest/SKILL.md:79-188`

**Interfaces:**
- Consumes: `/ingest --light <path>` 或等价的明确“轻量摄取”指令。
- Produces: 每篇 raw 一个 Source；零个或多个 Claim、Concept、Entity、Domain 的新增或增量更新；与普通 `/ingest` 完全隔离。

- [x] **Step 1: 写出轻量模式的触发定义**

在技能的触发逻辑中增加：`/ingest --light <path>` 仅处理指定来源，且不得扫描整个 inbox。未指定 `--light` 时保留原有行为。

- [x] **Step 2: 将轻量模式的产物规则写入技能**

在技能中加入以下可执行规则：

```markdown
轻量模式：
1. 每篇 raw 必须创建或更新一个 Source 摘要页。
2. Claim 只在原文存在独立、可核验、可复用的规则、限制、结论、设计取舍或操作风险时创建；不设每篇数量下限。
3. Concept、Entity、Domain 只在存在新对象、已有页得到实质补充，或需要跨资料导航时创建或更新。
4. 资料只是同一手册的一章且未带来新结论时，仅创建 Source，并把它链接到已有相关页面。
5. 所有新增 Claim 必须保留章节、页码或关键原句等出处锚点。
```

- [x] **Step 3: 补充轻量模式的 Source 模板**

将 `## 核心摘要` 限定为 1-3 条短 bullet，并新增以下可选字段：

```markdown
## 资料定位
- **资料集**: <document_set_id 或未标注>
- **文档类型**: <product_manual | design_spec | runbook | other>
- **权威等级**: <official | draft | experience | unknown>
```

- [x] **Step 4: 手工验收技能文本**

检查以下情形在文档规则中都有明确输出：

1. 一章纯背景说明：Source，零 Claim。
2. 一章新增产品限制：Source，加一个 Claim，更新已有产品页。
3. 完整设计文档有多个方案取舍：Source，必要的 Claim，更新 Concept/Domain。
4. 操作指导书仅补充已有 runbook：Source，更新已有页面，不新建同义 Domain。

### Task 3：运行公开样本的对照试点

**Files:**
- Modify: `docs/evals/llm-wiki-pilot-results.csv`
- Create: `docs/evals/llm-wiki-pilot-review.md`
- Modify: 由 `--light` ingest 实际触及的 `wiki/` 页面、`wiki/index.md`、`wiki/log.md`

**Interfaces:**
- Consumes: Task 1 的 `question_id` 和 Task 2 的轻量 ingest 规则。
- Produces: 三种模式可比较的同题结果，以及是否继续的明确建议。

- [ ] **Step 1: 记录直接 raw 基线**

逐题执行“先定位候选 raw，再读取原文回答”。每题将 token、工具读取字节数、调用次数和时延写入 CSV；人工 reviewer 依据问题集评分。

- [ ] **Step 2: 执行轻量 ingest**

对每个公开样本使用 `--light` 模式。检查每篇 raw 都对应一个 Source；检查没有为了数量生成空泛 Claim；检查 `wiki/index.md` 与 `wiki/log.md` 已按现有契约更新。

- [ ] **Step 3: 记录 LLM Wiki Lite 结果**

逐题遵循 `index.md -> 少量 wiki 页面 -> 必要时单篇 raw 回读`。将同一指标写入 CSV，`mode` 填写 `llm_wiki_lite`。

- [ ] **Step 4: 写出试点评审**

在 `docs/evals/llm-wiki-pilot-review.md` 中使用以下固定表格：

```markdown
| 指标 | 直接 raw | LLM Wiki Lite | 结论 |
|---|---:|---:|---|
| 平均正确性 |  |  |  |
| 平均来源锚点 |  |  |  |
| 平均风险完整性 |  |  |  |
| 平均输入 token |  |  |  |
| 平均工具读取字节数 |  |  |  |
| 平均调用次数 |  |  |  |
| 平均时延 |  |  |  |
```

- [ ] **Step 5: 做出迭代门禁决定**

只有同时满足以下条件，才进入迭代 2：

1. 跨文档问题的正确性和来源锚点均不低于直接 raw 基线。
2. 没有因压缩而遗漏关键操作风险、约束或例外。
3. 至少一类跨资料问题的输入 token、读取字节数、调用次数或人工复核成本有可解释改善。
4. 试点评审列出全部失败题和对应原因，而不是只报告平均值。

## 子项目 B：迭代 2，资料治理

**启动条件：** 子项目 A 通过门禁。
**独立计划：** 在启动时新建 `docs/superpowers/plans/YYYY-MM-DD-llm-wiki-source-governance.md`，不在本文件中预先实现。

必须覆盖以下验收项：

1. 定义统一 manifest，至少有 `source_id`、`document_set_id`、`document_kind`、`authority_level`、`owner`、`version`、`effective_date`、`source_original_path`、`source_current_path`、`source_sha256`、`status`、`compiled_pages`、`last_compiled_at`。
2. 本地确定性 intake 负责扫描、哈希、去重、类型识别与变更报告，不调用 LLM。
3. stale 检查读取 manifest 与 wiki frontmatter，标记关联页面而不静默改写正文。
4. raw 归档后仍通过 `source_current_path` 和 `source_sha256` 回源。

## 子项目 C：迭代 3，内网试点与发布治理

**启动条件：** 子项目 B 通过门禁，并获得内网资料使用与权限批准。
**独立计划：** 在启动时新建 `docs/superpowers/plans/YYYY-MM-DD-llm-wiki-internal-pilot.md`。

必须覆盖以下验收项：

1. 文档分级、访问控制和资料责任人清单。
2. `official`、`draft`、`experience` 等权威等级在查询答案中可见。
3. 高影响 Claim、设计取舍和操作风险需要 reviewer 审核后才进入已验证状态。
4. 面向普通员工的查询接口只读；写入、归档和发布由受控 workflow 完成。
5. 用脱敏的企业资料重复子项目 A 的问题集和评分过程。

## 子项目 D：迭代 4，规模化检索

**启动条件：** 内网试点数据显示 `index.md` 已无法稳定定位页面，或查询成本达到团队已确认的阈值。
**独立计划：** 在启动时新建 `docs/superpowers/plans/YYYY-MM-DD-llm-wiki-derived-search.md`。

必须覆盖以下验收项：

1. 先评估 SQLite FTS5/BM25；仅在语义召回不足时加入向量检索与 rerank。
2. 索引可由 Markdown 和 manifest 全量重建，不能成为新的知识真相源。
3. 检索结果返回 wiki 页路径、来源路径和分数/排序依据，供 agent 选择少量页面读取。
4. 与只读 `index.md` 查询对照评测 precision、来源可追溯率、端到端时延和输入 token。

## 追踪规则

- 每完成一个 Task，只勾选本文件对应的 checkbox，并在 `wiki/log.md` 记录实际执行过的 ingest/query/update/lint；不要把计划撰写当作 wiki 资料 ingest。
- 每个子项目结束时，在该子项目计划末尾追加“实际结果、失败案例、是否进入下一轮”的简短结论。
- 新的实现计划必须引用本文件、[实践调研与证据说明](../../research/llm-wiki-practice-evidence.md) 和前一轮评审结果。
- 任何范围扩大（向量库、subagent、自动发布、内网资料接入）都必须先写入相应子项目计划并获得明确批准。

## Plan Self-Review

- 覆盖性：本路线图覆盖了试点评估、轻量 ingest、来源治理、内网发布治理与派生检索；每项都有启动条件和退出条件。
- 范围：第一轮只修改 ingest 规则并建立评测资料，不提前实现 intake 脚本、检索服务或 subagent。
- 一致性：Source 一对一、Claim 按价值生成、查询优先 wiki、raw 按需回读的规则与 `AGENTS.md` 一致。
- 可追踪性：任务均有明确文件路径、输入输出和验收门禁；后续子项目必须单独计划。
