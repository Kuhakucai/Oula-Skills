#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLOW="$ROOT/scripts/verified-dev-flow.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  [ "$1" = "$2" ] || fail "expected '$2', got '$1'"
}

VERIFIED_DEV_FLOW_LIB_ONLY=1 source "$FLOW"

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

printf '%s\n' 'STATUS: NEEDS_REVISION' '说明文字' 'STATUS: PASS' > "$tmp/pass.md"
assert_eq "$(check_status "$tmp/pass.md")" "PASS"

printf '%s\n' 'STATUS: PASS' 'STATUS: NEEDS_REVISION' > "$tmp/revise.md"
assert_eq "$(check_status "$tmp/revise.md")" "NEEDS_REVISION"

printf '%s\n' 'STATUS: PASS' '尾部正文' > "$tmp/invalid.md"
assert_eq "$(check_status "$tmp/invalid.md")" "MISSING"

VERIFIED_DEV_FLOW_DIR="$tmp/flows"
MAX_PLAN_ITER=1
blocked_plan="blocked-plan-deadbeef"
mkdir -p "$VERIFIED_DEV_FLOW_DIR/$blocked_plan"
printf 'requirement\n' > "$VERIFIED_DEV_FLOW_DIR/$blocked_plan/context.md"
printf 'plan\n' > "$VERIFIED_DEV_FLOW_DIR/$blocked_plan/plan-v1.md"
printf 'STATUS: NEEDS_REVISION\n' > "$VERIFIED_DEV_FLOW_DIR/$blocked_plan/plan-review-v1.md"
write_state "$blocked_plan" "$STAGE_PLAN" "1" "0" ""
if stage_plan_loop "$blocked_plan"; then
  fail "plan loop must stop after failed maximum iteration"
fi
test ! -f "$VERIFIED_DEV_FLOW_DIR/$blocked_plan/plan.md"

MAX_EXEC_ITER=1
blocked_exec="blocked-exec-deadbeef"
mkdir -p "$VERIFIED_DEV_FLOW_DIR/$blocked_exec"
printf 'requirement\n' > "$VERIFIED_DEV_FLOW_DIR/$blocked_exec/context.md"
printf 'plan\n' > "$VERIFIED_DEV_FLOW_DIR/$blocked_exec/plan.md"
printf 'log\n' > "$VERIFIED_DEV_FLOW_DIR/$blocked_exec/execution-log-v1.md"
printf 'STATUS: NEEDS_REVISION\n' > "$VERIFIED_DEV_FLOW_DIR/$blocked_exec/execution-review-v1.md"
write_state "$blocked_exec" "$STAGE_EXECUTE" "1" "1" "$VERIFIED_DEV_FLOW_DIR/$blocked_exec/plan.md"
if stage_execute_loop "$blocked_exec"; then
  fail "execution loop must stop after failed maximum iteration"
fi
test ! -f "$VERIFIED_DEV_FLOW_DIR/$blocked_exec/final-summary.md"

manual="manual-edit-deadbeef"
mkdir -p "$VERIFIED_DEV_FLOW_DIR/$manual"
printf 'requirement\n' > "$VERIFIED_DEV_FLOW_DIR/$manual/context.md"
printf 'approved plan\n' > "$VERIFIED_DEV_FLOW_DIR/$manual/plan.md"
plan_checksum "$VERIFIED_DEV_FLOW_DIR/$manual/plan.md" > "$VERIFIED_DEV_FLOW_DIR/$manual/plan-approved.cksum"
write_state "$manual" "$STAGE_CONFIRM" "1" "0" "$VERIFIED_DEV_FLOW_DIR/$manual/plan.md"
printf 'edited plan\n' > "$VERIFIED_DEV_FLOW_DIR/$manual/plan.md"
run_agent() {
  local output
  output="$(printf '%s\n' "$1" | sed -n 's/^- 审查报告输出路径: //p' | tail -n1)"
  printf 'STATUS: PASS\n' > "$output"
}
SKIP_CONFIRM=1
stage_confirm "$manual"
assert_eq "$(read_state "$manual" stage)" "$STAGE_EXECUTE"
assert_eq "$(cat "$VERIFIED_DEV_FLOW_DIR/$manual/plan-approved.cksum")" "$(plan_checksum "$VERIFIED_DEV_FLOW_DIR/$manual/plan.md")"

project="$tmp/project"
mkdir -p "$project"
VDF_SRC="$ROOT" bash "$ROOT/install.sh" "$project"
test -f "$project/.agents/skills/verified-dev-flow/SKILL.md"
test -x "$project/.agents/skills/verified-dev-flow/verified-dev-flow.sh"
test -f "$project/.claude/skills/verified-dev-flow/SKILL.md"
test ! -f "$project/.agents/skills/verified-dev-flow/install.sh"

bash "$ROOT/install.sh" --uninstall "$project"
test ! -d "$project/.agents/skills/verified-dev-flow"
test ! -d "$project/.claude/skills/verified-dev-flow"

if grep -q '强制进入总结阶段\|以最后一版计划进入下一阶段' "$FLOW"; then
  fail "found forced progression after failed review"
fi

printf 'PASS: verified-dev-flow tests\n'
