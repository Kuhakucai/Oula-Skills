#!/usr/bin/env bash
# auto-flow.sh — auto-plan-and-execute 四阶段自动化编排
#
# 用法:
#   scripts/auto-flow.sh "<需求文本>"          # 直接传需求文本
#   scripts/auto-flow.sh <需求文档路径>         # 传需求文档（.md 文件）
#   scripts/auto-flow.sh --resume <名称|uuid|名称-uuid>
#   scripts/auto-flow.sh --status <名称|uuid|名称-uuid>
#   scripts/auto-flow.sh --list
#   scripts/auto-flow.sh --help
#
# 环境变量:
#   MAX_PLAN_ITER       计划阶段最大迭代轮数（默认 3）
#   MAX_EXEC_ITER       实施阶段最大迭代轮数（默认 3）
#   AGENT_CMD          agent CLI 路径（默认 ${CLAUDE_BIN:-claude}）
#   AUTO_FLOW_DIR       工作目录（默认 .auto-flow）
#   SKIP_CONFIRM        设为 1 跳过实施前人工确认（仅 CI）
#   AUTO_FLOW_VERBOSE   设为 1（默认）开启 Claude stream-json 事件日志；设为 0 静默

set -euo pipefail

# ---------- 路径解析 ----------
# 脚本自身所在目录（scripts/）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# skill 根目录（包含 SKILL.md / agents / references 的地方）
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------- 默认值 ----------
MAX_PLAN_ITER="${MAX_PLAN_ITER:-3}"
MAX_EXEC_ITER="${MAX_EXEC_ITER:-3}"
AGENT_CMD="${AGENT_CMD:-${CLAUDE_BIN:-claude}}"
AGENT_ARGS="${AGENT_ARGS:-}"
AGENT_PROMPT_MODE="${AGENT_PROMPT_MODE:-}"
AGENT_LABEL="${AGENT_LABEL:-$(basename "$AGENT_CMD")}"
AUTO_FLOW_DIR="${AUTO_FLOW_DIR:-.auto-flow}"
SKIP_CONFIRM="${SKIP_CONFIRM:-0}"

STAGE_INIT="init"
STAGE_PLAN="plan"
STAGE_CONFIRM="confirm"
STAGE_EXECUTE="execute"
STAGE_SUMMARY="summary"
STAGE_DONE="done"

# ---------- 工具函数 ----------
log()  { printf "\033[1;34m[auto-flow]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[auto-flow]\033[0m %s\n" "$*" >&2; }
err()  { printf "\033[1;31m[auto-flow]\033[0m %s\n" "$*" >&2; }

usage() {
  cat <<EOF
auto-plan-and-execute / auto-flow.sh

用法:
  scripts/auto-flow.sh "<需求文本>"
      把整段需求作为字符串传入；脚本会自动命名、生成 UUID 并启动流程。

  scripts/auto-flow.sh <需求文档路径>
      传一个 markdown 文件作为需求；脚本读取其 H1 标题作为默认命名。

  scripts/auto-flow.sh --resume <名称|uuid|名称-uuid>
      从上次中断处继续。

  scripts/auto-flow.sh --status <名称|uuid|名称-uuid>
      查看某个流程的当前状态。

  scripts/auto-flow.sh --list
      列出所有流程实例。

  scripts/auto-flow.sh --help

环境变量:
  MAX_PLAN_ITER (默认 $MAX_PLAN_ITER)
  MAX_EXEC_ITER (默认 $MAX_EXEC_ITER)
  AGENT_CMD    (默认 ${CLAUDE_BIN:-claude}，当前为 $AGENT_CMD)
  AGENT_ARGS   (默认空)  传给代理 CLI 的附加参数
  AGENT_PROMPT_MODE (默认自动)  claude / arg / stdin
  AUTO_FLOW_DIR (默认 $AUTO_FLOW_DIR)
  SKIP_CONFIRM  (默认 0)  设为 1 跳过实施前人工确认
  AUTO_FLOW_VERBOSE (默认 1)  设为 0 关闭 Claude stream-json 事件日志
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "缺少命令: $1"; exit 1; }
}

# ---------- 命名与 UUID ----------

# 生成 8 位短 UUID（仅小写字母数字）
gen_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr 'A-Z' 'a-z' | tr -d '-' | cut -c1-8
  else
    LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 8
    echo
  fi
}

# 把任意字符串 slug 化为 kebab-case
slugify() {
  local s="$1"
  # 去 markdown 标题井号、首尾空白
  s="$(echo "$s" | sed -E 's/^#+[[:space:]]*//; s/^[[:space:]]+//; s/[[:space:]]+$//')"
  # 替换所有非字母数字（含中文）为连字符
  # 注意：BSD sed 不直接支持 unicode 字符类，所以用 tr+iconv 组合
  # 简化方案：保留 ASCII 字母数字和连字符，其余替换为 -
  # 对中文等非 ASCII 字符，转写为 - 后再压缩
  s="$(echo "$s" | LC_ALL=C tr -c '[:alnum:][:space:]' '-')"
  s="$(echo "$s" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]-' '-' )"
  s="$(echo "$s" | sed -E 's/^-+//; s/-+$//')"
  # 截断到 40 字符
  s="${s:0:40}"
  s="$(echo "$s" | sed -E 's/-+$//')"
  if [ -z "$s" ]; then s="feat"; fi
  echo "$s"
}

# 从需求文档/文本推断名称
# 参数:
#   $1: 输入路径或文本
#   $2: is_file (true/false)
infer_name() {
  local input="$1" is_file="$2"
  local title=""
  if [ "$is_file" = "true" ]; then
    # 取首个 H1
    title="$(grep -m1 -E '^#[[:space:]]+' "$input" 2>/dev/null | head -n1 || true)"
    if [ -z "$title" ]; then
      # 没有 H1 就取第一行非空
      title="$(grep -m1 -E '.' "$input" 2>/dev/null | head -n1 || true)"
    fi
  else
    # 文本输入：取第一行
    title="$(echo "$input" | head -n1)"
  fi
  slugify "$title"
}

# ---------- 工作目录 ----------

work_dir() { echo "$AUTO_FLOW_DIR/$1"; }
state_file() { echo "$(work_dir "$1")/state.json"; }

# 列出所有 instance 目录名
list_instances() {
  [ -d "$AUTO_FLOW_DIR" ] || return 0
  ls -1 "$AUTO_FLOW_DIR" 2>/dev/null | while read -r d; do
    [ -d "$AUTO_FLOW_DIR/$d" ] && echo "$d"
  done
}

# 根据 partial 解析完整 instance 名
# partial 可以是: 完整 name-uuid / 仅 name / 仅 uuid
resolve_instance() {
  local partial="$1"
  local matches=()
  while IFS= read -r line; do
    [ -n "$line" ] && matches+=("$line")
  done < <(list_instances)

  local hits=()
  for inst in "${matches[@]}"; do
    if [ "$inst" = "$partial" ]; then
      echo "$inst"
      return 0
    fi
    # 后缀匹配 uuid
    if [[ "$inst" == *-"$partial" ]]; then
      hits+=("$inst")
      continue
    fi
    # 前缀匹配 name
    if [[ "$inst" == "$partial"-* ]]; then
      hits+=("$inst")
      continue
    fi
  done

  if [ ${#hits[@]} -eq 0 ]; then
    err "找不到匹配 '$partial' 的流程实例"
    return 1
  fi
  if [ ${#hits[@]} -eq 1 ]; then
    echo "${hits[0]}"
    return 0
  fi
  err "匹配到多个实例，请指定完整名称："
  for h in "${hits[@]}"; do err "  - $h"; done
  return 1
}

# ---------- 状态读写 ----------

read_state() {
  local instance="$1" key="$2"
  local sf
  sf="$(state_file "$instance")"
  [ -f "$sf" ] || { echo ""; return; }
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$key" '.[$k] // ""' "$sf"
  else
    grep -oE "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$sf" | sed -E "s/.*:[[:space:]]*\"([^\"]*)\"/\1/"
  fi
}

write_state() {
  local instance="$1"
  local stage="$2" plan_iter="$3" exec_iter="$4" plan_final="$5"
  local sf
  sf="$(state_file "$instance")"
  cat > "$sf" <<EOF
{
  "instance": "$instance",
  "stage": "$stage",
  "plan_iter": "$plan_iter",
  "exec_iter": "$exec_iter",
  "plan_final": "$plan_final",
  "updated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# ---------- agent 调用 ----------

run_agent() {
  local prompt="$1"
  local mode="${AGENT_PROMPT_MODE:-}"
  local args=()

  if [ -n "${AGENT_ARGS:-}" ]; then
    # shellcheck disable=SC2206
    args=($AGENT_ARGS)
  fi

  if [ -z "$mode" ]; then
    case "$(basename "$AGENT_CMD")" in
      claude|claude.exe) mode="claude" ;;
      *) mode="arg" ;;
    esac
  fi

  log "→ 调用 ${AGENT_LABEL} (${mode} 模式，独立调用/Session)..."

  case "$mode" in
    claude)
      if [ "${AUTO_FLOW_VERBOSE:-1}" = "1" ]; then
        set +e
        "$AGENT_CMD" -p "$prompt" \
          --dangerously-skip-permissions \
          --verbose \
          --output-format stream-json \
        | while IFS= read -r line; do
            if command -v jq >/dev/null 2>&1; then
              echo "$line" | jq -r '
                if .type=="assistant" then
                  (.message.content[]?
                    | if .type=="tool_use" then
                        "  · 工具调用: \(.name) " + ((.input // {}) | tostring | .[0:160])
                      elif .type=="text" then
                        "  · " + (.text | gsub("\n"; " ") | .[0:200])
                      else empty end)
                elif .type=="user" then
                  (.message.content[]?
                    | select(.type=="tool_result")
                    | "  ← 工具结果: " + ((.content // "") | tostring | gsub("\n"; " ") | .[0:160]))
                elif .type=="result" then
                  "  ✓ agent 完成 (耗时 \(.duration_ms // 0)ms, 轮数 \(.num_turns // 0))"
                elif .type=="system" and .subtype=="init" then
                  "  · session 初始化 (model=\(.model // "?"))"
                else empty end
              ' 2>/dev/null || echo "$line"
            else
              echo "$line"
            fi
          done
        local rc=${PIPESTATUS[0]}
        set -e
        return "$rc"
      else
        "$AGENT_CMD" -p "$prompt" --dangerously-skip-permissions
      fi
      ;;
    arg)
      "$AGENT_CMD" "${args[@]}" "$prompt"
      ;;
    stdin)
      printf '%s\n' "$prompt" | "$AGENT_CMD" "${args[@]}"
      ;;
    *)
      err "未知 AGENT_PROMPT_MODE: $mode（支持 claude、arg、stdin）"
      return 2
      ;;
  esac
}

# 检查 STATUS 行
check_status() {
  local doc="$1"
  [ -f "$doc" ] || { echo "MISSING"; return; }
  if tail -n 50 "$doc" | grep -qE "^STATUS: PASS$"; then
    echo "PASS"
  elif tail -n 50 "$doc" | grep -qE "^STATUS: NEEDS_REVISION$"; then
    echo "NEEDS_REVISION"
  else
    echo "MISSING"
  fi
}

# ---------- 阶段实现 ----------

stage_plan_loop() {
  local instance="$1" wd
  wd="$(work_dir "$instance")"
  local ctx="$wd/context.md"

  local start_iter
  start_iter="$(read_state "$instance" plan_iter)"
  [ -z "$start_iter" ] && start_iter=0
  start_iter=$((start_iter + 0))

  for ((i=start_iter+1; i<=MAX_PLAN_ITER; i++)); do
    log "═══ 计划阶段 第 $i/$MAX_PLAN_ITER 轮 ═══"
    local plan_doc="$wd/plan-v$i.md"
    local review_doc="$wd/plan-review-v$i.md"
    local prev_review="$wd/plan-review-v$((i-1)).md"

    # 写计划
    if [ ! -f "$plan_doc" ]; then
      log "[1/2] 生成计划方案 $plan_doc"
      local prompt
      if [ -f "$prev_review" ]; then
        prompt="请按 auto-plan-and-execute skill 中 agents/plan-write.md 的角色编写计划。

执行环境信息:
- skill 根目录: $SKILL_ROOT
- 当前轮次: 第 $i / $MAX_PLAN_ITER 轮（迭代版本）

请先读取以下文件以加载角色与模板:
- $SKILL_ROOT/agents/plan-write.md
- $SKILL_ROOT/references/document-templates.md

任务输入:
- 项目背景与需求文档: $ctx
- 上一轮计划审查报告: $prev_review
- 输出路径: $plan_doc

请基于审查报告反馈迭代计划方案，输出完整的新版方案（不要写元描述/对比/迭代记录）。"
      else
        prompt="请按 auto-plan-and-execute skill 中 agents/plan-write.md 的角色编写计划。

执行环境信息:
- skill 根目录: $SKILL_ROOT
- 当前轮次: 第 $i / $MAX_PLAN_ITER 轮（首版）

请先读取以下文件以加载角色与模板:
- $SKILL_ROOT/agents/plan-write.md
- $SKILL_ROOT/references/document-templates.md

任务输入:
- 项目背景与需求文档: $ctx
- 输出路径: $plan_doc

请编写完整的实现计划方案。"
      fi
      run_agent "$prompt"
      [ -f "$plan_doc" ] || { err "未产出 $plan_doc"; exit 2; }
    else
      log "[1/2] 已存在 ${plan_doc}，跳过生成（恢复模式）"
    fi

    # 审查计划
    if [ ! -f "$review_doc" ]; then
      log "[2/2] 审查计划方案 $review_doc"
      local rprompt="请按 auto-plan-and-execute skill 中 agents/plan-review.md 的角色审查计划。

执行环境信息:
- skill 根目录: $SKILL_ROOT
- 当前轮次: 第 $i / $MAX_PLAN_ITER 轮

请先读取以下文件以加载角色与规范:
- $SKILL_ROOT/agents/plan-review.md
- $SKILL_ROOT/references/status-protocol.md
- $SKILL_ROOT/references/document-templates.md

任务输入:
- 项目背景与需求文档: $ctx
- 待审计划方案: $plan_doc
- 审查报告输出路径: $review_doc

请独立、严格地审查计划方案，并在报告末尾输出 STATUS: PASS 或 STATUS: NEEDS_REVISION（独占一行，无任何修饰）。"
      run_agent "$rprompt"
      [ -f "$review_doc" ] || { err "未产出 $review_doc"; exit 2; }
    else
      log "[2/2] 已存在 ${review_doc}，跳过审查（恢复模式）"
    fi

    write_state "$instance" "$STAGE_PLAN" "$i" "0" ""

    local st
    st="$(check_status "$review_doc")"
    case "$st" in
      PASS)
        log "✅ 计划审查 STATUS: PASS，计划阶段完成"
        finalize_plan "$instance" "$plan_doc"
        return 0
        ;;
      NEEDS_REVISION)
        warn "计划审查 STATUS: NEEDS_REVISION，进入下一轮迭代"
        ;;
      MISSING)
        err "审查报告 $review_doc 末尾缺少 STATUS 标记！"
        err "请检查报告，必要时手动补 STATUS 行后用 --resume 继续。"
        exit 3
        ;;
    esac
  done

  warn "已达到计划阶段最大轮数 ${MAX_PLAN_ITER}，以最后一版计划进入下一阶段"
  finalize_plan "$instance" "$(work_dir "$instance")/plan-v$MAX_PLAN_ITER.md"
  return 0
}

# 把最终通过的计划复制为 plan.md（无版本后缀）
finalize_plan() {
  local instance="$1" src="$2"
  local plan_final
  plan_final="$(work_dir "$instance")/plan.md"
  cp "$src" "$plan_final"
  log "已将定稿计划复制为 $plan_final"
  write_state "$instance" "$STAGE_CONFIRM" "$(read_state "$instance" plan_iter)" "0" "$plan_final"
}

stage_confirm() {
  local instance="$1"
  local plan_final
  plan_final="$(read_state "$instance" plan_final)"
  log "═══ 人工确认点 ═══"
  log "计划已定稿: $plan_final"
  log "请在另一个终端打开审阅。"

  if [ "$SKIP_CONFIRM" = "1" ]; then
    warn "SKIP_CONFIRM=1，跳过人工确认直接进入实施"
    write_state "$instance" "$STAGE_EXECUTE" "$(read_state "$instance" plan_iter)" "0" "$plan_final"
    return 0
  fi

  while true; do
    printf "\n是否继续进入实施阶段? [y/n/e=编辑后再确认]: "
    read -r ans </dev/tty
    case "$ans" in
      y|Y)
        log "用户确认，进入实施阶段"
        write_state "$instance" "$STAGE_EXECUTE" "$(read_state "$instance" plan_iter)" "0" "$plan_final"
        return 0
        ;;
      n|N)
        warn "用户终止流程。可稍后用 --resume 继续。"
        exit 0
        ;;
      e|E)
        log "请编辑 $plan_final 后回到这里继续确认"
        ;;
      *)
        echo "请输入 y / n / e"
        ;;
    esac
  done
}

stage_execute_loop() {
  local instance="$1" wd
  wd="$(work_dir "$instance")"
  local ctx="$wd/context.md"
  local plan_final
  plan_final="$(read_state "$instance" plan_final)"

  local start_iter
  start_iter="$(read_state "$instance" exec_iter)"
  [ -z "$start_iter" ] && start_iter=0
  start_iter=$((start_iter + 0))

  for ((i=start_iter+1; i<=MAX_EXEC_ITER; i++)); do
    log "═══ 实施阶段 第 $i/$MAX_EXEC_ITER 轮 ═══"
    local exec_log="$wd/execution-log-v$i.md"
    local review_doc="$wd/execution-review-v$i.md"
    local prev_review="$wd/execution-review-v$((i-1)).md"

    if [ ! -f "$exec_log" ]; then
      log "[1/2] 实施计划，日志输出到 $exec_log"
      local prompt
      if [ -f "$prev_review" ]; then
        prompt="请按 auto-plan-and-execute skill 中 agents/execute-plan.md 的角色实施计划。

执行环境信息:
- skill 根目录: $SKILL_ROOT
- 当前轮次: 第 $i / $MAX_EXEC_ITER 轮（修补轮）

请先读取:
- $SKILL_ROOT/agents/execute-plan.md
- $SKILL_ROOT/references/document-templates.md

任务输入:
- 项目背景与需求文档: $ctx
- 定稿计划方案: $plan_final
- 上一轮实施审查报告: $prev_review
- 本轮实施日志输出路径: $exec_log

请基于审查报告中的 P0/P1 问题进行修补式调整，并产出实施日志。"
      else
        prompt="请按 auto-plan-and-execute skill 中 agents/execute-plan.md 的角色实施计划。

执行环境信息:
- skill 根目录: $SKILL_ROOT
- 当前轮次: 第 $i / $MAX_EXEC_ITER 轮（首轮）

请先读取:
- $SKILL_ROOT/agents/execute-plan.md
- $SKILL_ROOT/references/document-templates.md

任务输入:
- 项目背景与需求文档: $ctx
- 定稿计划方案: $plan_final
- 实施日志输出路径: $exec_log

请按计划方案落地代码改动，并产出实施日志。"
      fi
      run_agent "$prompt"
      [ -f "$exec_log" ] || { err "未产出 $exec_log"; exit 2; }
    else
      log "[1/2] 已存在 ${exec_log}，跳过实施（恢复模式）"
    fi

    if [ ! -f "$review_doc" ]; then
      log "[2/2] 审查实施 $review_doc"
      local rprompt="请按 auto-plan-and-execute skill 中 agents/execution-review.md 的角色审查实施。

执行环境信息:
- skill 根目录: $SKILL_ROOT
- 当前轮次: 第 $i / $MAX_EXEC_ITER 轮

请先读取:
- $SKILL_ROOT/agents/execution-review.md
- $SKILL_ROOT/references/status-protocol.md
- $SKILL_ROOT/references/document-templates.md

任务输入:
- 项目背景与需求文档: $ctx
- 定稿计划方案: $plan_final
- 本轮实施日志: $exec_log
- 审查报告输出路径: $review_doc

请用 git diff 看实际改动，独立审查实施质量，末尾输出 STATUS: PASS 或 STATUS: NEEDS_REVISION（独占一行）。"
      run_agent "$rprompt"
      [ -f "$review_doc" ] || { err "未产出 $review_doc"; exit 2; }
    else
      log "[2/2] 已存在 ${review_doc}，跳过审查（恢复模式）"
    fi

    write_state "$instance" "$STAGE_EXECUTE" "$(read_state "$instance" plan_iter)" "$i" "$plan_final"

    local st
    st="$(check_status "$review_doc")"
    case "$st" in
      PASS)
        log "✅ 实施审查 STATUS: PASS，实施阶段完成"
        write_state "$instance" "$STAGE_SUMMARY" "$(read_state "$instance" plan_iter)" "$i" "$plan_final"
        return 0
        ;;
      NEEDS_REVISION)
        warn "实施审查 STATUS: NEEDS_REVISION，进入下一轮迭代"
        ;;
      MISSING)
        err "审查报告 $review_doc 末尾缺少 STATUS 标记"
        exit 3
        ;;
    esac
  done

  warn "已达到实施阶段最大轮数 ${MAX_EXEC_ITER}，强制进入总结阶段"
  write_state "$instance" "$STAGE_SUMMARY" "$(read_state "$instance" plan_iter)" "$MAX_EXEC_ITER" "$plan_final"
  return 0
}

stage_summary() {
  local instance="$1" wd
  wd="$(work_dir "$instance")"
  local plan_final
  plan_final="$(read_state "$instance" plan_final)"
  local summary="$wd/final-summary.md"
  local ctx="$wd/context.md"

  log "═══ 生成最终总结 ═══"

  local exec_logs exec_reviews
  exec_logs="$(ls -1 "$wd"/execution-log-v*.md 2>/dev/null | tr '\n' ' ')"
  exec_reviews="$(ls -1 "$wd"/execution-review-v*.md 2>/dev/null | tr '\n' ' ')"

  local prompt="请基于以下文档生成最终的【项目需求实现总结】，写到 ${summary}。

请先读取:
- $SKILL_ROOT/references/document-templates.md （使用其中的'最终交付总结'章节模板）

输入文档:
- 背景需求: $ctx
- 定稿计划: $plan_final
- 实施日志: $exec_logs
- 实施审查报告: $exec_reviews

写作要求:
- 这是面向交付的文档，不要出现 v1/v2/审查指出 等迭代痕迹
- 信息完整、自洽，读者无需翻看其他文档即可了解全貌
- 用当前代理可用的写入工具写入指定路径"

  run_agent "$prompt"
  [ -f "$summary" ] || { err "总结文档未生成"; exit 2; }

  write_state "$instance" "$STAGE_DONE" "$(read_state "$instance" plan_iter)" "$(read_state "$instance" exec_iter)" "$plan_final"
  log "✅ 流程完成！最终交付:"
  log "    - 计划方案: $plan_final"
  log "    - 实施总结: $summary"
  log "    - 工作目录: $wd"
}

# ---------- 入口命令 ----------

cmd_start() {
  local input="$1"
  local is_file="false"
  if [ -f "$input" ]; then
    is_file="true"
  fi

  local name uuid instance
  name="$(infer_name "$input" "$is_file")"
  uuid="$(gen_uuid)"
  instance="${name}-${uuid}"

  local wd
  wd="$(work_dir "$instance")"
  if [ -d "$wd" ]; then
    err "工作目录已存在: ${wd}（UUID 罕见碰撞？请重试）"
    exit 1
  fi
  mkdir -p "$wd"

  # 生成 context.md
  if [ "$is_file" = "true" ]; then
    cp "$input" "$wd/context.md"
  else
    printf '%s\n' "$input" > "$wd/context.md"
  fi

  write_state "$instance" "$STAGE_PLAN" "0" "0" ""
  log "已创建流程实例: $instance"
  log "  - 工作目录: $wd"
  log "  - 输入类型: $([ "$is_file" = "true" ] && echo "文档($input)" || echo "文本")"

  run_pipeline "$instance"
}

cmd_resume() {
  local partial="$1"
  local instance
  instance="$(resolve_instance "$partial")" || exit 1
  log "从 $(work_dir "$instance") 恢复运行（stage=$(read_state "$instance" stage)）"
  run_pipeline "$instance"
}

cmd_status() {
  local partial="$1"
  local instance
  instance="$(resolve_instance "$partial")" || exit 1
  cat "$(state_file "$instance")"
}

cmd_list() {
  if [ ! -d "$AUTO_FLOW_DIR" ]; then
    log "尚无任何流程实例（$AUTO_FLOW_DIR 不存在）"
    return 0
  fi
  log "已有流程实例（$AUTO_FLOW_DIR/）:"
  local count=0
  while IFS= read -r inst; do
    [ -z "$inst" ] && continue
    local sf="$AUTO_FLOW_DIR/$inst/state.json"
    if [ -f "$sf" ]; then
      local stage
      stage="$(read_state "$inst" stage)"
      printf "  - %-50s stage=%s\n" "$inst" "$stage"
    else
      printf "  - %-50s (no state)\n" "$inst"
    fi
    count=$((count + 1))
  done < <(list_instances)
  if [ "$count" -eq 0 ]; then
    log "（空）"
  fi
}

run_pipeline() {
  local instance="$1"
  local stage
  stage="$(read_state "$instance" stage)"
  [ -z "$stage" ] && stage="$STAGE_PLAN"

  case "$stage" in
    "$STAGE_PLAN")
      stage_plan_loop "$instance"
      stage_confirm "$instance"
      stage_execute_loop "$instance"
      stage_summary "$instance"
      ;;
    "$STAGE_CONFIRM")
      stage_confirm "$instance"
      stage_execute_loop "$instance"
      stage_summary "$instance"
      ;;
    "$STAGE_EXECUTE")
      stage_execute_loop "$instance"
      stage_summary "$instance"
      ;;
    "$STAGE_SUMMARY")
      stage_summary "$instance"
      ;;
    "$STAGE_DONE")
      log "该实例已完成。如需重做，请删除工作目录后重新启动。"
      ;;
    *)
      err "未知阶段: $stage"
      exit 1
      ;;
  esac
}

main() {
  if [ $# -lt 1 ]; then usage; exit 1; fi

  case "$1" in
    -h|--help) usage; exit 0 ;;
    --list)    cmd_list; exit 0 ;;
    --resume)
      [ $# -ge 2 ] || { err "用法: $0 --resume <名称|uuid|名称-uuid>"; exit 1; }
      require_cmd "$AGENT_CMD"
      cmd_resume "$2"
      ;;
    --status)
      [ $# -ge 2 ] || { err "用法: $0 --status <名称|uuid|名称-uuid>"; exit 1; }
      cmd_status "$2"
      ;;
    -*) err "未知选项: $1"; usage; exit 1 ;;
    *)
      require_cmd "$AGENT_CMD"
      cmd_start "$1"
      ;;
  esac
}

main "$@"
