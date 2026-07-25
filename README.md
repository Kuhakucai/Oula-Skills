# Oula Skills

这是 **欧拉欧拉** 持续维护的个人 Agent Skill 收藏库，收录我在软件开发、产品设计和 Agent 工作流等真实任务中反复使用，并认为值得长期复用的方法。

我更关注 AI 能不能真正把事情做完：过程是否可靠、结果能否验证、方法是否可以被其他人复用。这个仓库就是这些实践的长期沉淀。

如果你第一次来到这里，不需要逐个阅读文件：先在下面找到自己想解决的问题，点击对应 Skill 即可查看完整说明。

## 快速找到你需要的 Skill

| 你想完成什么 | 推荐 Skill | 它能帮你做什么 | 使用前提 |
|---|---|---|---|
| 在行动前把方案、设计或想法彻底问清楚 | [grill-me](./grill-me/SKILL.md) | 一次只追问一个关键决策，主动给出建议，沿决策树消除歧义并形成共同理解 | 通用 Agent；无需外部依赖 |
| 先制定方案、评审后再写代码 | [verified-dev-flow](./verified-dev-flow/SKILL.md) | 用“计划 → 评审 → 实施 → 复核”闭环完成软件需求，保留完整过程记录 | 具备文件和终端能力的编码 Agent |
| 从产品想法产出专业 PRD | [prd-generator](./prd-generator/SKILL.md) | 通过问答补齐产品信息、功能需求、异常场景、竞品研究与验收标准 | 通用 Agent；竞品研究需要联网能力 |
| 分析产品、平台或公司竞争关系 | [competitive-analysis](./competitive-analysis/SKILL.md) | 使用 PEST、商业模式画布、KANO、SWOT 等框架生成证据驱动的竞品报告 | 需要可靠的信息检索能力 |
| 创建、改进或校验自己的 Skill | [skill-creator](./skill-creator/SKILL.md) | 初始化标准 Skill 目录，组织脚本、参考资料、资源并执行结构校验 | Python；校验脚本依赖 PyYAML |

## 按场景浏览

### 软件开发与 Agent 工程

#### [verified-dev-flow](./verified-dev-flow/README.md)

适合复杂功能开发、重要重构以及需要留下决策记录的任务。它将工作拆成计划编写、计划评审、代码实施和实施复核四个阶段；审查未通过时不会强制放行。

你可能会这样使用：

> 按计划走，先评审方案，再实现这个登录限流需求。

[查看完整 Skill](./verified-dev-flow/SKILL.md) · [安装与命令说明](./verified-dev-flow/README.md)

#### [skill-creator](./skill-creator/SKILL.md)

用于创建或维护跨 Agent 使用的通用 Skill，提供目录初始化、写作规范、资源组织和基础校验脚本。适合把重复工作沉淀成稳定、可复用的能力包。

你可能会这样使用：

> 帮我把这套发布流程整理成一个可复用的 Skill。

[查看完整 Skill](./skill-creator/SKILL.md)

### 思考澄清与决策

#### [grill-me](./grill-me/SKILL.md)

适合在开始写方案、做设计或执行重要决定之前，把隐藏假设、关键分支、依赖关系、边界条件和成功标准逐一问清楚。它每次只提出一个问题，同时给出明确的推荐答案与核心取舍；在你确认双方已经达成共同理解之前，不会直接进入执行。

你可能会这样使用：

> 用 grill-me 挑战一下我的 AI 产品方案，先把所有关键决策问透，不要急着开始实现。

[查看完整 Skill](./grill-me/SKILL.md)

### 产品设计与市场决策

#### [prd-generator](./prd-generator/SKILL.md)

适合从模糊产品想法开始，通过交互式问答逐步形成完整 PRD。覆盖产品背景、目标用户、用户痛点、功能流程、异常场景、非功能需求、竞品分析和评审清单。

你可能会这样使用：

> 我要做一个 AI 会议纪要工具，帮我从零整理一份 PRD。

[查看完整 Skill](./prd-generator/SKILL.md)

#### [competitive-analysis](./competitive-analysis/SKILL.md)

适合单个竞品深度拆解或多个产品横向比较，强调先确认分析范围，再进行资料采集和证据驱动的结论输出。支持快速分析与深度分析两种模式。

你可能会这样使用：

> 对比产品 A、产品 B 和我们的产品，重点分析商业模式与 AI 能力。

[查看完整 Skill](./competitive-analysis/SKILL.md)

## 如何使用

### 方式一：下载整个仓库

```bash
git clone git@github.com:Kuhakucai/Oula-Skills.git
cd Oula-Skills
```

选择需要的 Skill 目录，复制到目标 Agent 支持的 Skills 路径中。请保留目录内的 `SKILL.md`、`scripts/`、`references/` 和 `assets/` 等相对结构。

### 方式二：显式加载

如果你的 Agent 没有自动发现 Skill 的机制，可以让它读取对应目录的 `SKILL.md`，并明确要求按其中流程完成任务。

### verified-dev-flow 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/Kuhakucai/Oula-Skills/main/verified-dev-flow/install.sh | bash
```

详细参数见 [verified-dev-flow 安装说明](./verified-dev-flow/README.md)。

## 使用提醒

- 不同 Agent 对 Skill 的自动发现路径、工具名和权限机制可能不同，请按所用平台调整。
- 涉及联网研究、外部账号或 MCP 的 Skill，需要先配置相应能力和授权。
- Skill 会持续迭代；建议关注仓库更新，并在升级前查看目录内说明。
- 使用和分发前，请分别确认各 Skill 的许可证、数据来源及第三方依赖。

## 收录原则

- 我自己实际使用，并且确实能提升工作质量或效率。
- 任务边界清晰，触发场景容易判断。
- 过程尽可能可验证、可追溯，不用漂亮话代替证据。
- 优先保持通用性；必须依赖特定平台或 MCP 时明确说明。

## 关于维护者

我是 **欧拉欧拉**，长期关注 AI Agent、MCP、产品方法和个人内容创作。我会把自己实际跑通的流程整理成 Skill，继续在真实任务中使用、复盘和更新。

如果你也在探索怎样让 AI 从“能聊天”走向“能稳定完成工作”，可以收藏这个仓库。后续我会持续补充自己常用、好用并经过验证的 Skill；也欢迎你根据自己的工作方式继续改造。
