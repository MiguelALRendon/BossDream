$ErrorActionPreference = 'Stop'
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }
$cmd = [string]$j.tool_input.command
if (-not $cmd) { exit 0 }

$danger = @(
  'rm\s+-rf\s+[/~]',
  'rm\s+-rf\s+\*',
  'git\s+push\s+.*--force',
  'git\s+reset\s+--hard',
  'Remove-Item.*-Recurse.*-Force.*[\\/]',
  'format\s+[a-zA-Z]:',
  '>\s*/dev/sd',
  ':\(\)\s*\{\s*:\|:'
)
foreach ($p in $danger) {
  if ($cmd -match $p) {
    $reason = "Comando potencialmente destructivo bloqueado por BossDream (patron: $p). Si es intencional, ejecutalo manualmente fuera del agente."
    (@{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reason } } | ConvertTo-Json -Compress -Depth 5)
    exit 0
  }
}
exit 0
