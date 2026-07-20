# auto-plan-and-execute

[![CI](https://github.com/Vocsal/auto-plan-and-execute/actions/workflows/ci.yml/badge.svg)](https://github.com/Vocsal/auto-plan-and-execute/actions/workflows/ci.yml)
[![Release](https://github.com/Vocsal/auto-plan-and-execute/actions/workflows/release.yml/badge.svg)](https://github.com/Vocsal/auto-plan-and-execute/actions/workflows/release.yml)
[![Install Smoke Test](https://github.com/Vocsal/auto-plan-and-execute/actions/workflows/install-smoke.yml/badge.svg)](https://github.com/Vocsal/auto-plan-and-execute/actions/workflows/install-smoke.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

把 **编写计划 → 审查计划 → 实施 → 审查实施** 四阶段开发循环，封装为 **代理中立 Skill + 编排脚本**，可供 Codex、Claude Code 或其他具备文件/终端能力的编码代理使用。

每个阶段通过独立 agent 调用或手动阶段隔离来控制 Context；阶段间用文档传递信息；最终输出一份可交付的实施总结。

## 核心特性

- **单一 skill 入口**：`SKILL.md`，触发后由其调度四阶段
- **A + B 双重收敛**：审查报告末尾的 `STATUS: PASS / NEEDS_REVISION` + 每阶段最多 N 轮（默认 3）
- **人工确认点**：计划定稿后、开始实施前停下来等待人工确认
- **Context 隔离**：自动脚本用独立 agent 调用；手动模式按阶段重新读取文档
- **两种调用方式**：自动脚本（`auto-flow.sh`）和代理内手动四阶段执行（含 `/auto-plan-and-execute`）
- **支持文本/文档两种输入**：脚本自动判别
- **自动命名 + UUID**：每次执行产出 `.auto-flow/{name}-{uuid}/`，互不冲突，支持精确恢复

## 目录结构

```
auto-plan-and-execute/
├── SKILL.md                      # 唯一 skill 入口
├── README.md
├── usage.md                      # 详细使用文档
├── install.sh                    # 安装到目标项目
├── auto-flow.sh                  # 根目录便捷入口（转发到 scripts/）
├── agents/                       # 四阶段角色 prompt
│   ├── plan-write.md
│   ├── plan-review.md
│   ├── execute-plan.md
│   └── execution-review.md
├── scripts/
│   └── auto-flow.sh              # 真正的编排脚本
├── references/                   # 共享规范（被多个 agent 引用）
│   ├── status-protocol.md
│   ├── document-templates.md
│   └── workflow-overview.md
└── assets/
    └── context-template.md       # 需求描述模板
```

运行后会在 **目标项目** 中生成：

```
{你的项目}/
└── .auto-flow/
    └── {需求名称}-{uuid}/
        ├── context.md
        ├── state.json
        ├── plan-v1.md, plan-review-v1.md, ...
        ├── plan.md                 # 定稿计划，无版本后缀
        ├── execution-log-v1.md, execution-review-v1.md, ...
        └── final-summary.md
```

## 安装

### 方式 1：远程一行安装（推荐）

> 下方命令使用 `latest` 引用，它由 release 工作流自动滚动到**最新稳定版**（预发布版本不会被标记为 latest）。如需锁定具体版本，把 `latest` 换成 `vX.Y.Z` 即可。

```bash
# 项目级 - 装到当前目录
curl -fsSL https://raw.githubusercontent.com/Vocsal/auto-plan-and-execute/latest/install.sh | bash

# 项目级 - 装到指定项目
curl -fsSL https://raw.githubusercontent.com/Vocsal/auto-plan-and-execute/latest/install.sh | bash -s -- /path/to/project

# 全局 - 装到 ~/.agents/skills 和 ~/.claude/skills
curl -fsSL https://raw.githubusercontent.com/Vocsal/auto-plan-and-execute/latest/install.sh | bash -s -- -g

# 卸载项目级
curl -fsSL https://raw.githubusercontent.com/Vocsal/auto-plan-and-execute/latest/install.sh | bash -s -- --uninstall

# 卸载全局
curl -fsSL https://raw.githubusercontent.com/Vocsal/auto-plan-and-execute/latest/install.sh | bash -s -- -g --uninstall

# 锁定指定版本
curl -fsSL https://raw.githubusercontent.com/Vocsal/auto-plan-and-execute/v1.0.0/install.sh | bash
```

### 方式 2：本地 clone 后安装

```bash
git clone https://github.com/Vocsal/auto-plan-and-execute.git
cd auto-plan-and-execute

./install.sh                          # 项目级，装到当前目录
./install.sh /path/to/your-project    # 项目级，装到指定目录
./install.sh -g                       # 全局安装
./install.sh -g --uninstall           # 卸载全局
./install.sh --uninstall /path/...    # 卸载项目级
```

### 安装位置

**项目级**（两份完整副本）：
- `<目标>/.agents/skills/auto-plan-and-execute/`
- `<目标>/.claude/skills/auto-plan-and-execute/`

**全局**：
- `~/.agents/skills/auto-plan-and-execute/`
- `~/.claude/skills/auto-plan-and-execute/`
- 附加：在 PATH 中创建可执行命令 `auto-plan-and-execute`（详见下方「全局命令」）

项目级和全局**可共存**。Claude Code 优先识别项目级，未找到时回退全局。

已安装过会**自动覆盖更新**（先删除旧版再复制）。

### 全局命令（仅 `-g` 模式）

全局安装时，脚本会额外在 PATH 候选目录中创建软链接 `auto-plan-and-execute`，让你在任意目录直接调用，无需记忆完整路径。

候选目录按优先级：

1. `$HOME/.local/bin/auto-plan-and-execute`（推荐，无需 sudo）
2. `/usr/local/bin/auto-plan-and-execute`（需要该目录可写）

行为说明：

- 两个候选目录都不可写时 → 跳过软链接创建，仍可用完整路径调用
- 目标位置已存在同源软链接 → 跳过（视为已安装）
- 目标位置已存在其他文件 → 警告并跳过，**不会覆盖**
- 所选目录不在 `PATH` 中 → 打印需要追加的 `export PATH=...`，由你自行加到 `~/.zshrc` / `~/.bashrc`（脚本**不自动改 shell 配置**）
- `-g --uninstall` 会同时清理创建的软链接（不会删除别人放的同名普通文件）

## 使用

### 启动新流程

> 下面所有命令都有两种调用形式：
> - **项目级安装**：`.claude/skills/auto-plan-and-execute/auto-flow.sh ...`
> - **全局安装**：直接 `auto-plan-and-execute ...`（前提是 PATH 已包含软链接所在目录）
>
> 为简洁，下文示例统一使用全局命令形式。

**方式 A：直接传需求文本**

```bash
auto-plan-and-execute "为登录接口加 IP+账号双维度限流：1分钟内 IP 失败5次封禁15分钟；1小时内账号失败10次封禁1小时；封禁返回 429。不引入新依赖。"

# 等价的项目级调用：
# .claude/skills/auto-plan-and-execute/auto-flow.sh "..."
```

**方式 B：传需求文档**

```bash
auto-plan-and-execute ./requirements.md

# 等价的项目级调用：
# .claude/skills/auto-plan-and-execute/auto-flow.sh ./requirements.md
```

脚本会自动:
1. 检测输入类型（已存在的文件 → 文档；否则 → 文本）
2. 从文档 H1 或文本首行推断名称（slug 化）
3. 生成 8 位短 UUID
4. 创建 `.auto-flow/{name}-{uuid}/`
5. 跑计划循环 → 复制定稿为 `plan.md` → 等人工确认 → 跑实施循环 → 生成 `final-summary.md`

### 中断恢复

```bash
auto-plan-and-execute --resume <名称>
auto-plan-and-execute --resume <uuid>
auto-plan-and-execute --resume <名称-uuid>
```

匹配规则：
- 完整 `名称-uuid` → 精确匹配
- 仅名称 → 匹配 `{名称}-*`（多个会列出让你选）
- 仅 uuid → 匹配 `*-{uuid}`

### 查询

```bash
auto-plan-and-execute --status <名称|uuid>
auto-plan-and-execute --list
```

### Claude Code 内调用

安装后直接在 Claude Code 中输入：

```
/auto-plan-and-execute
```

或自然语言：

> 用 auto-plan-and-execute skill 帮我跑一遍："给登录接口加限流..."

当前代理会按本 skill 调度四阶段流程；若代理不支持自动脚本，则按 `SKILL.md` 的“手动阶段执行”完成同一流程。

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `MAX_PLAN_ITER` | 3 | 计划阶段最大轮数 |
| `MAX_EXEC_ITER` | 3 | 实施阶段最大轮数 |
| `AGENT_CMD` | `${CLAUDE_BIN:-claude}` | 自动脚本调用的代理命令 |
| `AGENT_ARGS` | 空 | 传给代理命令的附加参数 |
| `AGENT_PROMPT_MODE` | 自动 | `claude` / `arg` / `stdin` |
| `CLAUDE_BIN` | `claude` | 兼容旧 Claude 配置 |
| `AUTO_FLOW_DIR` | `.auto-flow` | 工作目录 |
| `SKIP_CONFIRM` | `0` | 设为 `1` 跳过人工确认（仅 CI） |
| `APE_REPO` | `Vocsal/auto-plan-and-execute` | install.sh 远程拉取的仓库 |
| `APE_REF` | `latest` | install.sh 远程拉取的 ref（branch / tag / commit SHA）；`latest` 跟随最新稳定版 |
| `APE_SRC` | — | install.sh 强制指定本地源目录 |

## 何时该用 / 不该用

**适合**:
- 中等以上复杂度的需求（需先讨论方案再动手）
- 希望保留完整决策记录的项目
- 团队希望统一 "计划 + 审查" 流程

**不适合**:
- 一行小改
- 探索性 spike
- 大量 UI 设计、需频繁人工交互的任务

详细使用方式见 [usage.md](usage.md)。

## License

MIT
