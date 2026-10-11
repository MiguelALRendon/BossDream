$ErrorActionPreference = 'Stop'
if ($env:CLAUDE_PLUGIN_OPTION_ENABLE_READ_BUDGET_HOOK -ne 'true') { exit 0 }
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }
$tool = $j.tool_name
$ti = $j.tool_input
$ask = $null
if ($tool -eq 'Read' -and -not $ti.limit) {
  $ask = 'Read sin limit: usa offset+limit, o delega a Explore si el alcance es amplio (economia de tokens).'
}
elseif ($tool -eq 'Grep' -and $ti.output_mode -eq 'content' -and -not $ti.head_limit) {
  $ask = 'Grep content sin head_limit: acota, o consulta codebase-memory en su lugar.'
}
if ($ask) {
  (@{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'ask'; permissionDecisionReason = $ask } } | ConvertTo-Json -Compress -Depth 5)
}
exit 0
