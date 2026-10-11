param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR,
  [Parameter(Mandatory=$true)][string]$Slug,
  [string]$ProjectSlug
)
$ErrorActionPreference = 'Stop'

if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
if (-not $ProjectSlug) {
  $activeProjectFile = Join-Path $ProjectDir '.claude/.active-project'
  if (-not (Test-Path $activeProjectFile)) {
    Write-Output "bossdream-learning-publish BLOCKED: no hay proyecto activo (.claude/.active-project) y no se paso -ProjectSlug."
    exit 1
  }
  $ProjectSlug = (Get-Content $activeProjectFile -Raw).Trim()
}

$dotDir = Join-Path $ProjectDir "bossdream_projects/$ProjectSlug/.bossdream-project"
$logPath = Join-Path $dotDir "pattern-$Slug.log"
$tutorialPath = Join-Path $dotDir "human-explanations/$Slug.md"
$destDir = Join-Path $ProjectDir "docs/human-explanations"
$destPath = Join-Path $destDir "$Slug.md"

if (-not (Test-Path $logPath)) {
  Write-Output "bossdream-learning-publish BLOCKED: no existe log de patron en '$logPath'."
  exit 1
}

$aprobaciones = @(Get-Content $logPath | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.etapa -eq 'aprobacion' -and $_.veredicto -eq 'pass' })
if ($aprobaciones.Count -eq 0) {
  Write-Output "bossdream-learning-publish BLOCKED: '$logPath' no tiene una entrada 'aprobacion' con veredicto 'pass' - tutorial NO publicado."
  exit 1
}

if (-not (Test-Path $tutorialPath)) {
  Write-Output "bossdream-learning-publish BLOCKED: tutorial no encontrado en '$tutorialPath'."
  exit 1
}

New-Item -ItemType Directory -Force -Path $destDir | Out-Null
Copy-Item -Path $tutorialPath -Destination $destPath -Force

Write-Output "bossdream-learning-publish OK: '$Slug' publicado en '$destPath'."
exit 0
