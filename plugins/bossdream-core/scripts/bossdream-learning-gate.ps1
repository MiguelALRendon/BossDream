param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR,
  [string]$ProjectSlug,
  [Parameter(Mandatory=$true)][string]$Slug,
  [Parameter(Mandatory=$true)][string]$OperationsLog,
  [int]$MinRepeticiones = 3,
  [string]$ValidacionVeredicto,
  [string]$ValidacionDetalle,
  [string]$AprobacionVeredicto,
  [string]$AprobacionDetalle
)
$ErrorActionPreference = 'Stop'

if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
if (-not $ProjectSlug) {
  $activeProjectFile = Join-Path $ProjectDir '.claude/.active-project'
  if (-not (Test-Path $activeProjectFile)) {
    ([ordered]@{ status = 'blocked'; razon = @('no hay proyecto activo (.claude/.active-project) y no se paso -ProjectSlug') } | ConvertTo-Json -Compress)
    exit 1
  }
  $ProjectSlug = (Get-Content $activeProjectFile -Raw).Trim()
}

$dotDir = Join-Path $ProjectDir "bossdream_projects/$ProjectSlug/.bossdream-project"
$patternDetectScript = Join-Path $PSScriptRoot 'pattern-detect.ps1'

function Get-EvidenceGateVeredicto([string]$LogPath) {
  if (-not (Test-Path $LogPath)) { return @{ veredicto = 'blocked'; detalle = "log de operaciones no encontrado en '$LogPath'" } }
  $lineas = @(Get-Content $LogPath | Where-Object { $_.Trim().Length -gt 0 })
  if ($lineas.Count -eq 0) { return @{ veredicto = 'blocked'; detalle = "log de operaciones vacio en '$LogPath'" } }
  return @{ veredicto = 'pass'; detalle = "$($lineas.Count) corridas registradas en '$LogPath'" }
}

function Get-PatternConsistencyVeredicto([string]$LogPath, [int]$MinReps) {
  $salida = & $patternDetectScript -LogPath $LogPath -MinRepeticiones $MinReps 2>$null
  $veredicto = if ($LASTEXITCODE -eq 0) { 'pass' } else { 'blocked' }
  return @{ veredicto = $veredicto; detalle = [string]$salida }
}

$etapas = [System.Collections.Generic.List[hashtable]]::new()

$evidencia = Get-EvidenceGateVeredicto $OperationsLog
$etapas.Add(@{ etapa = 'evidence_gate'; veredicto = $evidencia.veredicto; detalle = $evidencia.detalle })
$continua = $evidencia.veredicto -eq 'pass'

if ($continua) {
  $consistencia = Get-PatternConsistencyVeredicto $OperationsLog $MinRepeticiones
  $etapas.Add(@{ etapa = 'pattern_consistency_gate'; veredicto = $consistencia.veredicto; detalle = $consistencia.detalle })
  $continua = $consistencia.veredicto -eq 'pass'
}

if ($continua -and $ValidacionVeredicto) {
  $etapas.Add(@{ etapa = 'validacion'; veredicto = $ValidacionVeredicto; detalle = $ValidacionDetalle })
  $continua = $ValidacionVeredicto -eq 'pass'
} else {
  $continua = $false
}

if ($continua -and $AprobacionVeredicto) {
  $etapas.Add(@{ etapa = 'aprobacion'; veredicto = $AprobacionVeredicto; detalle = $AprobacionDetalle })
  $continua = $AprobacionVeredicto -eq 'pass'
} else {
  $continua = $false
}

New-Item -ItemType Directory -Force -Path $dotDir | Out-Null
$logPath = Join-Path $dotDir "pattern-$Slug.log"
$lineas = @($etapas | ForEach-Object { [ordered]@{ etapa = $_.etapa; veredicto = $_.veredicto; detalle = $_.detalle } | ConvertTo-Json -Compress })
Set-Content -Path $logPath -Value $lineas -Encoding utf8

$status = if ($continua) { 'pass' } else { 'blocked' }
$result = [ordered]@{ status = $status; log = $logPath; etapas = @($etapas | ForEach-Object { $_.etapa }) }
if ($status -eq 'blocked') { $result.razon = @("gate detenido en '$($etapas[-1].etapa)' con veredicto '$($etapas[-1].veredicto)'") }

($result | ConvertTo-Json -Compress -Depth 10)
if ($status -eq 'pass') { exit 0 } else { exit 1 }
