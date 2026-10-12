param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR,
  [Parameter(Mandatory=$true)][ValidateSet('activate', 'clear', 'status')][string]$Action,
  [string]$ProjectSlug
)
$ErrorActionPreference = 'Stop'

if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
$claudeDir = Join-Path $ProjectDir '.claude'
$activeProjectFile = Join-Path $claudeDir '.active-project'
$projectsRoot = Join-Path $ProjectDir 'bossdream_projects'

function Get-AvailableSlugs {
  if (-not (Test-Path $projectsRoot)) { return @() }
  $slugs = @()
  foreach ($dir in Get-ChildItem -Path $projectsRoot -Directory -ErrorAction SilentlyContinue) {
    if (Test-Path (Join-Path $dir.FullName '.bossdream-project/project.json')) { $slugs += $dir.Name }
  }
  return $slugs
}

switch ($Action) {

  'clear' {
    if (Test-Path $activeProjectFile) {
      Remove-Item $activeProjectFile -Force
      Write-Output "active-project CLEARED: modo normal restaurado - /bossdream-plan y /bossdream-implement funcionan sin proyecto activo hasta que actives otro."
    } else {
      Write-Output "active-project: no habia ningun proyecto activo, nada que limpiar."
    }
    exit 0
  }

  'status' {
    $current = if (Test-Path $activeProjectFile) { (Get-Content -Encoding utf8 $activeProjectFile -Raw).Trim() } else { $null }
    $available = @(Get-AvailableSlugs)
    if ($current) {
      Write-Output "active-project: '$current' esta activo."
    } else {
      Write-Output "active-project: ninguno activo (modo normal)."
    }
    if ($available.Count -gt 0) {
      Write-Output "Proyectos disponibles en bossdream_projects/: $($available -join ', ')"
    } else {
      Write-Output "No hay proyectos en bossdream_projects/ todavia."
    }
    exit 0
  }

  'activate' {
    if (-not $ProjectSlug) {
      Write-Output "set-active-project: falta -ProjectSlug para activar."
      exit 1
    }

    $projectJsonPath = Join-Path $projectsRoot "$ProjectSlug/.bossdream-project/project.json"
    if (-not (Test-Path $projectJsonPath)) {
      $available = @(Get-AvailableSlugs)
      $availableMsg = if ($available.Count -gt 0) { "Disponibles: $($available -join ', ')" } else { "No hay ningun proyecto en bossdream_projects/ todavia." }
      Write-Output "set-active-project: '$ProjectSlug' no existe en bossdream_projects/. $availableMsg"
      exit 1
    }

    New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
    [System.IO.File]::WriteAllText($activeProjectFile, $ProjectSlug)

    $project = Get-Content -Encoding utf8 $projectJsonPath -Raw | ConvertFrom-Json
    $validationPath = Join-Path $projectsRoot "$ProjectSlug/.bossdream-project/validation.json"
    $overallStatus = if (Test-Path $validationPath) { (Get-Content -Encoding utf8 $validationPath -Raw | ConvertFrom-Json).overallStatus } else { 'desconocido' }

    Write-Output "active-project ACTIVATED: '$ProjectSlug' (clasificacion: $($project.classification), validation.json: $overallStatus)."
    exit 0
  }
}
