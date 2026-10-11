param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR
)
$ErrorActionPreference = 'Stop'
if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }

# proxy deterministico de "doc drift": notas crudas en _inbox que aun no pasaron por /docs-rewrite
$inbox = Join-Path $ProjectDir 'docs/_inbox'
if (-not (Test-Path $inbox)) { Write-Output 'docdrift-check: sin docs/_inbox, nada que revisar'; exit 0 }

$pending = Get-ChildItem -Path $inbox -File -Recurse -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -ne 'README.md' }

if ($pending.Count -gt 0) {
  $list = ($pending | ForEach-Object { ($_.FullName.Substring($ProjectDir.Length) -replace '\\', '/').TrimStart('/') }) -join "`n"
  Write-Output "DOCDRIFT FAIL: hay notas sin procesar en docs/_inbox/ (corre /docs-rewrite):`n$list"
  exit 1
}
Write-Output 'docdrift-check OK (docs/_inbox vacio)'
exit 0
