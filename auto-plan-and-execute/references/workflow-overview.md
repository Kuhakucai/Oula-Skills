# 四阶段工作流总览

## 流程时序图

```
        ┌──────────────────────────────────────────────────────────┐
        │  阶段 1 + 2：计划循环（最多 MAX_PLAN_ITER 轮）              │
        │                                                          │
        │  ┌─────────────┐    plan-vN.md    ┌──────────────┐       │
        │  │ plan-write  │ ───────────────► │ plan-review  │       │
        │  └─────────────┘                  └──────┬───────┘       │
        │         ▲                                │               │
        │         │ NEEDS_REVISION                 │ 含 STATUS     │
        │         │                                ▼               │
        │         │                       plan-review-vN.md        │
        │         └────────────── (循环)                            │
        │                                          │ PASS          │
        └──────────────────────────────────────────┼──────────────┘
                                                   │ 复制最终版为
                                                   ▼ plan.md
                                          ┌────────────────┐
                                          │  人工确认 y/n  │
                                          └────────┬───────┘
                                                   │ y
                                                   ▼
        ┌──────────────────────────────────────────────────────────┐
        │  阶段 3 + 4：实施循环（最多 MAX_EXEC_ITER 轮）              │
        │                                                          │
        │  ┌─────────────┐ execution-log-vN ┌──────────────────┐   │
        │  │execute-plan │ ───────────────► │execution-review  │   │
        │  └─────────────┘  + git diff      └──────┬───────────┘   │
        │         ▲                                │               │
        │         │ NEEDS_REVISION                 │ 含 STATUS     │
        │         │                                ▼               │
        │         │              execution-review-vN.md            │
        │         └────────────── (循环)                            │
        │                                          │ PASS          │
        └──────────────────────────────────────────┼──────────────┘
                                                   ▼
                                          ┌────────────────┐
                                          │ final-summary  │
                                          └────────────────┘
```

## 阶段角色与产出对照

| 阶段 | 角色 prompt | 输入 | 产出 |
|---|---|---|---|
| 1. 编写计划 | `agents/plan-write.md` | `context.md` + 上轮 `plan-review-v{N-1}.md`（可选） | `plan-v{N}.md` |
| 2. 审查计划 | `agents/plan-review.md` | `context.md` + `plan-v{N}.md` | `plan-review-v{N}.md`（含 STATUS） |
| —定稿— | (脚本) | 通过的 `plan-v{N}.md` | 复制为 `plan.md` |
| —人工确认— | (用户) | `plan.md` | y / n / e |
| 3. 实施 | `agents/execute-plan.md` | `context.md` + `plan.md` + 上轮 `execution-review-v{N-1}.md`（可选） | 代码改动 + `execution-log-v{N}.md` |
| 4. 审查实施 | `agents/execution-review.md` | `context.md` + `plan.md` + `git diff` + `execution-log-v{N}.md` | `execution-review-v{N}.md`（含 STATUS） |
| —总结— | (脚本调度) | 全部历史文档 | `final-summary.md` |

## 工作目录结构

```
.auto-flow/{需求名称}-{uuid}/
├── context.md                          # 需求背景（输入）
├── state.json                          # 当前阶段、轮数、定稿计划路径
├── plan-v1.md, plan-v2.md, ...         # 计划迭代版本
├── plan-review-v1.md, ...              # 计划审查报告
├── plan.md                             # 定稿计划（无版本后缀）
├── execution-log-v1.md, ...            # 实施日志
├── execution-review-v1.md, ...         # 实施审查报告
└── final-summary.md                    # 最终交付总结
```

## Context 隔离的实现

编排脚本通过 `AGENT_CMD` 启动独立 agent 调用每个阶段的角色。默认配置兼容 `claude -p`；其他代理可用 `AGENT_PROMPT_MODE=arg` 或 `AGENT_PROMPT_MODE=stdin` 接入。每个阶段调用：
- 只看到该阶段需要的文档路径
- 不继承前一阶段的对话上下文
- 通过文件系统传递信息

自动脚本模式下，独立性来自独立进程或独立 session；手动模式下，执行者必须只依据阶段文档重新审查，不能引用上一阶段未写入文档的解释或辩解。

## 收敛策略 A + B

- **A（语义判断）**：审查报告末尾 `STATUS: PASS` 或 `STATUS: NEEDS_REVISION`
- **B（轮数兜底）**：每阶段最多 `MAX_PLAN_ITER` / `MAX_EXEC_ITER` 轮（默认 3）

判定逻辑：

```
for round in 1..MAX_ITER:
    跑一轮
    case STATUS:
        PASS           → 跳出，进入下阶段
        NEEDS_REVISION → 继续下一轮
        MISSING        → 报错退出（要求人工修复后 --resume）
到达 MAX_ITER 仍 NEEDS_REVISION → 警告并强制进入下阶段
```
