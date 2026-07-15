# LLM Wiki 试点问题集

## 范围

- 产品手册：MacBook Air 入门指南，来源位于 `raw/09-archive/`
- 设计文档：Kubernetes KEP-3140 TimeZone support in CronJob，来源位于 `raw/04-design-docs/`
- 操作指导书：Kubernetes Debug Running Pods、GitLab Runner Troubleshooting，来源位于 `raw/05-operation-guides/`

## 评分规则

- 正确性：0=错误或无依据；1=部分正确；2=正确且覆盖关键限制。
- 来源锚点：0=无来源；1=只有 Source；2=可定位章节、页码或原文片段。
- 风险完整性：0=遗漏关键前置条件、风险、回滚或安全提醒；1=部分覆盖；2=完整覆盖。

## 运行模式

- `direct_raw`：先定位候选 raw，再读取原文回答。
- `rag_like`：使用外部检索或简单全文检索定位资料后回答，作为传统知识库对照。
- `llm_wiki_lite`：遵循 `wiki/index.md -> 少量 wiki 页面 -> 必要时单篇 raw 回读`。

## 验收覆盖

- 单文档事实：`Q-PM-001` 至 `Q-PM-005`
- 设计约束：`Q-DD-001` 至 `Q-DD-005`
- 操作前置条件、风险和排障：`Q-OP-001` 至 `Q-OP-006`
- 跨文档综合：`Q-XD-001` 至 `Q-XD-003`
- 来源变更后回源：`Q-SRC-001`

## Q-PM-001

- 类型：产品手册单文档事实
- 问题：MacBook Air 可以通过哪些端口或线缆给电池充电？
- 标准答案要点：可以使用 USB-C 转 MagSafe 3 连接线连接 MagSafe 3 端口；也可以用 USB-C 充电线连接任一雷雳端口；线缆需要连接 Apple 电源适配器或其他兼容电源适配器，并接入交流电源。
- 可接受来源：`raw/09-archive/005-给-MacBook-Air-电池充电.md`，章节 `## 连接电源适配器和线缆`。

## Q-PM-002

- 类型：产品手册单文档事实
- 问题：70W USB-C 电源适配器对 MacBook Air 的快充能力是什么？
- 标准答案要点：13 英寸和 15 英寸 MacBook Air 可选配 70W USB-C 或 67W USB-C 电源适配器；使用 70W USB-C 电源适配器可在约 30 分钟充至最高 50% 电量；原文还注明并非所有国家或地区都可用。
- 可接受来源：`raw/09-archive/005-给-MacBook-Air-电池充电.md`，章节 `## 适用于 MacBook Air 的电源适配器和线缆`，以及文末脚注。

## Q-PM-003

- 类型：产品手册单文档事实
- 问题：MacBook Air 最多支持多少台外接显示器？对应的最高分辨率和刷新率限制是什么？
- 标准答案要点：最多两台外接显示器；两台外接显示器最高为 6K 60 Hz 或 4K 144 Hz；一台外接显示器最高为 8K 60 Hz、5K 120 Hz 或 4K 240 Hz；支持通过单个雷雳端口连接最多两台外接显示器。
- 可接受来源：`raw/09-archive/014-将外接显示器连接到-MacBook-Air.md`，章节 `## 步骤 2：查看 Mac 支持多少台显示器`。

## Q-PM-004

- 类型：产品手册单文档事实
- 问题：从 Windows 转到 Mac 时，常用快捷键中的 Control 和 Alt 通常分别对应 Mac 上的什么按键？
- 标准答案要点：Windows 上多数快捷键里的 Control 通常替换为 Mac 的 Command；Windows 上的 Alt 可时常替换为 Mac 的 Option；例如 Command-C/Command-V 对应复制粘贴，Option-E 可输入带重音字符。
- 可接受来源：`raw/09-archive/011-从-Windows-转而使用-Mac.md`，章节 `## Mac 上的按键和快捷键`。

## Q-PM-005

- 类型：产品手册单文档事实
- 问题：触控 ID 在 MacBook Air 启动或重启后的第一次登录有什么限制？
- 标准答案要点：触控 ID 可以用于开机、解锁、Apple Pay 和认证操作；但启动或重启 MacBook Air 后需要先键入密码才能登录，完成初始登录后才能使用触控 ID 登录。
- 可接受来源：`raw/09-archive/003-适用于-MacBook-Air-的妙控键盘.md`，章节 `## 触控 ID（电源按钮）`。

## Q-DD-001

- 类型：设计文档目标
- 问题：KEP-3140 要给 Kubernetes CronJob 增加什么能力？
- 标准答案要点：为 CronJob 增加 `.spec.timeZone` 字段，使用户可以指定有效的 TimeZone 名称；CronJob controller 根据该时区解释 schedule；未指定时保持原行为，依赖 kube-controller-manager 进程的时区。
- 可接受来源：`raw/04-design-docs/kep-3140-cronjob-timezone-support.md`，章节 `## Summary`、`### Goals`、`## Proposal`。

## Q-DD-002

- 类型：设计约束
- 问题：KEP-3140 对 `.spec.timeZone` 的合法性如何验证？
- 标准答案要点：`TimeZone` 字段会使用嵌入的 Golang 时区数据库验证；若指定了无效时区，API server 会拒绝请求。
- 可接受来源：`raw/04-design-docs/kep-3140-cronjob-timezone-support.md`，章节 `### CronJob API`。

## Q-DD-003

- 类型：设计风险
- 问题：KEP-3140 识别了哪些主要风险，分别如何缓解？
- 标准答案要点：Golang 或系统时区数据库过期会导致调度时间错误，缓解方式是保持数据库更新；恶意用户创建多个不同时区 CronJob 可能导致大量 CronJob，缓解方式是使用 ResourceQuota 限制每用户可创建数量。
- 可接受来源：`raw/04-design-docs/kep-3140-cronjob-timezone-support.md`，章节 `### Risks and Mitigations`。

## Q-DD-004

- 类型：设计回滚
- 问题：如果启用 CronJob TimeZone 后再禁用，文档描述的回滚行为是什么？
- 标准答案要点：没有设置 TimeZone 时行为不变；设置了有效 TimeZone 时，新创建的 Jobs 会回到旧行为，即像没有设置 TimeZone 一样触发；重新启用后会回到禁用前的行为。
- 可接受来源：`raw/04-design-docs/kep-3140-cronjob-timezone-support.md`，章节 `###### Can the feature be disabled once it has been enabled` 与 `###### What happens if we reenable the feature if it was previously rolled back?`。

## Q-DD-005

- 类型：设计取舍
- 问题：KEP-3140 为什么没有选择把时区写成相对 UTC 的偏移量？
- 标准答案要点：替代方案是用 UTC offset 指定时区，但使用标准时区名称能在 Daylight Saving Time 场景中提供更一致的体验，因此该替代方案被放弃。
- 可接受来源：`raw/04-design-docs/kep-3140-cronjob-timezone-support.md`，章节 `## Alternatives`。

## Q-OP-001

- 类型：操作指导前置条件
- 问题：Kubernetes 的 Debug Running Pods 指南适用于什么前置条件？如果 Pod 还没 Running 应先看哪里？
- 标准答案要点：该指南用于调试已经调度并正在运行的 Pod；如果 Pod 尚未运行，应先从 Debugging Pods 开始；如果需要进入 Node，需要能定位 Pod 所在 Node 并有 shell 访问权限。
- 可接受来源：`raw/05-operation-guides/kubernetes-debug-running-pods.md`，章节 `## prerequisites`。

## Q-OP-002

- 类型：操作排障
- 问题：遇到 Pending Pod 时，应如何用 Kubernetes 事件判断原因，并且事件查询有什么命名空间注意事项？
- 标准答案要点：用 `kubectl describe pod <pod>` 查看 Events，`FailedScheduling` 等事件及 Message 会说明无法调度原因；也可用 `kubectl get events` 列出事件；事件是 namespaced 的，排查特定命名空间对象时必须显式指定 namespace。
- 可接受来源：`raw/05-operation-guides/kubernetes-debug-running-pods.md`，章节 `## Example: debugging Pending Pods`。

## Q-OP-003

- 类型：操作排障
- 问题：容器曾经崩溃过时，如何查看上一次崩溃的日志？
- 标准答案要点：先用 `kubectl logs ${POD_NAME} -c ${CONTAINER_NAME}` 看受影响容器当前日志；若容器以前崩溃过，使用 `kubectl logs ${POD_NAME} -c ${CONTAINER_NAME} --previous` 查看上一个容器实例的崩溃日志。
- 可接受来源：`raw/05-operation-guides/kubernetes-debug-running-pods.md`，章节 `## Examining pod logs {#examine-pod-logs}`。

## Q-OP-004

- 类型：操作排障
- 问题：什么时候应该考虑 Kubernetes ephemeral debug container，而不是直接 `kubectl exec`？
- 标准答案要点：当 `kubectl exec` 不够用时，例如容器已崩溃，或镜像不包含 shell/debug 工具；可用 `kubectl debug` 加入 ephemeral container；`--target` 用来定位另一个容器的进程命名空间，但如果运行时不支持，debug container 可能无法看到目标容器进程。
- 可接受来源：`raw/05-operation-guides/kubernetes-debug-running-pods.md`，章节 `## Debugging with an ephemeral debug container {#ephemeral-container}`。

## Q-OP-005

- 类型：操作安全风险
- 问题：GitLab Runner 的 debug logging 为什么有安全风险？应该注意什么？
- 标准答案要点：debug logging 输出会包含 job 可用的变量和其他 secrets；应禁用可能把这些信息暴露给第三方的日志聚合；masking 只保护 job log，不保护 container logs。
- 可接受来源：`raw/05-operation-guides/gitlab-runner-troubleshooting.md`，章节 `## Enable debug logging mode`。

## Q-OP-006

- 类型：操作排障
- 问题：GitLab Runner 与 GitLab 的网络路径问题可能怎样影响 artifact upload 调试？
- 标准答案要点：artifact upload 是从执行器环境发起：Shell executor 从脚本运行环境上传，Docker executor 从 Docker container 上传，Kubernetes executor 从 build pod 上传；build 环境到 GitLab 的网络路径可能与 GitLab Runner 到 GitLab 的路径不同；可启用 debug logging 查看 upload URL 和 HTTP status，但 response body 调试日志最多 512 bytes 且可能暴露敏感数据。
- 可接受来源：`raw/05-operation-guides/gitlab-runner-troubleshooting.md`，章节 `## I am seeing other artifact upload errors, how can I further debug this?`。

## Q-XD-001

- 类型：跨文档综合
- 问题：MacBook Air 的“先用 wiki 回答、必要时回读原文”的查询，如果用户问“外接显示器黑屏或分辨率低，还可能和线缆或转换器有关吗”，应综合哪些资料？
- 标准答案要点：应综合外接显示器连接指南中的线缆、转换器、端口匹配、最高分辨率/刷新率和故障排除入口；必要时可回读雷雳端口或转换器章节；回答不应只引用单个 claim，而应说明要检查电源、端口、线缆/转换器匹配和显示器设置。
- 可接受来源：`raw/09-archive/014-将外接显示器连接到-MacBook-Air.md`，章节 `## 开始之前`、`## 步骤 2：查看 Mac 支持多少台显示器`、`## 步骤 3：确保有合适的线缆和转换器`、`## 需要更多帮助？`；可选 `raw/09-archive/aside-007-雷雳-4-(USB-C)-端口.md`。

## Q-XD-002

- 类型：跨文档综合
- 问题：同样是“时区”，Kubernetes CronJob KEP 和 GitLab Runner Troubleshooting 中的 zoneinfo 问题有什么不同？
- 标准答案要点：KEP-3140 是 CronJob API/控制器设计，用 `.spec.timeZone` 明确指定调度时区并由 API server/controller 验证和使用；GitLab Runner 的 `zoneinfo.zip` 问题是 Runner 运行环境缺失时区数据库导致使用 `Timezone` 或 `OffPeakTimezone` 时崩溃，解决方式是安装系统时区包或提供 `zoneinfo.zip`/`ZONEINFO` 环境变量。两者都涉及时区数据库，但一个是 Kubernetes API 设计约束，一个是 Runner 运维故障处理。
- 可接受来源：`raw/04-design-docs/kep-3140-cronjob-timezone-support.md`，章节 `### CronJob API`、`### Dependencies`、`### Troubleshooting`；`raw/05-operation-guides/gitlab-runner-troubleshooting.md`，章节 ``## Error: `zoneinfo.zip: no such file or directory` error when using `Timezone` or `OffPeakTimezone` ``。

## Q-XD-003

- 类型：跨文档综合
- 问题：Debug Running Pods 和 GitLab Runner Troubleshooting 在启用更高诊断能力时，各自提醒了哪些清理或安全风险？
- 标准答案要点：Kubernetes debug 指南多次提醒调试 Pod 或复制 Pod 后要清理；使用 sysadmin profile 可让 ephemeral container 拥有 privileged container 的 full capabilities；GitLab Runner debug logging 可能泄露 variables/secrets，应控制日志聚合并及时关闭。回答需要分别说明资源清理风险和敏感信息泄露风险。
- 可接受来源：`raw/05-operation-guides/kubernetes-debug-running-pods.md`，章节 `## Debugging with an ephemeral debug container`、`## Debugging using a copy of the Pod`、`## Debugging a Pod or Node while applying a profile`；`raw/05-operation-guides/gitlab-runner-troubleshooting.md`，章节 `## Enable debug logging mode`。

## Q-SRC-001

- 类型：来源变更后回源
- 问题：如果一个 Source 摘要页的 `sources:` 指向归档后的 MacBook Air 电池充电章节，query/update 回读原文时应如何定位到原始证据？
- 标准答案要点：不扫描整个 archive；从 Source/frontmatter 或 manifest 记录的 `source_current_path`/`sources:` 读取单篇归档 raw；用 raw 路径和章节锚点定位证据，例如 `raw/09-archive/005-给-MacBook-Air-电池充电.md` 的 `## 适用于 MacBook Air 的电源适配器和线缆`；必要时用 sha256 或 manifest 校验来源版本。
- 可接受来源：`AGENTS.md` 的 `/query` 与 `/update` 规则；`docs/research/llm-wiki-practice-evidence.md` 中关于 source-first/provenance 的结论；`raw/09-archive/005-给-MacBook-Air-电池充电.md`。

## Reviewer Checklist

- 每题的标准答案可以在“可接受来源”中定位。
- 每题不依赖公开资料以外的背景知识。
- 跨文档题至少需要两个来源才能完整回答。
- 操作题必须检查风险、前置条件或清理步骤。
- 删除无法定位到章节、页码或关键原句的题目。
