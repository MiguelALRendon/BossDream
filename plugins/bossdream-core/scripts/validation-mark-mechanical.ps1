param(
  [Parameter(Mandatory=$true)][string]$ProjectSlug,
  [Parameter(Mandatory=$true)][string]$DocPattern,
  [Parameter(Mandatory=$true)][string]$Reason,
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR
)
$ErrorActionPreference = 'Stop'

if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }

$destDir = Join-Path $ProjectDir "bossdream_projects/$ProjectSlug"
$dotDir = Join-Path $destDir '.bossdream-project'
$validationPath = Join-Path $dotDir 'validation.json'

if (-not (Test-Path $validationPath)) {
  Write-Output "validation-mark-mechanical: no existe validation.json para '$ProjectSlug' — nada que marcar."
  exit 1
}

function Get-Fingerprint([string]$Path) {
  return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

$validation = Get-Content $validationPath -Raw | ConvertFrom-Json

$updated = @()
$skippedNotVerified = @()
$notFound = @()

if ($validation.PSObject.Properties.Name -contains 'documents') {
  foreach ($docKey in $validation.documents.PSObject.Properties.Name) {
    if ($docKey -notlike $DocPattern) { continue }

    $docEntry = $validation.documents.$docKey
    if ($docEntry.status -ne 'verified') {
      $skippedNotVerified += $docKey
      continue
    }

    $docPath = Join-Path $destDir $docKey
    if (-not (Test-Path $docPath)) {
      $notFound += $docKey
      continue
    }

    $newFingerprint = Get-Fingerprint $docPath
    if ($newFingerprint -eq $docEntry.documentFingerprint) { continue }

    $docEntry.documentFingerprint = $newFingerprint
    $updated += $docKey
  }
}

if ($updated.Count -gt 0) {
  $validation | ConvertTo-Json -Depth 20 | Set-Content $validationPath -Encoding utf8
}

$logPath = Join-Path $dotDir 'validation-mechanical-overrides.log'
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$logLine = "$timestamp | patron=$DocPattern | razon=$Reason | actualizados=$($updated -join ',') | omitidos=$($skippedNotVerified -join ',') | no-encontrados=$($notFound -join ',')"
Add-Content -Path $logPath -Value $logLine -Encoding utf8

Write-Output "validation-mark-mechanical ($ProjectSlug): actualizados=$($updated.Count) omitidos=$($skippedNotVerified.Count) (no estaban verified) no-encontrados=$($notFound.Count)"
if ($updated.Count -gt 0) { Write-Output "  actualizados: $($updated -join ', ')" }
if ($skippedNotVerified.Count -gt 0) { Write-Output "  omitidos (no verified): $($skippedNotVerified -join ', ')" }
if ($notFound.Count -gt 0) { Write-Output "  no encontrados en disco: $($notFound -join ', ')" }
exit 0
