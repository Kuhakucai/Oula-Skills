#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="verified-dev-flow"
VDF_REPO="${VDF_REPO:-Kuhakucai/Oula-Skills}"
VDF_REF="${VDF_REF:-main}"
VDF_SKILL_PATH="${VDF_SKILL_PATH:-verified-dev-flow}"

log() { printf '[install] %s\n' "$*"; }
err() { printf '[install] ERROR: %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
用法:
  ./install.sh [目标项目目录]
  ./install.sh -g
  ./install.sh --uninstall [目标项目目录]
  ./install.sh -g --uninstall

环境变量:
  VDF_REPO        GitHub 仓库，默认 Kuhakucai/Oula-Skills
  VDF_REF         分支、标签或提交，默认 main
  VDF_SKILL_PATH  Skill 在仓库内的路径，默认 verified-dev-flow
  VDF_SRC         使用本地 Skill 源目录，跳过下载
EOF
}

global_install=0
uninstall=0
target=""

while [ $# -gt 0 ]; do
  case "$1" in
    -g|--global) global_install=1 ;;
    --uninstall) uninstall=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) err "未知参数: $1"; usage; exit 2 ;;
    *)
      [ -z "$target" ] || { err "只能指定一个目标目录"; exit 2; }
      target="$1"
      ;;
  esac
  shift
done

if [ "$global_install" = "1" ] && [ -n "$target" ]; then
  err "-g 与目标目录不能同时使用"
  exit 2
fi

if [ "$global_install" = "1" ]; then
  base_dir="${HOME:?HOME 未设置}"
else
  base_dir="${target:-$PWD}"
  mkdir -p "$base_dir"
  base_dir="$(cd "$base_dir" && pwd)"
fi

agents_dest="$base_dir/.agents/skills/$SKILL_NAME"
claude_dest="$base_dir/.claude/skills/$SKILL_NAME"

remove_installation() {
  local dest="$1"
  case "$dest" in
    */.agents/skills/$SKILL_NAME|*/.claude/skills/$SKILL_NAME)
      rm -rf -- "$dest"
      log "已移除 $dest"
      ;;
    *)
      err "拒绝删除非预期路径: $dest"
      exit 3
      ;;
  esac
}

if [ "$uninstall" = "1" ]; then
  remove_installation "$agents_dest"
  remove_installation "$claude_dest"
  if [ "$global_install" = "1" ]; then
    link_path="$base_dir/.local/bin/$SKILL_NAME"
    [ ! -L "$link_path" ] || rm -- "$link_path"
  fi
  exit 0
fi

temp_dir=""
cleanup() {
  [ -z "$temp_dir" ] || rm -rf -- "$temp_dir"
}
trap cleanup EXIT

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
if [ -n "${VDF_SRC:-}" ]; then
  source_dir="$(cd "$VDF_SRC" && pwd)"
elif [ -n "$script_dir" ] && [ -f "$script_dir/SKILL.md" ]; then
  source_dir="$script_dir"
else
  command -v curl >/dev/null 2>&1 || { err "缺少 curl"; exit 1; }
  command -v tar >/dev/null 2>&1 || { err "缺少 tar"; exit 1; }
  temp_dir="$(mktemp -d)"
  archive="$temp_dir/repo.tar.gz"
  url="https://codeload.github.com/${VDF_REPO}/tar.gz/${VDF_REF}"
  log "正在从 $url 下载"
  curl -fsSL "$url" -o "$archive"
  tar -xzf "$archive" -C "$temp_dir"
  archive_root="$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d | head -n1)"
  source_dir="$archive_root/$VDF_SKILL_PATH"
fi

[ -f "$source_dir/SKILL.md" ] || { err "无效 Skill 源目录: $source_dir"; exit 1; }

install_to() {
  local dest="$1"
  local staging="${dest}.tmp.$$"
  mkdir -p "$(dirname "$dest")"
  rm -rf -- "$staging"
  mkdir -p "$staging"
  cp -R "$source_dir/." "$staging/"
  rm -rf -- "$staging/.github" "$staging/install.sh"
  chmod +x "$staging/verified-dev-flow.sh" "$staging/scripts/verified-dev-flow.sh" "$staging/scripts/codex-agent.sh"
  rm -rf -- "$dest"
  mv "$staging" "$dest"
  log "已安装到 $dest"
}

install_to "$agents_dest"
install_to "$claude_dest"

if [ "$global_install" = "1" ]; then
  mkdir -p "$base_dir/.local/bin"
  ln -sfn "$agents_dest/verified-dev-flow.sh" "$base_dir/.local/bin/$SKILL_NAME"
  log "全局命令: $base_dir/.local/bin/$SKILL_NAME"
fi

log "安装完成，来源 ${VDF_REPO}@${VDF_REF}/${VDF_SKILL_PATH}"
