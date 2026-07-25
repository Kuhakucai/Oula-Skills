# verified-dev-flow

通过“编写计划 → 审查计划 → 实施 → 审查实施”四阶段循环，可追溯地完成软件需求。

本目录维护于 [Kuhakucai/Oula-Skills](https://github.com/Kuhakucai/Oula-Skills)；安装脚本默认始终从该仓库的 `main/verified-dev-flow` 获取当前维护版本。

## 主要特性

- 计划与实施分别经过独立审查。
- 审查报告最后一个非空行必须是严格的 STATUS 标记。
- 达到最大迭代次数仍未通过时停止，不会强制放行。
- 人工修改已通过审查的 `plan.md` 后自动重新审查。
- 保存流程开始时的 Git 状态和 diff，避免把原有改动误算为本次改动。
- Claude 默认保留权限确认；只有显式设置环境变量才允许跳过。
- 支持 Claude Code、Codex 和其他 CLI 型编码代理。

## 安装

### 直接安装当前维护版本

项目级安装到当前目录：

```bash
curl -fsSL https://raw.githubusercontent.com/Kuhakucai/Oula-Skills/main/verified-dev-flow/install.sh | bash
```

安装到指定项目：

```bash
curl -fsSL https://raw.githubusercontent.com/Kuhakucai/Oula-Skills/main/verified-dev-flow/install.sh \
  | bash -s -- /path/to/project
```

全局安装：

```bash
curl -fsSL https://raw.githubusercontent.com/Kuhakucai/Oula-Skills/main/verified-dev-flow/install.sh \
  | bash -s -- -g
```

### 从克隆仓库安装

```bash
git clone git@github.com:Kuhakucai/Oula-Skills.git
cd Oula-Skills/verified-dev-flow
bash ./install.sh /path/to/project
```

安装器会写入：

- `.agents/skills/verified-dev-flow/`
- `.claude/skills/verified-dev-flow/`

卸载：

```bash
bash ./install.sh --uninstall /path/to/project
bash ./install.sh -g --uninstall
```

## 使用

```bash
verified-dev-flow "为登录接口增加 IP 与账号双维度限流"
verified-dev-flow ./requirements.md
verified-dev-flow --list
verified-dev-flow --status <名称或uuid>
verified-dev-flow --resume <名称或uuid>
```

项目级安装时也可以直接调用：

```bash
.agents/skills/verified-dev-flow/verified-dev-flow.sh ./requirements.md
```

## 接入不同 Agent

Claude Code 是默认 CLI：

```bash
CLAUDE_BIN=claude verified-dev-flow ./requirements.md
```

其他 CLI 可选择参数或标准输入模式：

```bash
AGENT_CMD=my-agent AGENT_ARGS="run" AGENT_PROMPT_MODE=arg \
  verified-dev-flow ./requirements.md

AGENT_CMD=my-agent AGENT_ARGS="run" AGENT_PROMPT_MODE=stdin \
  verified-dev-flow ./requirements.md
```

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `AGENT_CMD` | `${CLAUDE_BIN:-claude}` | Agent CLI 命令 |
| `AGENT_ARGS` | 空 | 传给 Agent CLI 的参数，按 Shell 空白拆分 |
| `AGENT_PROMPT_MODE` | 自动 | `claude`、`arg` 或 `stdin` |
| `MAX_PLAN_ITER` | `3` | 计划审查最大轮数 |
| `MAX_EXEC_ITER` | `3` | 实施审查最大轮数 |
| `VERIFIED_DEV_FLOW_DIR` | `.verified-dev-flow` | 流程文档目录 |
| `SKIP_CONFIRM` | `0` | 设为 `1` 跳过人工确认，仅用于受控 CI |
| `CLAUDE_DANGEROUS_PERMISSIONS` | `0` | 设为 `1` 才关闭 Claude 权限确认 |
| `VDF_REPO` | `Kuhakucai/Oula-Skills` | 安装器下载仓库 |
| `VDF_REF` | `main` | 安装器下载的分支、标签或提交 |
| `VDF_SKILL_PATH` | `verified-dev-flow` | Skill 在仓库中的目录 |
| `VDF_SRC` | 空 | 指定本地 Skill 源目录并跳过下载 |

## STATUS 协议

审查报告的最后一个非空行必须是：

```text
STATUS: PASS
```

或：

```text
STATUS: NEEDS_REVISION
```

达到最大轮数仍为 `NEEDS_REVISION` 时，流程会停止。修复问题后提高对应的 `MAX_PLAN_ITER` 或 `MAX_EXEC_ITER`，再使用 `--resume` 继续。

## 验证

```bash
bash -n verified-dev-flow.sh scripts/*.sh install.sh tests/*.sh
bash tests/verified-dev-flow-tests.sh
```

许可证见 [LICENSE](LICENSE)。
