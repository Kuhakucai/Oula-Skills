#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS_SCRIPT="$SCRIPT_DIR/codex-agent.ps1"

if command -v cygpath >/dev/null 2>&1; then
  PS_SCRIPT_WIN="$(cygpath -w "$PS_SCRIPT")"
else
  PS_SCRIPT_WIN="$PS_SCRIPT"
fi

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT_WIN" "$@"