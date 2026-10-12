$ErrorActionPreference = 'Stop'
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }

$proj = [string]$j.cwd
if (-not $proj) { $proj = $env:CLAUDE_PROJECT_DIR }
if (-not $proj) { exit 0 }
Import-Module (Join-Path $PSScriptRoot 'plugin-paths.psm1')
$proj = Get-ProjectRoot $proj

$activeProjectFile = Join-Path $proj '.claude/.active-project'
if (-not (Test-Path $activeProjectFile)) { exit 0 }
$slug = (Get-Content -Encoding utf8 $activeProjectFile -Raw).Trim()
if (-not $slug) { exit 0 }

$dotDir = Join-Path $proj "bossdream_projects/$slug/.bossdream-project"
$validationPath = Join-Path $dotDir 'validation.json'
$status = $null
if (Test-Path $validationPath) {
  try { $status = (Get-Content -Encoding utf8 $validationPath -Raw | ConvertFrom-Json).overallStatus } catch { $status = $null }
}

$projectJsonPath = Join-Path $dotDir 'project.json'
$oneLiner = $null
if (Test-Path $projectJsonPath) {
  $name = $null
  try { $name = (Get-Content $projectJsonPath -Raw -Encoding utf8 | ConvertFrom-Json).name } catch { $name = $null }
  if ($name) {
    # ASCII-only: el pipe de este host usa $OutputEncoding=us-ascii, cualquier caracter no-ASCII se corrompe al salir por stdout
    $normalized = $name.Normalize([System.Text.NormalizationForm]::FormD)
    $noAccents = -join ($normalized.ToCharArray() | Where-Object { [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark })
    $name = ($noAccents -replace '[^\x00-\x7F]', '').Trim()
    if ($name) { $oneLiner = $name }
  }
}

$ctx = "[proyecto-activo] '$slug'"
if ($status) { $ctx += " (overallStatus: $status)" }
if ($oneLiner) { $ctx += " - $oneLiner" }

(@{ hookSpecificOutput = @{ hookEventName = 'UserPromptSubmit'; additionalContext = $ctx } } | ConvertTo-Json -Compress -Depth 5)
exit 0
