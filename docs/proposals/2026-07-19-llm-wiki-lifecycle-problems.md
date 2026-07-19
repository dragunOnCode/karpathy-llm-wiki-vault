# Proposal：LLM Wiki 长期运作典型问题清单

> **状态**：Proposal（问题盘点，非实施计划）  
> **日期**：2026-07-19  
> **目的**：盘点本仓库在「可迭代、可维护」目标下会长期遇到的典型问题，并附标志性解法与出处，便于后续按优先级设计协议与 skill。  
> **相关文档**：[[docs/superpowers/plans/2026-07-15-llm-wiki-iteration-roadmap.md]]、[[docs/research/llm-wiki-practice-evidence.md]]、[[AGENTS.md]]

---

## 1. 背景与动机

当前流水线大致为：

```text
ingest（inbox → wiki → archive）
  → query（读 wiki；缺口时按需核 archive）
  → update（确认有原文后定向补编）
  → lint（结构与契约健康检查）
```

这在「初次编译」上说得通，但库跑久之后会出现：**原文更新、知识过时、想删除、冲突、路径腐烂、补编偏置** 等问题。若没有显式协议，Agent 只能靠临场猜测，知识库会逐渐不可信。

本提案先**只列问题与业界标志性解法**，不规定本仓库立刻全部实现。实施顺序应回到迭代路线图，按试点数据裁剪。

---

## 2. 问题总览（九大类）

| # | 类别 | 一句话 |
|---|------|--------|
| 1 | 源材料生命周期 | raw 如何新增、修订、消失、退役 |
| 2 | Wiki 编译层一致性 | 摘要/断言/实体如何与 index、双链保持一致 |
| 3 | 冲突、时效与真值 | 新旧说法打架、软过时、谁来裁定 |
| 4 | 删除、退役与遗忘 | 删源 / 删知 / 半删 / 合规硬删 |
| 5 | 查询与补编长期行为 | 缺口误判、update 噪声、冷门区永远瘦 |
| 6 | 人机协作与治理 | 人工精修、批量 ingest、多 Agent 同写 |
| 7 | 规模与性能 | index 膨胀、lint 变慢、检索升级阈值 |
| 8 | Schema 与仓库演进 | 命名变更、新页面类型、skill 升级回归 |
| 9 | 安全与滥用 | 间接注入、密钥进库、不可信源扩散 |

---

## 3. 分项：典型场景 × 标志性解法 × 出处

### 3.1 源材料生命周期（raw / archive）

| 典型场景 | 标志性解法 | 出处 |
|----------|------------|------|
| 原文重大更新（同文件/同 URL 新版本） | **Supersession**：新版入库，旧版标 `superseded`，`supersedes` / `superseded_by` 串版本链；默认查询只看当前版 | [llm-wiki-kit SPEC](https://github.com/MauricioPerera/llm-wiki-kit/blob/main/SPECIFICATION.md)；[Areev Supersede](https://areev.ai/docs/guides/supersede/)；[Director-AI Provenance Ledger](https://anulum.github.io/director-ai/api/provenance-ledger/) |
| 原文小修（错字、链接） | **内容哈希增量**：对 raw 做 SHA-256；仅 hash 变化触发 `refresh --stale`，避免全库重编 | [LLM Wiki v3 spec](https://gist.github.com/adamambush/b35080bee510ffd35b5cefc876a47182)；[atomicstrata/llm-wiki-compiler](https://github.com/atomicstrata/llm-wiki-compiler) |
| 同一主题多版本并存 | **Fact 不可变 + 显式取代**：旧事实保留，新事实指向旧事实；禁止静默覆盖 | llm-wiki-kit；[NornicDB Persistence Semantics](https://orneryd.github.io/NornicDB/research/papers/persistence-semantics-nornicdb/paper/) |
| 原文消失 / 整篇退役 | **Supersede ≠ Forget**：演化用取代；合规真删用 forget。另用 **软删 / tombstone** 让索引跳过但历史可审计 | Areev；NornicDB；[Wikipedia Soft deletion](https://en.wikipedia.org/wiki/WP:SOFTDELETE) |
| 误 ingest / 低质文 | **原子 commit + git revert**：一次 ingest 多页改动打成单一 commit，可整笔回退 | llm-wiki-kit；[Karpathy LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) |
| 不可信 / 有毒来源 | **Review queue / pending**：未审源不进 live wiki；四眼或人工 gate | llm-wiki-compiler；Karpathy gist 社区安全讨论 |

**对本仓库的含义**：与路线图「迭代 2：资料治理」（manifest、SHA-256、stale）直接对齐；「原文重大更新」应优先设计为 supersede + 相关页 stale，而不是静默重写。

---

### 3.2 Wiki 编译层漂移与一致性

| 典型场景 | 标志性解法 | 出处 |
|----------|------------|------|
| 有损编译缺口（摘要太粗、边界没提） | **Lint + Query 回访原文 + 定向补编**（本仓库 query → update） | Karpathy gist（lint）；本仓库 `.opencode/skills/{query,update}` |
| 重复实体/概念（别名分裂） | **Merge + Redirect**：合并到 survivor，旧页变重定向；稳定 ID 不硬删 | [Wikidata Help:Merge](https://www.wikidata.org/wiki/Help:Merge/en)；[Help:Redirects](https://www.wikidata.org/wiki/Help:Redirects) |
| 热门页膨胀 | **原子 Claim 与叙事分离**：断言独立成页，概念/领域页引用 claim | LLM Wiki v3（claims 分区）；本仓库 `wiki/claims/` 契约（`AGENTS.md`） |
| 孤儿页 / 死链 | **定时确定性 lint**（结构检查可不调 LLM） | Karpathy gist；llm-wiki-compiler `llmwiki lint` |
| index / log 不同步 | **每次写入强制更新 index + append log** | Karpathy gist |
| `sources:` 路径腐烂（归档后仍写 inbox） | 归档后改写最终路径；lint 做路径存在性；或 content-addressed `raw/<sha>/` | 本仓库 ingest/lint 契约；LLM Wiki v3 |
| 半向双链 | Lint 报缺失反向链；合并后批量改写引用 | Wikidata bot 清引用实践 |

**对本仓库的含义**：Claims / Domains 已降低「把一切塞进概念页」的压力；下一步要补的是 **redirect 约定** 与 **路径/stale 的确定性检查**。

---

### 3.3 冲突、时效与真值

| 典型场景 | 标志性解法 | 出处 |
|----------|------------|------|
| 硬冲突（新文否定旧结论） | **Flag 不静默覆盖**；或新 claim `supersedes` 旧 claim；人文场景可用类型化边（contradicts / extends） | Karpathy gist；[cozypet: Schema Is the Product](https://cozypet.github.io/llm-wiki-schema/)；gist 评论区讨论 |
| 软过时（部分仍成立） | **`compiled` / `verified` / `stale`**：源 mtime/hash 新于编译时间 → 确定性降级为 stale | [Samanta Fluture: Stress-Testing](https://samantafluture.com/blog/2026-04-12-stress-testing-the-karpathy-wiki/) |
| 时效敏感声明（「当前 SOTA 是 X」） | **双时态（bi-temporal）**：valid time + transaction time | [Temporal database](https://en.wikipedia.org/wiki/Temporal_database)；[Sentra bi-temporal KG](https://www.sentra.app/articles/what-is-a-bitemporal-knowledge-graph) |
| 置信分层 | 信任来自 **provenance 链**（source、span、extracted_at），不迷信单一 float | [LLM-Wiki-v3](https://github.com/vvvvvivekkk/LLM-Wiki-v3) |
| 人 vs Agent 裁定 | **默认人工批准 supersession**；仅高置信可 auto-promote | Director-AI `KnowledgeSupersessionPolicy` |

**对本仓库的含义**：个人/小团队阶段优先 **`stale` + `## 知识冲突` + 人工确认**；双时态图数据库属于远期选项，不进第一轮。

---

### 3.4 删除、退役与遗忘

| 典型场景 | 标志性解法 | 出处 |
|----------|------------|------|
| 删源不删知（通用原则仍想留） | 切断或改写 provenance，知识保留为已验证结论；或先 supersede 再归档源 | Areev；Fluture（verified 与 source 状态） |
| 删知不删源 | 页标 `retired` / tombstone 或 redirect；raw 不动 | Wikipedia deletion vs redirect；Wikidata「redirect 优先于 delete」 |
| 级联删除范围 | **按来源扫贡献**：凡 claim/`sources:` 含该源的内容进入剥离清单，人工确认后半删 | llm-wiki-kit（fact↔source）；LLM Wiki v3 claim 模型 |
| 半删（只去掉某文贡献的几条） | **段/claim 级引用**（脚注或 claim-id）；删源 = 处理带该引用的 claim | LLM-Wiki-v3；llm-wiki-compiler |
| 旧双链不断 | **Redirect / aliases**，禁止复用旧 ID 给新主题 | Wikidata Redirects |
| 合规遗忘 | **Forget（硬删）** 与 supersede 分离；删除动作可审计 | Areev；Wikipedia deletion log |

**对本仓库的含义**：用户「觉得某篇过时想删」应拆成三问——退役源？作废知识？合规硬删？默认走 **软退役 + 级联剥离清单**，少物理删页。

---

### 3.5 查询与补编长期行为

| 典型场景 | 标志性解法 | 出处 |
|----------|------------|------|
| 补编偏置（常问的越补越厚） | **Lint 主动找 gap** + 建议新问题/新源 | Karpathy gist Lint |
| update 过度 / synthesis 堆积 | **高价值才固化**；pending 区；crystallize 有门槛 | 本仓库 query/update 确认菜单；[llm-wiki-skills crystallize](https://github.com/vanillaflava/llm-wiki-skills) |
| archive 核对成本上升 | index/图预筛后再单篇回读；规模大了加本地检索（如 qmd） | Karpathy（可选 qmd）；[tobi/qmd](https://github.com/tobi/qmd) |
| 「未找到」误判 | 路径回退、hash、freshness；缺口时显式核原文 | Fluture freshness；本仓库 query 路径回退设计 |

**对本仓库的含义**：保持「query 发现、update 写入」分工；防止把每次小问都写回 wiki。

---

### 3.6 人机协作与治理

| 典型场景 | 标志性解法 | 出处 |
|----------|------------|------|
| 人手改 wiki vs Agent 覆盖 | **Hand-edit protection / pre-edit checkpoint**：写入前比对 hash，禁止静默吞掉人工段落 | llm-wiki-compiler；LLM Wiki v3 |
| 批量 ingest 审查不过来 | 偏好 **一篇一审**；批量进 review queue | Karpathy gist |
| 多 Agent / 多设备同写 | **Scoped ownership**（目录归属）+ append-only log；或 **单写者队列** | [VaultMesh](https://github.com/alinclaudiu/vaultmesh)；[wuphf WIKI-SCHEMA](https://github.com/nex-crm/wuphf/blob/main/docs/specs/WIKI-SCHEMA.md) |
| 审计「这句话从哪来」 | 页级 `sources:` → 升级为 **claim/段落级 citation** | LLM-Wiki-v3；本仓库 Claim 出处锚点契约 |

**对本仓库的含义**：单人使用时可先忽略多写者；但 **人工编辑保护** 与 **claim 级锚点** 值得早做。

---

### 3.7 规模与性能

| 典型场景 | 标志性解法 | 出处 |
|----------|------------|------|
| `index.md` 过长 | 分层目录 / MOC；或派生检索索引（可重建） | Nick Milo LYT（MOC）；lucasastorian/llmwiki（SQLite 派生索引） |
| 单页过长 | 拆 claim / 子页；query 只读相关段 | LLM Wiki v3 |
| lint 全库变慢 | 结构 lint 用**确定性脚本**；LLM lint 抽样 | Fluture；llm-wiki-compiler |
| 何时升级检索 | 个人规模靠 index；证明不足后再加 BM25/混合搜 | Karpathy；qmd；本仓库路线图迭代 4 |
| 派生层可重建 | 「markdown + git 为真源；向量/BM25/图可 rebuild」 | LLM-Wiki-v3 |

**对本仓库的含义**：与路线图「迭代 4：规模化检索」一致——**先证明 index 不够，再上派生索引**。

---

### 3.8 Schema 与仓库自身演进

| 典型场景 | 标志性解法 | 出处 |
|----------|------------|------|
| 目录/命名规范变更 | **Schema 版本化**（`schema/v1` + `CURRENT`）+ 显式迁移 | LLM-Wiki-v3 |
| 新页面类型（claim/domain/decision…） | OKF 式：`type` 开放字符串，消费者容忍未知 type | [Google OKF v0.1](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing) |
| skill / 契约升级 | `refresh --stale` / 全库 lint；用 git 分支试跑 | llm-wiki-compiler |
| 缺少回归 | 固定「金标准问题集」做 eval | 本仓库 `docs/evals/`；llm-wiki-compiler eval |

**对本仓库的含义**：Claims/Domains 已是一次 schema 演进；后续变更应带迁移说明与 eval，而不是只改 skill 文案。

---

### 3.9 安全与滥用

| 典型场景 | 标志性解法 | 出处 |
|----------|------------|------|
| 间接 Prompt Injection（剪藏里藏指令） | **Spotlighting**（分隔/打标/编码）；分类器；检测后裁剪 | [Hines et al., arXiv:2403.14720](https://arxiv.org/abs/2403.14720)；[Microsoft MSRC 2025](https://www.microsoft.com/en-us/msrc/blog/2025/07/how-microsoft-defends-against-indirect-prompt-injection-attacks) |
| Agent 工具链注入 | **INJECAGENT** 基准；工具输出当数据不当指令 | [INJECAGENT, ACL 2024 Findings](https://aclanthology.org/2024.findings-acl.624/) |
| 不可信编译进 live | 暂存 + 人工 promote；外部 bundle 默认 review | llm-wiki-compiler |
| 秘密进库 | pre-commit 密钥扫描 | VaultMesh |

**对本仓库的含义**：ingest 应对不可信网页剪藏保持「当数据读」；企业试点还需文档分级与审核责任（见实践调研文档）。

---

## 4. 与用户两个具体问题的对照

| 用户问题 | 归属类别 | 建议默认策略（提案级，非已实现） |
|----------|----------|----------------------------------|
| raw 有重大更新怎么办？ | §3.1 + §3.3 | 当新修订登记 → 相关 Source/Claim 标 stale 或 supersede → 定向 refresh；旧版保留可追溯 |
| 觉得过时想从知识库删掉？ | §3.4 | 先区分退役源 / 作废知识 / 合规遗忘；默认软退役 + redirect + 按来源剥离清单，少硬删 |

---

## 5. 建议的后续设计分组（便于排期）

1. **源变更协议**：新增 / 小修 / 大更新 / 消失 / 退役  
2. **知变更协议**：增补 / 合并 / 拆分 / 冲突 / 过时标记  
3. **删除语义**：删源、删知、半删、级联、重定向  
4. **治理**：人工编辑保护、审计、权限、注入防护  
5. **规模**：索引分层、检索升级阈值、lint 成本  
6. **元演进**：schema 版本、skill 迁移、eval 回归  

与现有路线图的粗映射：

| 本提案分组 | 路线图迭代 |
|------------|------------|
| 源变更 + 过时/stale | 迭代 2 资料治理 |
| 治理 + 安全（企业） | 迭代 3 内网试点 |
| 规模 + 检索 | 迭代 4 规模化检索 |
| 缺口补编闭环 | 已有 query/update（持续打磨） |
| 删除/redirect/合并 | **尚未单独立项**（建议作为迭代 2 的子项或独立小提案） |

---

## 6. 个人库「最小可借鉴」组合（提醒，非承诺）

若只抽对 markdown vault 最划算的标志性组合：

```text
源变更     →  content-hash 测变 + supersede 链
过时       →  compiled / verified / stale
冲突       →  双说或 supersedes + 人工裁定
删除       →  redirect / tombstone 优先；合规才 hard forget
缺口       →  lint + query 核原文 + update（已有）
协作       →  人工编辑保护；claim 级锚点（已有雏形）
规模       →  markdown 为真源；检索层可重建
安全       →  未审源不进 live；原文当数据读
```

---

## 7. 非目标（本提案不做）

- 不在本文规定具体 skill 文案或 frontmatter 字段终稿  
- 不引入向量库 / 企业知识中台  
- 不把社区报告当作已验证的业务效果  
- 不修改 `raw/` 正文  

---

## 8. 建议的下一步（供决策）

1. 评审本清单：标注「采纳 / 暂缓 / 不做」  
2. 优先挑 **源更新（supersede/stale）** 与 **退役删除（redirect + 级联剥离）** 写成决策表  
3. 再开实施计划（可挂到路线图迭代 2 子任务），避免一上来改全套 skill  

---

## 9. 参考索引（按类型）

### 规范 / 论文 / 权威实践
- Karpathy, *LLM Wiki* — https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f  
- Google Cloud, *Open Knowledge Format (OKF) v0.1*  
- Hines et al., *Spotlighting*, arXiv:2403.14720  
- INJECAGENT, ACL 2024 Findings  
- Wikipedia: Soft deletion / Deletion policy  
- Wikidata: Merge / Redirects  
- Temporal database (bi-temporal)

### 开源实现 / 产品文档
- MauricioPerera/llm-wiki-kit  
- atomicstrata/llm-wiki-compiler  
- vvvvivekkk/LLM-Wiki-v3 / adamambush LLM Wiki v3 gist  
- Areev Supersede docs  
- Director-AI Provenance Ledger  
- tobi/qmd  
- VaultMesh / wuphf wiki schema  

### 社区分析
- Samanta Fluture, *Stress-Testing the Karpathy Wiki*  
- cozypet, *The Schema Is the Product*  

---

*本文为问题盘点提案。采纳项落地时，应另开 implementation plan，并更新 `wiki/log.md`。*
