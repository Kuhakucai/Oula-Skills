# 使用指南

## 设计原理

### 为什么要分四个阶段

软件开发中，方案讨论和动手实施是两种不同的思维模式。混在一起会导致：

- **过早实现**：方案没想清就开始改代码，发现走错路再回退成本极高
- **审查盲区**：自己写的方案/实现，自己审查会有盲区
- **Context 污染**：写方案时的上下文会让审查带有偏见

解法：

| 阶段 | 角色 | Context | 产出 |
|---|---|---|---|
| 1. plan-write | 方案设计者 | 背景需求 + 项目代码 + 上轮审查 | 计划方案文档 |
| 2. plan-review | 独立评审人 | 背景需求 + 计划方案 + 项目代码 | 审查报告（含 STATUS） |
| 3. execute-plan | 实施工程师 | 背景需求 + 定稿计划 + 上轮审查 + 代码库 | 代码改动 + 实施日志 |
| 4. execution-review | 独立评审人 | 背景需求 + 计划 + git diff + 关键文件 | 审查报告（含 STATUS） |

自动脚本模式下，每个阶段通过独立 agent 调用隔离 Context；默认兼容 `claude -p`，也可用 `AGENT_CMD` 接入其他代理。手动模式下，当前代理按阶段重新读取文档来实现过程隔离。

### 为什么要 A + B 双重收敛

仅靠"轮数封顶"：可能方案没成熟就强行进入实施，浪费实施轮数
仅靠"STATUS 通过"：审查可能永远挑得出问题，无法收敛

A + B 组合：
- **A（语义判断）**：审查报告最后一个非空行必须是 `STATUS: PASS` / `STATUS: NEEDS_REVISION`，脚本严格匹配
- **B（轮数兜底）**：每阶段最多 N 轮（默认 3），达到上限仍未通过则停止，修复后提高上限并恢复

### 为什么人工确认点放在"开始实施前"

- 计划阶段产物是文档，迭代成本低，可全自动
- 实施阶段会动代码，错误代价高，必须人工把关一次
- 实施审查→修补：基于审查报告的修补改动可控，可自动跑

## 完整工作流示例

### Step 1：准备需求

可以是文档 `requirements.md`：

```markdown
# 登录接口加限流

## 业务背景
近期检测到 /api/login 接口被刷，日均 5w+ 失败请求。

## 需求详情
- 同一 IP 1 分钟内失败超过 5 次，临时封禁 15 分钟
- 同一账号 1 小时内失败超过 10 次，临时封禁 1 小时
- 封禁期间返回 429，并返回 Retry-After 头
- 解封后自动恢复

## 技术约束
- 不引入新依赖（项目已有 Redis）
- 配置项要支持热更新

## 验收标准
- 单元测试覆盖 IP/账号双维度限流逻辑
- 集成测试模拟暴力破解场景
```

也可以是命令行字符串。

### Step 2：启动

> 调用形式取决于安装方式：
> - **项目级**：`.claude/skills/verified-dev-flow/verified-dev-flow.sh ...`
> - **全局**（`install.sh -g`）：直接 `verified-dev-flow ...`（需确保 `$HOME/.local/bin` 已加入 PATH）
>
> 下文示例统一使用全局命令形式，项目级用户请把 `verified-dev-flow` 替换为完整脚本路径。

```bash
cd /path/to/your-project
verified-dev-flow ./requirements.md
```

或：

```bash
verified-dev-flow "给登录接口加 IP+账号 双维度限流..."
```

终端显示：

```
[verified-dev-flow] 已创建流程实例: login-rate-limit-a3f2c8d1
[verified-dev-flow]   - 工作目录: .verified-dev-flow/login-rate-limit-a3f2c8d1
[verified-dev-flow]   - 输入类型: 文档(./requirements.md)
[verified-dev-flow] ═══ 计划阶段 第 1/3 轮 ═══
[verified-dev-flow] [1/2] 生成计划方案 .verified-dev-flow/login-rate-limit-a3f2c8d1/plan-v1.md
[verified-dev-flow] → 调用 <agent> (<mode> 模式，独立调用/Session)...
...
```

### Step 3：计划迭代

如果第 1 轮审查 `STATUS: NEEDS_REVISION`，自动进入第 2 轮，直到 `PASS` 或达 3 轮上限。

通过后，脚本会把最终通过版**复制为 `plan.md`**（无版本后缀）：

```
[verified-dev-flow] ✅ 计划审查 STATUS: PASS，计划阶段完成
[verified-dev-flow] 已将定稿计划复制为 .verified-dev-flow/login-rate-limit-a3f2c8d1/plan.md
```

### Step 4：人工确认

```
[verified-dev-flow] ═══ 人工确认点 ═══
[verified-dev-flow] 计划已定稿: .verified-dev-flow/login-rate-limit-a3f2c8d1/plan.md
[verified-dev-flow] 请在另一个终端打开审阅。

是否继续进入实施阶段? [y/n/e=编辑后再确认]:
```

- `y` → 进入实施
- `n` → 终止，稍后用 `--resume` 续跑
- `e` → 编辑文件后再回来确认

### Step 5：实施 → 审查

当前代理会按 `plan.md` 改代码、跑测试，输出 `execution-log-v1.md`。
然后 `execution-review` 看 `git diff`，输出 `execution-review-v1.md`。

如有 P0/P1 问题则进入修补轮，最多 3 轮。

### Step 6：最终总结

```
[verified-dev-flow] ═══ 生成最终总结 ═══
[verified-dev-flow] ✅ 流程完成！最终交付:
[verified-dev-flow]     - 计划方案: .verified-dev-flow/login-rate-limit-a3f2c8d1/plan.md
[verified-dev-flow]     - 实施总结: .verified-dev-flow/login-rate-limit-a3f2c8d1/final-summary.md
[verified-dev-flow]     - 工作目录: .verified-dev-flow/login-rate-limit-a3f2c8d1
```

## 命令对照

下表中 `<cmd>` 代表入口命令：
- 项目级安装 → `<cmd>` = `.claude/skills/verified-dev-flow/verified-dev-flow.sh`
- 全局安装   → `<cmd>` = `verified-dev-flow`

| 命令 | 作用 |
|---|---|
| `<cmd> "<文本>"` | 用需求文本启动 |
| `<cmd> ./req.md` | 用需求文档启动 |
| `<cmd> --resume <名称>` | 按名称恢复（多个匹配会列出） |
| `<cmd> --resume <uuid>` | 按 uuid 精确恢复 |
| `<cmd> --resume <名称-uuid>` | 按完整 instance 恢复 |
| `<cmd> --status <名称\|uuid>` | 查看状态 |
| `<cmd> --list` | 列出所有流程实例 |
| `<cmd> --help` | 帮助 |

## 常见场景

### 调高迭代轮数

```bash
MAX_PLAN_ITER=5 MAX_EXEC_ITER=5 verified-dev-flow "..."
```

### 跳过人工确认（仅 CI）

```bash
SKIP_CONFIRM=1 verified-dev-flow ./req.md  # 仅用于受控 CI
```

### 代理内手动单跑某阶段

不想跑完整 verified-dev-flow，只想用 skill 跑某一个阶段时，在 Codex、Claude Code 或其他代理里说：

> 用 verified-dev-flow skill 的 plan-write 角色帮我写计划，需求在 ./req.md，输出到 plans/my-plan.md

当前代理会读取 `agents/plan-write.md` 作为角色 prompt，按规范产出。

### 修复中间步骤后重跑

假设第 2 轮计划审查后，你想手动改一下 `plan-v2.md` 再继续：

1. 编辑 `plan-v2.md`
2. 删除 `plan-review-v2.md`（让脚本重新审查）
3. `verified-dev-flow --resume <名称>`

### 完全重做

```bash
rm -rf .verified-dev-flow/<名称>-<uuid>
verified-dev-flow ./req.md
```

## 故障排除

### "审查报告末尾缺少 STATUS 标记"

skill 没按规范输出 STATUS 行。处理方式：

1. 手动打开报告，在末尾加 `STATUS: PASS` 或 `STATUS: NEEDS_REVISION`
2. `verified-dev-flow --resume <名称>` 继续

### "未产出 plan-vN.md"

可能原因：
- 当前代理没识别到 skill — 检查 skill 是否安装到该代理支持的 skills 目录
- 代理写到了别的路径 — 看一下工作目录里有没有同名文件
- 代理 CLI 报错 — 重跑看完整输出，并确认 `AGENT_CMD` / `AGENT_PROMPT_MODE`

### 实施阶段改坏了代码

中止脚本后用 git 回退：

```bash
git stash       # 或 git reset --hard HEAD
```

然后修一下计划或审查报告，再 `--resume`。

### 多个 instance 同名

可能在不同时间为同一个需求多次启动 verified-dev-flow。每次会有不同 UUID，互不冲突。用 `--list` 查看，用 `--status <完整名-uuid>` 精确查询。

## 文档命名规则

| 文件 | 含义 | 是否带版本后缀 |
|---|---|---|
| `plan-v1.md`, `plan-v2.md`, ... | 计划迭代版本 | 是 |
| `plan.md` | 通过审查后定稿的计划 | **否** |
| `plan-review-v1.md`, ... | 计划审查报告 | 是 |
| `execution-log-v1.md`, ... | 实施日志 | 是 |
| `execution-review-v1.md`, ... | 实施审查报告 | 是 |
| `final-summary.md` | 最终交付总结 | 否 |

实施阶段和总结阶段统一引用 `plan.md`，下游不用关心定稿了第几版。

## 进阶用法

### 集成 CI/CD

```yaml
# .github/workflows/verified-dev-flow.yml
on:
  workflow_dispatch:
    inputs:
      requirements: { required: true }

jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: curl -fsSL https://raw.githubusercontent.com/Kuhakucai/Oula-Skills/main/verified-dev-flow/install.sh | bash
      - run: SKIP_CONFIRM=1 .claude/skills/verified-dev-flow/verified-dev-flow.sh "${{ inputs.requirements }}"
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

### 自定义 STATUS 解析逻辑

修改 `scripts/verified-dev-flow.sh` 中 `check_status` 函数，可以加入：
- 检查报告中"P0 数量"是否为 0
- 检查问题清单中是否含特定关键词
- 调用其他工具做额外校验

## 设计取舍

| 取舍点 | 选择 | 原因 |
|---|---|---|
| Context 隔离 | 自动脚本每阶段独立 agent 调用；手动模式按阶段文档隔离 | 简单可靠，无需复杂 IPC |
| 状态持久化 | JSON 文件 | 易调试、易手动修改 |
| 人工确认点 | 仅在实施前 | 平衡自动化与安全 |
| 单 skill vs 多 skill | 单 skill | 集中调度，触发率高，避免命名冲突 |
| 定稿计划命名 | `plan.md`（无后缀） | 下游引用稳定 |
| 实例命名 | `name-uuid` | name 易读，uuid 防冲突 |
| install 策略 | 双份完整拷贝 | 简单可靠，跨平台兼容 |
