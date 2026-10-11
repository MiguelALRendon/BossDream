param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR,
  [Parameter(Mandatory=$true)][string]$Motivo,
  [string]$Alcance = 'solo-esta-tarea',
  [string]$Quien = [Environment]::UserName
)
$ErrorActionPreference = 'Stop'

if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
$activeProjectFile = Join-Path $ProjectDir '.claude/.active-project'
if (-not (Test-Path $activeProjectFile)) {
  Write-Output "emergency-override: no hay proyecto activo (.claude/.active-project) - nada que destrabar."
  exit 1
}
$slug = (Get-Content $activeProjectFile -Raw).Trim()
if (-not $slug) {
  Write-Output "emergency-override: .claude/.active-project esta vacio."
  exit 1
}

$dotDir = Join-Path $ProjectDir "bossdream_projects/$slug/.bossdream-project"
if (-not (Test-Path $dotDir)) {
  Write-Output "emergency-override: no existe $dotDir para el proyecto activo '$slug'."
  exit 1
}

$overridesPath = Join-Path $dotDir 'emergency-overrides.json'
if (Test-Path $overridesPath) {
  $overridesRaw = Get-Content $overridesPath -Raw | ConvertFrom-Json
  $overrides = @($overridesRaw)
} else {
  $overrides = @()
}

$newEntry = [PSCustomObject]@{
  quien     = $Quien
  cuando    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  motivo    = $Motivo
  alcance   = $Alcance
  consumido = $false
}
$overrides = @($overrides) + $newEntry
ConvertTo-Json -InputObject $overrides -Depth 6 | Set-Content $overridesPath -Encoding utf8

Write-Output "emergency-override OK: entrada agregada a emergency-overrides.json para '$slug'. Se consume en la proxima invocacion de /bossdream-plan o /bossdream-implement bloqueada por validation-lock.ps1 - el resto del proyecto sigue evaluandose normal."
exit 0
