$ErrorActionPreference = 'Stop'

$codex = $env:CODEX_CMD_WIN
if ([string]::IsNullOrWhiteSpace($codex)) {
    $codex = Join-Path $env:APPDATA 'npm\codex.cmd'
}

try {
    & $codex @args
    exit $LASTEXITCODE
} catch {
    Write-Error "Failed to run Codex CLI at '$codex'. Install with npm install -g @openai/codex or set CODEX_CMD_WIN. $($_.Exception.Message)"
    exit 127
}