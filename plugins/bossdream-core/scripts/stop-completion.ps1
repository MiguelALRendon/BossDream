$ErrorActionPreference = 'Stop'
$raw = [Console]::In.ReadToEnd()
$j = $null
$proj = $env:CLAUDE_PROJECT_DIR
if ($raw) { try { $j = $raw | ConvertFrom-Json; if ($j.cwd) { $proj = $j.cwd } } catch {} }
if (-not $proj) { $proj = (Get-Location).Path }
Import-Module (Join-Path $PSScriptRoot 'plugin-paths.psm1')
$proj = Get-ProjectRoot $proj

# stop_hook_active evita re-entrada infinita cuando el propio hook provoco la continuacion
if ($j -and $j.stop_hook_active -eq $true) { exit 0 }

# corre el pipeline solo si este turno edito codigo (marcador de mark-dirty); se consume al leerlo
$marker = Join-Path $proj '.claude/.bossdream-dirty'
if (-not (Test-Path $marker)) { exit 0 }
Remove-Item $marker -Force -ErrorAction SilentlyContinue

# recordatorio si las pruebas estan apagadas y este turno edito codigo
$testReminder = ''
$bossdreamTestPath = Join-Path $proj 'bossdream.json'
if (Test-Path $bossdreamTestPath) {
  try { $tcfg = (Get-Content -Encoding utf8 $bossdreamTestPath -Raw | ConvertFrom-Json).testing; if ($tcfg -and $tcfg.enabled -ne $true) { $testReminder = 'Recordatorio: las pruebas unitarias estan APAGADAS (testing.enabled=false); este cambio no queda cubierto por unit tests. Enciende el switch y define testing.project cuando quieras cobertura.' } } catch {}
}

$completionPath = Join-Path $proj 'completion.json'
if (-not (Test-Path $completionPath)) { exit 0 }
$completion = Get-Content -Encoding utf8 $completionPath -Raw | ConvertFrom-Json
$maxBlocks = if ($completion.maxBlocks) { [int]$completion.maxBlocks } else { 8 }

# scripts hermanos (pipeline, tasks-complete) viven junto a este, tanto en el plugin como en .claude/bossdream-hooks/
$scripts = $PSScriptRoot

$failures = @()
$g = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'pipeline.ps1') -Tier local -ProjectDir $proj 2>&1
if ($LASTEXITCODE -ne 0) { $failures += ($g -join "`n") }
$tk = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'tasks-complete.ps1') -ProjectDir $proj 2>&1
if ($LASTEXITCODE -ne 0) { $failures += ($tk -join "`n") }

$statePath = Join-Path $proj '.claude/.completion-state.json'
$count = 0
if (Test-Path $statePath) { try { $count = [int]((Get-Content -Encoding utf8 $statePath -Raw | ConvertFrom-Json).blocks) } catch { $count = 0 } }

if ($failures.Count -eq 0) {
  if (Test-Path $statePath) { Remove-Item $statePath -Force }
  if ($testReminder) { (@{ continue = $true; systemMessage = $testReminder } | ConvertTo-Json -Compress -Depth 6) }
  exit 0
}

$count++
if ($count -ge $maxBlocks) {
  if (Test-Path $statePath) { Remove-Item $statePath -Force }
  $msg = "Completion NO cumplido tras $maxBlocks intentos. Escalado al usuario. Pendiente:`n" + ($failures -join "`n")
  (@{ continue = $true; systemMessage = $msg } | ConvertTo-Json -Compress -Depth 6)
  exit 0
}

$dir = Split-Path $statePath -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
(@{ blocks = $count } | ConvertTo-Json) | Set-Content -Path $statePath -Encoding utf8
$reason = "Completion Criteria pendiente (intento $count/$maxBlocks). Resuelve y reintenta:`n" + ($failures -join "`n")
if ($testReminder) { $reason = $reason + "`n" + $testReminder }
(@{ decision = 'block'; reason = $reason } | ConvertTo-Json -Compress -Depth 6)
exit 0
