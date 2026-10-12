param([string]$ProjectDir = $env:CLAUDE_PROJECT_DIR)
$ErrorActionPreference = 'Stop'
if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }

$active = Join-Path $ProjectDir '.claude/.active-plan'
$targets = @()
if (Test-Path $active) {
  $f = (Get-Content -Encoding utf8 $active -Raw).Trim()
  $p = Join-Path $ProjectDir "plans/$f/tasks.md"
  if (Test-Path $p) { $targets += $p }
}
else {
  $specsDir = Join-Path $ProjectDir 'plans'
  if (Test-Path $specsDir) {
    $targets = Get-ChildItem -Path $specsDir -Recurse -Filter 'tasks.md' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '[\\/]_TEMPLATE[\\/]' } | ForEach-Object { $_.FullName }
  }
}
if ($targets.Count -eq 0) { Write-Output 'tasks OK (sin tasks.md)'; exit 0 }

$open = @()
foreach ($t in $targets) {
  $lines = Get-Content -Encoding utf8 $t
  foreach ($l in $lines) { if ($l -match '^\s*[-*]\s*\[\s\]') { $open += "$t : $($l.Trim())" } }
}
if ($open.Count -gt 0) { Write-Output ("TASKS PENDIENTES:`n" + ($open -join "`n")); exit 1 }
Write-Output 'tasks OK'
exit 0
