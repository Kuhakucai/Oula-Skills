#!/usr/bin/env bash
# 根目录便捷入口 — 转发到 scripts/verified-dev-flow.sh
#
# 通过软链接（例如 install.sh -g 创建的 ~/.local/bin/verified-dev-flow）调用时，
# $0 / BASH_SOURCE[0] 会是软链接自身路径而非真实文件，必须先解析到真实路径再取 dirname，
# 否则会去 link 所在目录找 scripts/verified-dev-flow.sh，导致 "No such file or directory"。
src="${BASH_SOURCE[0]}"
while [ -L "$src" ]; do
  dir="$(cd -P "$(dirname "$src")" && pwd)"
  src="$(readlink "$src")"
  [[ $src != /* ]] && src="$dir/$src"
done
real_dir="$(cd -P "$(dirname "$src")" && pwd)"
exec "$real_dir/scripts/verified-dev-flow.sh" "$@"
