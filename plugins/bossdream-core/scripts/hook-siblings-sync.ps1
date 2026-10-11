param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR,
  [ValidateSet('Check', 'Sync')][string]$Mode = 'Check'
)
$ErrorActionPreference = 'Stop'
if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
Import-Module (Join-Path $PSScriptRoot 'plugin-paths.psm1')

function Get-Fingerprint([string]$Path) {
  return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

$pluginScriptsDir = Get-CanonicalPluginScriptsDir $ProjectDir
$localScriptsDir = Join-Path $ProjectDir '.claude/bossdream-hooks'

$pluginFiles = @(Get-ChildItem -Path $pluginScriptsDir -File | Select-Object -ExpandProperty Name)

$discrepancies = @()
foreach ($fileName in $pluginFiles) {
  $pluginPath = Join-Path $pluginScriptsDir $fileName
  $localPath = Join-Path $localScriptsDir $fileName
  if (-not (Test-Path $localPath)) {
    $discrepancies += $fileName
    continue
  }
  if ((Get-Fingerprint $pluginPath) -ne (Get-Fingerprint $localPath)) {
    $discrepancies += $fileName
  }
}

if ($Mode -eq 'Sync') {
  foreach ($fileName in $discrepancies) {
    Copy-Item -Path (Join-Path $pluginScriptsDir $fileName) -Destination (Join-Path $localScriptsDir $fileName) -Force
    Write-Output "hook-siblings-sync: sincronizado '$fileName' (plugin -> local)."
  }
  exit 0
}

if ($discrepancies.Count -gt 0) {
  foreach ($fileName in $discrepancies) {
    if (-not (Test-Path (Join-Path $localScriptsDir $fileName))) {
      Write-Output "hook-siblings-sync: archivo ausente en local: '$fileName'."
    } else {
      Write-Output "hook-siblings-sync: contenido divergente: '$fileName'."
    }
  }
  exit 1
}
Write-Output "hook-siblings-sync: sin discrepancias ($($pluginFiles.Count) archivos del plugin verificados)."
exit 0
