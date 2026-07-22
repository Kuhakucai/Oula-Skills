# My Skills

这是我-欧拉欧拉的个人 Skill 收藏库，用于沉淀日常使用频率高、实践效果好、值得长期复用的 Agent Skills。

每个 Skill 均保留独立目录与 `SKILL.md` 入口说明；使用时请保持其相对目录结构完整。不同 Agent 对 Skill 的发现路径和元数据支持可能不同，请按所使用工具的规范安装或加载。

## 收录 Skill

- `auto-plan-and-execute/`：通过“计划 → 评审 → 实施 → 复核”的四阶段闭环执行软件需求。
- `prd-generator/`：协助收集信息、分析竞品并产出结构化产品需求文档（PRD）。
- `competitive-analysis/`：用于产品与市场决策的竞品分析，包含资料采集、分析框架与图表规范。
- `skill-creator/`：用于创建、维护和校验可复用的通用 Agent Skill。

## 使用方式

1. 选择需要的 Skill 目录。
2. 复制到目标 Agent 支持的 Skills 目录，或在对话中将 `SKILL.md` 作为任务指引加载。
3. 如存在 `scripts/`、`references/` 或 `assets/`，请一并保留。

## 维护原则

- 只收录我实际高频使用且验证有效的 Skill。
- 优先保留通用、可复用、依赖清晰的实现。
- 更新 Skill 后应运行其提供的校验或测试命令。
