$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'prompt-matchers.psm1')
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }
$proj = $j.cwd
if (-not $proj) { $proj = $env:CLAUDE_PROJECT_DIR }
if (-not $proj) { exit 0 }

$prompt = [string]$j.prompt
$dir = Join-Path $proj '.claude'
$modeFile = Join-Path $dir '.work-mode'
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

$dirtyMarker = Join-Path $dir '.bossdream-dirty'
if (Test-Path $dirtyMarker) { Remove-Item $dirtyMarker -Force -ErrorAction SilentlyContinue }

# fija .work-mode desde el comando del usuario (unico canal para pasar a un modo editable)

if (Test-BossdreamPlanPrompt $prompt) {
  [System.IO.File]::WriteAllText($modeFile, 'plan')
}
elseif ($prompt -match '(^|\s)/plan(\s|$)') {
  [System.IO.File]::WriteAllText($modeFile, 'plan')
}
elseif (Test-BossdreamImplementPrompt $prompt) {
  [System.IO.File]::WriteAllText($modeFile, 'implement')
}
elseif ($modeName = Test-BossdreamModePrompt $prompt) {
  $m = $modeName.ToLower()
  if ($m -eq 'clear') { if (Test-Path $modeFile) { Remove-Item $modeFile -Force } }
  else { [System.IO.File]::WriteAllText($modeFile, $m) }
}

if (Test-Path (Join-Path $proj 'plans')) { exit 0 }
$ctx = 'Recordatorio BossDream: este proyecto aun no tiene carpeta plans/. Para cambios no triviales crea la spec con /plan-new antes de implementar (Gate 1 readiness).'
(@{ hookSpecificOutput = @{ hookEventName = 'UserPromptSubmit'; additionalContext = $ctx } } | ConvertTo-Json -Compress -Depth 5)
exit 0
