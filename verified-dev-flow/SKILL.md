---
name: verified-dev-flow
description: 用四阶段循环（编写计划 → 审查计划 → 实施 → 审查实施）严格、可追溯地完成软件项目需求；适用于 Claude Code、Codex 或其他具备文件读取、编辑与终端能力的编码代理。阶段间通过文档传递信息；支持脚本驱动的独立 agent 调用，也支持在当前代理内按阶段手动执行。当用户提到“按计划走”、“先写方案再实施”、“严格规划再落地”、“自动化计划与执行”、“verified-dev-flow”、“四阶段流程”、“先评审方案”，或调用 /verified-dev-flow 时，必须使用本 skill。
---

# verified-dev-flow

把 **编写计划 → 审查计划 → 实施 → 审查实施** 四阶段闭环封装成可重复执行的开发流程。

本 skill 是代理中立的：
- Claude Code 可以继续使用 `scripts/verified-dev-flow.sh` 的默认 `claude -p` 自动编排。
- Codex 或其他代理可以按“手动阶段执行”直接读取本 skill 的角色 prompt 和模板，在当前工作区完成同一流程。
- 其他 CLI 型代理可通过 `AGENT_CMD`、`AGENT_ARGS`、`AGENT_PROMPT_MODE` 接入自动脚本。

## 何时触发

- 用户输入 `/verified-dev-flow`
- 用户提到“自动化计划执行”、“四阶段流程”、“先写方案再实施”、“严格规划再落地”
- 用户给出需求并明确希望走“方案 → 审查 → 实施 → 复核”完整流程
- 用户要求恢复或单跑 verified-dev-flow 某个阶段

## 必读文件

- 流程总览：`references/workflow-overview.md`
- 状态协议：`references/status-protocol.md`
- 文档模板：`references/document-templates.md`
- 计划编写角色：`agents/plan-write.md`
- 计划审查角色：`agents/plan-review.md`
- 实施角色：`agents/execute-plan.md`
- 实施审查角色：`agents/execution-review.md`

## 工作目录约定

所有产出都放在执行目录的 `.verified-dev-flow/{需求名称}-{uuid}/` 下：

```text
.verified-dev-flow/{name}-{uuid}/
├── context.md
├── state.json
├── plan-v1.md, plan-v2.md, ...
├── plan-review-v1.md, ...
├── plan.md
├── execution-log-v1.md, ...
├── execution-review-v1.md, ...
└── final-summary.md
```

## 自动脚本用法

默认兼容 Claude Code：

```bash
bash scripts/verified-dev-flow.sh "为登录接口增加 IP+账号双维度限流"
bash scripts/verified-dev-flow.sh ./requirements.md
```

通用代理配置：

```bash
# prompt 作为最后一个参数传给代理 CLI
AGENT_CMD=codex AGENT_ARGS="exec --sandbox workspace-write" AGENT_PROMPT_MODE=arg bash scripts/verified-dev-flow.sh ./requirements.md

# prompt 通过 stdin 传入代理 CLI
AGENT_CMD=my-agent AGENT_ARGS="run" AGENT_PROMPT_MODE=stdin bash scripts/verified-dev-flow.sh ./requirements.md

# 旧 Claude 配置仍可用
CLAUDE_BIN=claude bash scripts/verified-dev-flow.sh ./requirements.md
```

环境变量：

| 变量 | 默认 | 说明 |
|---|---|---|
| `AGENT_CMD` | `${CLAUDE_BIN:-claude}` | 自动脚本调用的代理命令 |
| `AGENT_ARGS` | 空 | 传给代理命令的附加参数，按 shell 空白拆分 |
| `AGENT_PROMPT_MODE` | `claude` 或 `arg` | `claude` 使用 `-p`，`arg` 把 prompt 作为最后参数，`stdin` 通过标准输入传入 |
| `AGENT_LABEL` | 命令 basename | 日志显示名称 |
| `CLAUDE_BIN` | `claude` | 兼容旧配置；未设置 `AGENT_CMD` 时生效 |
| `MAX_PLAN_ITER` | 3 | 计划阶段最大轮数 |
| `MAX_EXEC_ITER` | 3 | 实施阶段最大轮数 |
| `VERIFIED_DEV_FLOW_DIR` | `.verified-dev-flow` | 工作目录 |
| `SKIP_CONFIRM` | `0` | 设为 `1` 跳过实施前人工确认，仅用于受控 CI |
| `CLAUDE_DANGEROUS_PERMISSIONS` | `0` | 设为 `1` 才向 Claude 传入危险的跳过权限确认参数 |


Codex CLI 隔离调用示例（Windows/Git Bash 推荐）：

```bash
AGENT_CMD="./scripts/codex-agent.sh" \
AGENT_ARGS="exec --sandbox workspace-write --ephemeral" \
AGENT_PROMPT_MODE=arg \
bash scripts/verified-dev-flow.sh ./requirements.md
```

说明：`codex-agent.sh` 会通过 PowerShell 调用 npm 安装的 `codex.cmd`，避免 WindowsApps 中同名 `codex.exe` 抢占 PATH。每个阶段都会启动一次新的 `codex exec`；不要使用 `exec resume`，否则会破坏阶段隔离。
恢复与状态：

```bash
bash scripts/verified-dev-flow.sh --resume <名称 或 uuid 或 名称-uuid>
bash scripts/verified-dev-flow.sh --status <名称 或 uuid>
bash scripts/verified-dev-flow.sh --list
```

## 手动阶段执行（Codex 推荐）

如果当前环境不能安全运行自动脚本，或者代理没有适配 CLI，直接按下面步骤执行。手动模式仍必须生成同样的阶段文档，并遵守 STATUS 协议。

1. 初始化 `.verified-dev-flow/{name}-{uuid}/context.md`，记录用户需求、仓库背景、约束、已知风险。
2. 阶段 1：读取 `agents/plan-write.md` 和 `references/document-templates.md`，输出 `plan-v{N}.md`。
3. 阶段 2：读取 `agents/plan-review.md`、`references/status-protocol.md`，独立审查 `plan-v{N}.md`，输出 `plan-review-v{N}.md`，末尾必须有 `STATUS: PASS` 或 `STATUS: NEEDS_REVISION`。
4. 如果计划审查需要修订，回到阶段 1；通过后复制或整理为 `plan.md`。
5. 阶段 3：读取 `agents/execute-plan.md`，按 `plan.md` 实施并输出 `execution-log-v{N}.md`。
6. 阶段 4：读取 `agents/execution-review.md`、`references/status-protocol.md`，基于 `git diff`、计划和实施日志审查，输出 `execution-review-v{N}.md`。
7. 如果实施审查需要修订，回到阶段 3；通过后输出 `final-summary.md`。

## Context 隔离要求

- 自动脚本模式：每个阶段应通过独立 agent 调用或独立 session 执行，阶段间只传文档路径。
- 手动模式：当前代理必须按阶段重新读取必要文档，不把上一阶段的解释、辩解或未写入文档的推理当作审查依据。
- 审查角色必须独立：只相信需求、计划、diff、日志和测试结果。

## 重要约束

- `STATUS` 必须是审查报告最后一个非空行，否则脚本拒绝继续。
- 达到最大迭代轮数仍未通过时必须停止，不得强制进入下一阶段。
- 人工修改已经通过审查的 `plan.md` 后，脚本必须重新审查。
- 定稿计划统一命名为 `plan.md`。
- 计划和总结不要写“v2 相比 v1”这类迭代痕迹。
- 实施必须真实运行可用的验证命令；不能伪造测试通过。
- 当前代理有更严格的系统/开发者指令时，以更高优先级指令为准，但仍应保留本流程的产出文档和审查闭环。
