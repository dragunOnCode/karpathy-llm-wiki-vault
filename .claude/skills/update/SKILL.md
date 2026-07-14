---
name: update
description: 根据已确认的原文证据，定向补编 wiki（摘要/断言 Claim/实体/概念/领域 Domain/综合）。由 /query 在发现「wiki 缺口但 archive 原文有相关内容」后调用；也可由用户显式执行 /update。允许读取 raw/09-archive/ 单篇原文进行核对与提炼，禁止对 archive 做全量再 ingest。当用户提到「补编」「回填」「根据原文更新索引」时应触发。
user-invocable: true
---

# update 技能

## 核心目标

在 **query 已确认「wiki 未覆盖、但 archive 原文有相关内容」** 之后，把缺失知识点定向写回 wiki，并更新 `index.md` / 双链 / `log.md`。

本技能 **不做主动发现**：不负责判断「用户问题在 wiki 里有没有答案」。发现与核对由 [[query]] 完成；本技能只负责 **补编写入**。

## 权限边界

| 允许 | 禁止 |
|------|------|
| 按路径读取 `raw/09-archive/` 下的 **单篇** 原文 | 对 `09-archive/` 做 inbox 式全量 `/ingest` |
| 增量更新 `wiki/sources/`、`wiki/claims/`、`wiki/entities/`、`wiki/concepts/`、`wiki/domains/`、`wiki/syntheses/` | 修改 `raw/` 下任何文件正文 |
| 更新 `wiki/index.md`、追加 `wiki/log.md` | 无用户确认时静默覆盖已有知识 |
| 独立 `/update`（用户已指定目标页或原文） | 凭模型记忆编造原文没有的内容；创建无出处锚点的 Claim |

## 触发逻辑

1. **由 query 调用**：query 已定位候选原文、确认原文含相关内容后，加载并遵循本技能。
2. **用户执行 `/update`**：需提供目标（页面双链、摘要/claim slug、Domain、或 archive 文件路径）及要补的主题。
3. **隐式触发**：用户说「根据原文把这个补进知识库」「回填到概念页」「提炼成 claim」等。

## 调用时传入上下文（由 query 或用户提供）

执行前必须具备：

- **用户问题 / 缺口主题**
- **候选原文路径**（优先 `raw/09-archive/...`；若 frontmatter 仍是旧 inbox 路径，先按文件名在 archive 中解析）
- **相关 wiki 页面**（若有）：`[[摘要-...]]`、`[[claim-...]]`、`[[Concept]]`、`[[Entity]]`、`[[Domain]]`
- **原文中与缺口相关的摘录或定位说明**（query 核对阶段已获得）

若缺少原文路径或主题，先向用户索取，再继续。

## 补编流水线

### 步骤 1：再次核对原文（只读）

读取指定 archive 文件，确认缺口内容确实存在。若无法打开文件或原文并无相关内容：

> 无法完成补编：原文不可用或不含该主题。

然后终止，不写 wiki。

### 步骤 2：提示用户选择落点（必须确认）

向用户展示缺口摘要与原文依据，请选择（可多选）：

```text
已确认原文含相关内容。请选择补编落点：
A) 更新对应 摘要-*.md（来源保真）
B) 新建或更新 Claim（关键判断；须 Source 回链 + 出处锚点）
C) 增量更新已有 concept/entity（可复用知识）
D) 新建 concept/entity（新知识点）
E) 新建或更新 Domain（领域地图：挂概念/实体/claim）
F) 写入 wiki/syntheses/（本轮综合结论）
G) 取消，不修改 wiki
H) 与现有说法冲突 → 走冲突流程
```

**未获用户选择前，禁止写入。**

### 步骤 3：按选择写入 wiki

遵循 `CLAUDE.md` 的 Frontmatter、`## 关联连接`、命名规范。

| 选择 | 动作 |
|------|------|
| A | 增量补充对应 `wiki/sources/摘要-*.md`；`sources:` 使用 **archive 最终路径** |
| B | 新建或更新 `wiki/claims/claim-*.md`：**必须**含一句话摘要、内容、`## 出处锚点`、回链 `[[摘要-...]]` |
| C | 读取已有页面，增量合并；不删除既有有效信息；可挂相关 claim |
| D | 新建 concept/entity，并挂上与摘要/claim/domain 的双链 |
| E | 新建或更新 Domain：一句话摘要 + 概述 + 关联概念/实体/claim |
| F | 创建 synthesis，并链回相关 concept/claim/source |
| H | 在目标页（含 claim）新增 `## 知识冲突`，保留双方说法 |

**Claim 写入检查清单（选 B 时必过）：**
- [ ] `type: claim`
- [ ] `sources:` 指向 archive 路径
- [ ] `## 一句话摘要` / `## 内容` / `## 出处锚点` / `## 关联连接`
- [ ] 关联区含 `[[摘要-...]]`

**Domain 写入检查清单（选 E 时必过）：**
- [ ] `type: domain`
- [ ] `## 一句话摘要` / `## 概述` / `## 关联连接`
- [ ] 关联区至少包含 Concepts、Entities、Claims 中的一类非空链接

`sources:` 字段示例：

```yaml
sources: [raw/09-archive/The Complete Prompt Engineering Guide (2025).md]
```

### 步骤 4：更新注册表

- 新页面 → 写入 `wiki/index.md` 对应分类（含 **Claims** / **Domains**）
- 所有变更 → 追加 `wiki/log.md`：

```markdown
## [YYYY-MM-DD] update | <操作简述>
- **变更**: 更新 [[PageName]]; 新增 [[claim-...]]; 依据 `raw/09-archive/...`
- **来源问题**: <query 缺口主题或用户指定主题>
- **冲突**: 无 (或: 冲突 [[Page]], 已标注)
```

### 步骤 5：交还 query（若由 query 调用）

补编完成后，回到 query 流程：基于 **更新后的 wiki** 重新综合回答，并使用 `[[wikilink]]` 引用（优先引用 Claim 作为可审计结论）。

## 冲突处理流程

与 ingest 一致：

1. **暂停**写入覆盖
2. **报告**冲突点
3. **询问**：A) 双说并存（`## 知识冲突`）B) 用新知识覆盖 C) 放弃本次 update
4. 按用户选择继续或终止

## 与其他技能的关系

- [[ingest]] — 初次全量编译 inbox；**不对 archive 全量再编译**
- [[query]] — 发现 wiki 缺口并核对原文；确认有原文后调用本技能
- [[lint]] — 结构健康检查；校验 Claim 锚点与 Domain 关联；不读 archive 正文

## 强制约束

- **禁止主动发现**：不扫描整个 archive「找还能补什么」
- **禁止无证据写入**：补编内容必须能在指定原文中找到依据
- **禁止无锚点 Claim**：没有出处锚点与 Source 回链则不得写入
- **禁止孤岛页面**：新页必须含 `## 关联连接`
- **使用简体中文**编写 wiki 正文
