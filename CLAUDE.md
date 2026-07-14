# 语言设定与核心角色 (Global Rules)
- **语言指令**：无论输入何种语言，你必须始终使用**简体中文**进行思考、回复和知识库的编写。
- **角色定义**：你正在维护一个 **LLM Wiki**（根据 [Karpathy 的规范](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f))，你的任务是将碎片化的信息编译成结构化、高度相互链接的 Obsidian 知识库。

# 核心目录与权限边界 (Immutability & Architecture)
你必须严格遵守以下文件操作权限，这是不可逾越的底线：

- `/raw/` (不可变层 - Immutable)：
  - **正文只读**。这里存放我的原始素材、网页剪藏和自媒体文案；禁止修改原文内容。
  - `09-archive/` 为已处理归档：`/ingest` 可将 inbox 文件**移动**至此，但不得改写正文。
  - **读权限**：`/ingest` 与 `/lint` 不读 archive 正文；`/query` 与 `/update` 可按需读取 archive **单篇**用于核对与补编。
- `/assets/` (媒体资产层)：
  - 存放图片、PDF和媒体。引用时使用 Obsidian 标准语法 `![[文件名称.png]]`。
- `/wiki/` (编译输出层 - You Own This)：
  - 这是你的专属工作区。你需要在此处创建、更新、提炼知识并解决矛盾。

# Wiki 核心文件契约 (The Wiki Schema)
当你在 `/wiki/` 中工作时（尤其是执行写入操作后），必须维护以下基石：

1. **`wiki/index.md` (总目录)**：
   每次向 wiki 新增知识页后，必须同步更新此文件，将其按分类加入目录中。
   格式要求： [[页面名称]] — 一句话描述。
    - Entities / Concepts / Domains: 使用 TitleCase 命名。
    - Sources / Claims / Syntheses: 使用 kebab-case 命名（Claims 建议前缀 `claim-`）。
    范例：
    ```markdown
    # Wiki Index

    ## Sources
    - [[摘要-source-slug]] — 该资料的核心主旨摘要。

    ## Claims
    - [[claim-example-slug]] — 一句话陈述该关键判断/结论。

    ## Entities
    - [[EntityName]] — 该实体的身份定义或核心功能。

    ## Concepts
    - [[ConceptName]] — 该概念或框架的核心定义。

    ## Domains
    - [[DomainName]] — 该主题/领域的一句话定位。

    ## Syntheses
    - [[synthesis-slug]] — 该页面回答的复杂问题。
    ```
2. **`wiki/log.md` (操作日志)**：
   只能追加写入（Append-only）。每次操作后记录：`## [YYYY-MM-DD] <动作> | <操作简述>`。
   操作类型： ingest, query, update, lint, sync
   范例：
   ```markdown
   ## [2026-04-11] ingest | 引入项目 Claude Code 核心概念
   - **变更**: 新增 [[ClaudeCode]], [[摘要-claude-code-docs]], [[claim-example]]; 更新 [[index.md]]
   - **冲突**: 无 (或: 冲突 [[RAG架构]], 已标注)

   ## [2026-04-11] query | 解析 Karpathy LLM-Wiki 理念
   - **输出**: 已保存至 [[分析-karpathy-wiki-philosophy]]
   - **缺口**: 无

   ## [2026-04-11] update | 从原文补编 Chain_of_Thought 边界条件
   - **变更**: 更新 [[Chain_of_Thought]]; 新增 [[claim-cot-boundary]]; 依据 `raw/09-archive/...`
   - **来源问题**: 推理模型是否仍需显式 CoT
   - **冲突**: 无

   ## [2026-04-11] lint | 周度健康检查
   - **结果**: 修复 2 处死链，发现 1 个孤儿页面 [[UnlinkedPage]]
   ```
3. **内容分类**：
   - `/wiki/sources/`：存放从 `raw/` 提炼出的原始素材摘要（一对一）。
   - `/wiki/claims/`：存放从原材料提取的**关键判断/结论**（可审计的原子断言）。
   - `/wiki/entities/`：存放人物、公司、工具、产品（如 `Claude_Code.md`）。
   - `/wiki/concepts/`：存放概念、框架、方法论（如 `Agent_Skill.md`）。
   - `/wiki/domains/`：存放某个**主题/领域**的综合导航页（聚合相关概念、实体、claim）。
   - `/wiki/syntheses/`：存放针对复杂提问生成的深度综合分析。
4. **Claims（关键判断）页面规范**：
   - **是什么**：原文中可独立成立的关键判断、结论或可检验断言；不是空泛主题介绍。
   - **必须包含**：
     1. **一句话摘要**（可作 index 描述，也可作页面首段/标题含义）
     2. **正文内容**（展开该判断的含义、条件、适用范围）
     3. **回链到 Source**：`## 关联连接` 中至少一条 `[[摘要-...]]`，且 frontmatter `sources:` 指向对应 raw/archive 路径
     4. **出处锚点**：`## 出处锚点` 写明可定位原文的线索（章节标题、关键原句引用、页码/段落位置等）；无法精确定位时写明「整篇主旨性结论」并仍保留 source 回链
   - **命名**：kebab-case，建议 `claim-{简短语义slug}.md`
   - **冲突**：与已有 claim 矛盾时，不得静默覆盖；使用 `## 知识冲突` 或新建 claim 并在双方互链说明
5. **Domains（领域综合）页面规范**：
   - **是什么**：某一主题/领域的「地图页」，用于导航与总览，不替代 Sources 的保真摘要，也不替代 Claims 的原子断言。
   - **必须包含**：
     1. **一句话摘要**（领域定位，同步写入 index）
     2. **概述**（该领域覆盖什么、边界是什么）
     3. **相关双链**：概念、实体、claim（可选：关键 sources / syntheses）
   - **命名**：TitleCase（如 `Prompt_Engineering.md`、`Agent_Memory.md`）
   - **维护**：ingest/update 发现新的相关 concept/entity/claim 时，应增量挂到对应 Domain 的关联区；Domain 不存在且主题已成体系时可新建
6. **强制双向链接**：
   每一个 wiki 页面必须包含 `## 关联连接` 区域，使用 Obsidian 双链 `[[页面名称]]` 链接到其他相关页面。绝不能产生孤岛页面。
   - Claim **必须**回链至少一个 Source 摘要页
   - Domain **必须**链接其覆盖的 Concepts / Entities / Claims（至少一类非空）
7. **矛盾处理原则**：
   如果新摄入的知识与旧知识冲突，不要静默覆盖。在页面中新建 `## 知识冲突` 区块，将两种说法都保留并做对比。

# 工作流指令说明 (Workflows / Skills)
当被要求执行以下操作时，请遵循核心逻辑（由 `.claude/skills/` 下对应技能细则接管）：

- `/ingest <路径>`：读取指定的 `raw/` **inbox** 文件（排除 `09-archive/`），提炼 Sources / Claims / Entities / Concepts，并视需要更新 Domains；归档后把 `sources:` 更新为 archive 路径。必须更新 index 和 log。本流程不读 archive 正文。
- `/query <问题>`：通过读取 `wiki/index.md` 寻找相关 Sources / Claims / Entities / Concepts / Domains / Syntheses 并回答。若 wiki 有缺口，允许读 `raw/09-archive/` 核对原文：无则声明未找到；有则调用 `/update` 补编后再答。
- `/update`：在已确认「原文有、wiki 无」后，定向补编（含 Claim / Domain 等落点），并更新 index 与 log。可由 query 调用，也可由用户显式触发。
- `/lint`：全局扫描 `wiki/`，找出孤岛、死链、未同步索引、过时/死 sources 路径、**缺少出处锚点或未回链 Source 的 Claim**、**关联区为空的 Domain**，以及知识冲突；不读 archive 正文。

# 页面 Frontmatter (YAML) 规范
所有生成的 wiki 页面必须包含以下 YAML 头部：
---
title: "页面标题"
type: concept | entity | source | claim | domain | synthesis
tags: [知识标签]
sources: [关联的raw文件相对路径]
last_updated: YYYY-MM-DD
---

补充约定：
- `type: claim`：`sources:` **必填**（至少一个 raw/archive 路径）；正文必须有 `## 出处锚点`。
- `type: domain`：`sources:` 可为聚合列表或留空数组；正文必须有 `## 概述` 与非空的 `## 关联连接`。
