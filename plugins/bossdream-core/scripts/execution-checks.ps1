param(
  [string]$Plan,
  [string]$Diff,
  [Parameter(Mandatory=$true)]
  [ValidateSet('diff-intelligence','plan-to-code-traceability','unintended-change-detector','correctness-chain')]
  [string]$Check,
  [ValidateSet('local','global')]
  [string]$Scope = 'local',
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'pipeline-helpers.psm1') -Force -WarningAction SilentlyContinue

function New-BlockedResult($Reason) {
  ([ordered]@{ status = 'blocked'; razon = @($Reason) } | ConvertTo-Json -Compress -Depth 10)
  exit 1
}

function Get-DiffIntelligence($DiffPath) {
  $entries = Get-DiffFileEntries $DiffPath
  $agregado = @()
  $modificado = @()
  $eliminado = @()
  foreach ($e in $entries) {
    $path = Get-DiffFilePath $e
    if ($e.added -gt 0 -and $e.removed -eq 0) { $agregado += $path }
    elseif ($e.removed -gt 0 -and $e.added -eq 0) { $eliminado += $path }
    elseif ($e.added -gt 0 -and $e.removed -gt 0) { $modificado += $path }
  }
  # ponytail: comportamiento_cambiado exige entender el codigo, no el diff crudo - queda vacio hasta que exista ese analisis
  return [ordered]@{ agregado = $agregado; modificado = $modificado; eliminado = $eliminado; comportamiento_cambiado = '' }
}

function Get-AllDiffPaths($Intelligence) {
  return , @($Intelligence.agregado + $Intelligence.modificado + $Intelligence.eliminado)
}

function Find-MatchingPaso($Pasos, $FilePath) {
  foreach ($paso in $Pasos) {
    if ($paso.action -like "*$FilePath*") { return $paso }
    if ($paso.expected_output -like "*$FilePath*") { return $paso }
  }
  return $null
}

function Get-PlanToCodeTraceability($Plan, $DiffPath) {
  $intelligence = Get-DiffIntelligence $DiffPath
  $paths = Get-AllDiffPaths $intelligence
  $pasos = @($Plan.pasos)
  $testField = if (Test-FieldFilled $Plan.tests) { (@($Plan.tests) -join ', ') } else { '' }
  $rows = @()
  foreach ($path in $paths) {
    $match = Find-MatchingPaso $pasos $path
    $rows += [ordered]@{
      requirement = ''
      ac          = ''
      plan_step   = if ($match) { [string]$match.action } else { '' }
      code_change = $path
      test        = $testField
      qa_evidence = if ($match) { [string]$match.evidence } else { '' }
    }
  }
  $result = [ordered]@{ trazabilidad = $rows }
  if ($rows.Count -gt 0) {
    $result.traceability_watcher = [ordered]@{
      status      = 'requires-agent'
      agente      = 'bossdream-traceability-watcher'
      instruccion = 'Invocar bossdream-traceability-watcher con esta tabla de trazabilidad - este script no evalua eslabones rotos no sistemicos.'
    }
  }
  return $result
}

function Get-PisadaEntrePlanes($Plan, $Paths, $Scope, $ProjectDir) {
  if ($Scope -ne 'global') { return , @() }
  $otros = Get-OtherPlanningArtifacts $ProjectDir $Plan.id_tarea
  $pisadas = [System.Collections.Generic.List[object]]::new()
  foreach ($otro in $otros) {
    $compartidos = Get-ArchivosCompartidos $Paths $otro.archivos_tocados
    if ($compartidos.Count -gt 0) {
      $pisadas.Add([ordered]@{ id_tarea_conflictivo = $otro.id_tarea; archivos_compartidos = $compartidos })
    }
  }
  return , @($pisadas)
}

function Get-UnintendedChangeDetector($Plan, $DiffPath, $Scope, $ProjectDir) {
  $intelligence = Get-DiffIntelligence $DiffPath
  $paths = Get-AllDiffPaths $intelligence
  $planFiles = @(@($Plan.archivos_primarios) + @($Plan.archivos_tocados) | Where-Object { $_ } | Select-Object -Unique)
  $fueraDeAlcance = @($paths | Where-Object { $planFiles -notcontains $_ })
  # ponytail: modificaciones_accidentales/complejidad_innecesaria exigen diff linea-por-linea contra cada paso y leer el codigo, no solo listar archivos - quedan vacios, fuera de alcance de un dispatcher determinista
  $result = [ordered]@{
    fuera_de_alcance            = $fueraDeAlcance
    modificaciones_accidentales = @()
    complejidad_innecesaria     = @()
    pisada_entre_planes         = Get-PisadaEntrePlanes $Plan $paths $Scope $ProjectDir
  }
  if ($fueraDeAlcance.Count -eq 0) {
    $result.scope_enforcer = [ordered]@{
      status      = 'requires-agent'
      agente      = 'bossdream-scope-enforcer'
      instruccion = 'Invocar bossdream-scope-enforcer con este plan-draft.json y este implementation.diff - este script no evalua renames/case-sensitivity/normalizacion de ruta.'
    }
  }
  return $result
}

function Get-CorrectnessChain($ProjectDir) {
  if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
  $testPipelineScript = Join-Path $PSScriptRoot 'test-checks.ps1'
  $out = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $testPipelineScript -ProjectDir $ProjectDir
  return @{ text = $out; code = $LASTEXITCODE }
}

if ($Check -eq 'correctness-chain') {
  $chain = Get-CorrectnessChain $ProjectDir
  $chain.text
  exit $chain.code
}

if (-not $Diff -or -not (Test-Path $Diff)) { New-BlockedResult "implementation.diff no encontrado en '$Diff'" }

if ($Check -eq 'diff-intelligence') {
  $result = Get-DiffIntelligence $Diff
  ($result | ConvertTo-Json -Compress -Depth 10)
  exit 0
}

if (-not $Plan -or -not (Test-Path $Plan)) { New-BlockedResult "plan-draft.json no encontrado en '$Plan'" }
$planObj = Get-Content $Plan -Raw | ConvertFrom-Json

if ($Check -eq 'plan-to-code-traceability') {
  $result = Get-PlanToCodeTraceability $planObj $Diff
  ($result | ConvertTo-Json -Compress -Depth 10)
  $exitCode = if ($result.traceability_watcher) { 2 } else { 0 }
  exit $exitCode
}

if ($Check -eq 'unintended-change-detector') {
  $result = Get-UnintendedChangeDetector $planObj $Diff $Scope $ProjectDir
  ($result | ConvertTo-Json -Compress -Depth 10)
  $exitCode = 0
  if (@($result.fuera_de_alcance).Count -gt 0) { $exitCode = 1 }
  elseif ($result.scope_enforcer) { $exitCode = 2 }
  exit $exitCode
}
