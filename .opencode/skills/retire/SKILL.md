---
name: retire
description: 当用户使用 /retire，或要求下架、退役、老化、隔离过时/错误/不再适用的 wiki 知识页，或按 source/关键词清理活跃知识时调用。只治理 wiki/ 编译层，不修改 raw/ 原文。
user-invocable: true
---

# retire 技能

## 核心目标

将已经过时、错误、不再适用、来源废弃，或不应继续参与可信回答的 wiki 页面，从**活跃知识库**中下架。retire 的目标是“保留可审计历史，同时切断活跃依赖”，不是删除原文，也不是强行生成替代页面。

## 触发场景

- `/retire [[PageName]]`：退役明确指定的单个 wiki 页面。
- `/retire --source <raw-path-or-source-page>`：按来源查找候选页面，适合一次 ingest 产物治理。
- `/retire --match "关键词"`：按关键词查找候选页面，只产出候选清单，等待确认。
- `/retire --confirm`：用户确认上一轮退役计划后，才执行写入。
- 用户说“这个知识过时了”“这批页面不要再被 query 用到”“把某来源编译出的 wiki 下架”。

## 权限边界

| 允许 | 禁止 |
|------|------|
| 读取 `wiki/index.md`、`wiki/` 页面与 `wiki/log.md` | 修改 `raw/` 原文或移动 `raw/` 文件 |
| 扫描 wiki 双链、frontmatter、`sources:` 路径 | 对 `raw/09-archive/` 做全量读取 |
| 修改 wiki 页面 frontmatter、正文退役说明、活跃双链、`wiki/index.md`、`wiki/retired.md` | 未经用户确认就批量写入 |
| 追加 `wiki/log.md` | 把 retire 当作测试现场重置或 hard delete |

**绝对规则**：retire 不修改 raw。raw 是不可变来源层；retire 只处理 `wiki/` 编译层。

## 页面状态语义

| 状态 | 含义 | query 行为 |
|------|------|------------|
| `status: active` | 当前可信知识；缺省状态 | 默认可检索、可引用 |
| `status: retired` | 已下架；保留历史与来源 | 默认跳过；仅在用户明确“查历史/包含退役”时读取 |
| `status: needs_review` | 候选退役或可信度待确认 | query 可谨慎说明不确定性，优先提示需复核 |

没有替代页也可以退役。此时使用：

```yaml
status: retired
retired_at: YYYY-MM-DD
retired_reason: "下架原因"
superseded_by: []
```

不要为了填 `superseded_by` 而强行创建新页面。

## 候选发现

### 1. 总是先读 index

读取 `wiki/index.md`，以活跃目录作为候选入口。retired 页面通常已不在活跃 index 中；若用户明确查历史，再读取 `wiki/retired.md`。

### 2. 按入口定位候选

| 入口 | 候选发现方式 |
|------|--------------|
| `/retire [[PageName]]` | 解析双链对应页面，读取页面 frontmatter、正文摘要与 `## 关联连接` |
| `/retire --source <path>` | 扫描 wiki 页 frontmatter `sources:` 和 Source 摘要页，匹配完整路径、archive 路径、同名文件 |
| `/retire --match "关键词"` | 使用搜索工具在 `wiki/` 的标题、路径、frontmatter、正文中找命中；只读取命中页 |

`--source` 的默认判断：
- Source 页面本身：可退役候选。
- 只由该 source 支撑的 Claim：可退役候选。
- Concept / Entity / Domain：如果仍有其他活跃 source 或活跃页面依赖，默认标为 `needs_review`，不要自动退役。

### 3. 做反向链接影响分析

对每个候选页面，搜索 `[[PageName]]` 的反向链接，并区分：

| 来源页面 | 处理 |
|----------|------|
| `status: retired` 页面 | 可保留历史链接 |
| 活跃 Source / Claim / Concept / Entity / Domain / Synthesis | 判断是否把候选页作为当前依据 |
| `wiki/index.md` | 必须从活跃分类移除 |
| `wiki/retired.md` | 确认写入后应登记 |

活跃页面若在“核心结论、关联连接、当前做法、依据”等区域链接 retired 页面，必须纳入计划：删除该活跃依赖、改为替代页，或移入“历史/退役引用”并明确标注。

## 写入前确认

除非用户已经使用 `/retire --confirm` 明确确认，否则只能输出退役计划，不能写文件。

计划格式：

```markdown
## 退役候选计划

| 页面 | 类型 | 建议状态 | 命中原因 | 替代页面 | 活跃反向链接 | 处理建议 |
|------|------|----------|----------|----------|--------------|----------|
| [[claim-old]] | claim | retired | 来自废弃 source | 无 | [[DomainA]] | 从 DomainA 当前依据中移除 |

确认后请回复：`/retire --confirm`
```

如果无法判断，应建议 `needs_review`，而不是冒险退役。

## 确认后的写入

### 1. 更新候选页面

对每个确认退役页：

1. 保留原文件路径，不物理删除。
2. 更新 frontmatter：
   - `status: retired`
   - `retired_at: YYYY-MM-DD`
   - `retired_reason: "<用户确认的原因>"`
   - `superseded_by: []` 或 `["[[NewPage]]"]`
   - `last_updated: YYYY-MM-DD`
3. 在正文 frontmatter 后加入或更新：

```markdown
## 退役说明

该页面已退役，不再作为当前知识库的可信依据。
- **退役时间**: YYYY-MM-DD
- **退役原因**: <原因>
- **替代页面**: 无
- **查询行为**: `/query` 默认跳过本页；只有用户明确要求查历史或包含退役内容时才读取。
```

4. 页面原有 `## 关联连接` 通常保留，用于审计历史。

### 2. 清理活跃入口和活跃依赖

- 从 `wiki/index.md` 的活跃分类中移除退役页。
- 更新或创建 `wiki/retired.md`，追加退役页、原因、替代页、原类型。
- 处理活跃页面中的反向链接：
  - 有替代页：将当前依据链接改为替代页。
  - 无替代页：从“当前依据/核心结论/关联连接”等活跃依赖位置移除该链接。
  - 需要保留历史：移入 `## 历史/退役引用`，并写明该页面已 retired。

### 3. 追加日志

在 `wiki/log.md` 末尾追加：

```markdown
## [YYYY-MM-DD] retire | <操作简述>
- **退役**: [[PageA]], [[PageB]]
- **原因**: <用户确认的原因>
- **替代**: 无 | [[NewPage]]
- **影响处理**: 从 [[DomainA]] 移除活跃依赖；更新 [[retired.md]]
```

## 与其他技能的关系

- [[query]]：默认跳过 `status: retired` 页面；用户明确查历史时可读取并标注为退役内容。
- [[lint]]：检查 retired 页面是否有 `## 退役说明`、是否登记到 `wiki/retired.md`、活跃页面是否仍依赖 retired 页面。
- [[update]]：若新证据足以替代退役知识，应新建/更新 active 页面，而不是直接把 retired 页面当正常页面继续补写。
- [[ingest]]：新 ingest 若命中已 retired 的相似主题，应提示存在退役历史，避免静默复活旧知识。

## 强制约束

- 禁止修改、移动或删除 `raw/` 文件。
- 禁止在没有用户确认时批量写入。
- 禁止把 retire 用作 eval/reset；反复测试应使用 disposable git worktree 或专用清理脚本。
- 禁止强行创建替代页；没有新可信结论时使用 `superseded_by: []`。
- 禁止让活跃页面继续把 retired 页面当作当前依据。
- 所有输出和 wiki 正文使用简体中文。

## 关联连接

- [[wiki/index.md]] — 活跃知识入口
- [[wiki/retired.md]] — 退役页面登记入口
- [[wiki/log.md]] — append-only 操作日志
- [[query]] — 可信问答入口
- [[lint]] — 健康检查入口
