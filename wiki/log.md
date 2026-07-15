# Wiki 操作日志

---



---

## [2026-07-14] sync | 扩展 Wiki Schema：新增 Claims 与 Domains
- **变更**: 更新 [[CLAUDE.md]] 与 ingest/query/update/lint skills；新增目录 `wiki/claims/`、`wiki/domains/`；更新 [[index.md]] 分类骨架
- **说明**: Claim 须一句话摘要+内容+Source 回链+出处锚点；Domain 须一句话摘要+概述+概念/实体/claim 双链
- **冲突**: 无

## [2026-07-14] sync | 重命名配置入口：CLAUDE.md→AGENTS.md，.claude→.opencode
- **变更**: 全局规范改为 [[AGENTS.md]]；skills 目录迁至 `.opencode/skills/`；同步 README 与各 skill 内引用
- **冲突**: 无

## [2026-07-14] ingest | 批量摄取 MacBook Air 入门指南 45 章节（macOS Tahoe 26）
- **变更**: 新增 45 个 Source 摘要、15 个 Claim、8 个概念、3 个实体、1 个 Domain（[[MacBook_Air_Getting_Started]]）；同步更新 [[index.md]]
- **数量说明**: `raw/01-articles/` 下实际 `.md` 文件为 45 个（任务清单标注 46，差异为目录中另有 `manifest.json` 非素材文件）；已按章节一对一全量处理
- **实体**: [[Apple]]、[[MacBook_Air]]、[[macOS_Tahoe]]
- **概念**: [[Optimized_Battery_Charging]]、[[Force_Touch]]、[[Touch_ID]]、[[Migration_Assistant]]、[[System_Settings]]、[[Spotlight_Search]]、[[Control_Center]]、[[Time_Machine]]
- **Claims**: [[claim-macbook-air-thunderbolt-4-external-display]]、[[claim-magsafe-3-indicator-led]]、[[claim-optimized-battery-charging-delays-80pct]]、[[claim-touch-id-requires-password-after-reboot]]、[[claim-magic-keyboard-fn-key-customizable]]、[[claim-mac-replaces-windows-ctrl-with-command]]、[[claim-mac-replaces-windows-alt-with-option]]、[[claim-migration-assistant-from-windows]]、[[claim-apple-account-required-for-some-features]]、[[claim-magsafe-and-thunderbolt-both-charge]]、[[claim-70w-adapter-50pct-in-30min]]、[[claim-secure-boot-verifies-apple-authorized-os]]、[[claim-mac-operation-temp-10-to-35c]]、[[claim-external-display-max-2-up-to-6k]]、[[claim-energy-star-sleep-after-10min-idle]]
- **冲突**: 无
- **归档**: 已将 45 个 raw 文件从 `raw/01-articles/` 移动至 `raw/09-archive/`；所有 wiki 页 `sources:` 已写入 archive 路径
- **注意**: 本次 ingest 为新主题（MacBook Air），未与既有提示工程主题交叉链接
