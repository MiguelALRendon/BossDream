$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'plugin-paths.psm1')
$raw = [Console]::In.ReadToEnd()
$j = $null
$proj = $env:CLAUDE_PROJECT_DIR
if ($raw) { try { $j = $raw | ConvertFrom-Json; if ($j.cwd) { $proj = $j.cwd } } catch {} }
if (-not $proj) { $proj = (Get-Location).Path }

$activeProjectFile = Join-Path $proj '.claude/.active-project'
if (-not (Test-Path $activeProjectFile)) { exit 0 }
$slug = (Get-Content $activeProjectFile -Raw).Trim()
if (-not $slug) { exit 0 }

$dotDir = Join-Path $proj "bossdream_projects/$slug/.bossdream-project"
if (-not (Test-Path (Join-Path $dotDir 'project.json'))) { exit 0 }

$hostProjectDir = $env:CLAUDE_PROJECT_DIR
if (-not $hostProjectDir) { $hostProjectDir = (Get-Location).Path }
$canonicalScripts = Get-CanonicalPluginScriptsDir $hostProjectDir
try {
  & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File (Join-Path $canonicalScripts 'traceability-build.ps1') -ProjectDir $proj -ProjectSlug $slug 2>&1 | Out-Null
  & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File (Join-Path $canonicalScripts 'validation-check.ps1') -ProjectDir $proj -ProjectSlug $slug 2>&1 | Out-Null
} catch {}
exit 0
