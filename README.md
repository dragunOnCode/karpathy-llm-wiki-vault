# LLM Wiki 知识库

本项目是一个基于 [Karpathy 的 LLM Wiki 理念](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) 构建的 Obsidian 知识库。

## 核心理念

将碎片化的信息编译成**结构化、高度相互链接**的知识网络，便于 AI 辅助学习和研究。

## 目录结构

```

🏛️ 你的知识库文件夹 (LLM-Wiki-Vault)
├── 🖼️ assets/                   ← 统一媒体资源层：存放图片、PDF、附件（Obsidian设置附件路径至此）
│
├── 📥 raw/                      ← 原始资料收件箱（只读事实层，文件处理后移动至 archive）
│   ├── 📄 01-articles/          ← 网页剪藏、技术文章 (.md)
│   ├── 🎓 02-papers/            ← 论文、深度研报、PDF文档
│   ├── 🎙️ 03-transcripts/       ← 视频/播客转录文本、会议记录
│   ├── 💡 04-meeting_notes/     ← 头脑风暴或会议纪要等
│   └── 🗃️ 09-archive/           ← 已归档区：`/ingest` 执行成功后，源文件自动移动至此
│
├── 🧠 wiki/                     ← 知识编译输出层（LLM 拥有完全写权限，人类阅读层）
│   ├── 📑 index.md              ← 全局内容字典：记录所有 wiki 页面及其一句话索引
│   ├── 📜 log.md                ← 行为流水线：以 Grep-friendly 格式记录 ingest/query/update/lint 历史
│   ├── 🔍 sources/              ← 摘要层：针对 raw 文件的一对一核心观点提炼 
│   ├── 📌 claims/               ← 断言层：从原文提取的关键判断（须回链 Source + 出处锚点）
│   ├── 👥 entities/             ← 实体层：人名、公司、工具软件、项目 
│   ├── 🏗️ concepts/             ← 抽象层：方法论、架构模式、第一性原理 
│   ├── 🗺️ domains/              ← 领域层：主题综合导航页（聚合概念/实体/claim）
│   └── 💎 syntheses/            ← 综合层：针对复杂提问生成的深度研究报告 
│
├── 🤖 AGENTS.md                 ← 全局心智规范：定义语言协议、读写权限与 Wiki Schema（跨工具）
│
└── ⚙️ .opencode/                ← Agent 配置目录（skills 等）
    └── 🛠️ skills/               ← Agent Skill中心
        ├── ⚙️ ingest/           ← 自定义：编译收件箱 raw 文件到 wiki，并执行 09-archive 归档
        ├── 🔎 query/            ← 自定义：检索 wiki；缺口时读 archive 核对，有原文则调用 update
        ├── 🔧 update/           ← 自定义：按原文证据定向补编 wiki（由 query 或用户触发）
        └── 🩺 lint/             ← 自定义：知识体检，修复死链、补充 index、发现认知冲突
```


## 使用方式

在 Obsidian 中打开本 vault，配合支持 `AGENTS.md` 与 `.opencode/skills/` 的 Agent（如 OpenCode / Claude Code 等，按工具约定加载）执行操作。

### 常用命令

- `/query <问题>` — 在知识库中搜索相关内容；wiki 不足时核对 archive，必要时触发补编
- `/update` — 根据已确认的原文，定向补编摘要/断言/概念/实体/领域/综合
- `/ingest` — 将新的原始资料编译到知识库（含 Claims 与 Domains）
- `/lint` — 检查知识库健康度（死链、孤儿页面、sources 路径、Claim/Domain 契约）

### 技能分工（archive 权限）

| 技能 | 读 archive 正文 | 职责 |
|------|-----------------|------|
| ingest | 否 | inbox 初次全量编译并归档 |
| query | 是（按需单篇） | 检索 wiki；发现缺口后核对原文 |
| update | 是（按需单篇） | 原文确认后的定向补编写入 |
| lint | 否（仅路径存在性） | 结构与 provenance 健康检查 |

## 知识来源

- Google Gemini API 官方文档
- Anthropic Claude 最佳实践
- 各机构发布的 Prompt Engineering 白皮书
- 学术论文（如 5C Prompt Contracts）
