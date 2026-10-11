param(
  [Parameter(Mandatory=$true)][string]$InventoryPath
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'pipeline-helpers.psm1') -Force -WarningAction SilentlyContinue

$script:RequiredKeys = @('behavior', 'rules', 'flows', 'happy_paths', 'negative_paths', 'boundaries', 'dependencies', 'tests', 'evidence')
$script:FlowSubKeys = @('estados', 'transiciones_validas', 'transiciones_invalidas', 'dead_ends', 'retries', 'rollbacks')
$script:GenericEvidence = @('', 'todo', 'tbd', 'n/a', 'pendiente', 'pending', 'tests pasan')

function Get-PropertyNames($Obj) {
  if (-not $Obj) { return @() }
  return @($Obj.PSObject.Properties.Name)
}

function Test-RequiredKeys($Inventory) {
  $present = Get-PropertyNames $Inventory
  return , [string[]]@($script:RequiredKeys | Where-Object { $present -notcontains $_ } | ForEach-Object { "campo requerido ausente: $_" })
}

function Test-FlowStructure($Flows) {
  $missing = [System.Collections.Generic.List[string]]::new()
  $flowArray = @($Flows)
  for ($i = 0; $i -lt $flowArray.Count; $i++) {
    $present = Get-PropertyNames $flowArray[$i]
    foreach ($key in $script:FlowSubKeys) {
      if ($present -notcontains $key) { $missing.Add("flows[$i].$key ausente") }
    }
  }
  return , $missing
}

function Get-CoveredSet($Tests) {
  $set = New-Object System.Collections.Generic.HashSet[string]
  foreach ($t in @($Tests)) {
    if (Test-FieldFilled $t.cubre) { [void]$set.Add(([string]$t.cubre).Trim().ToLowerInvariant()) }
  }
  return , $set
}

function Test-BehaviorCoverage($Inventory) {
  if ((Test-FieldFilled $Inventory.behavior) -and @($Inventory.tests).Count -eq 0) {
    return , [string[]]@("Missing behavior coverage: $($Inventory.behavior)")
  }
  return , [string[]]@()
}

function Test-RulesCoverage($Inventory, $Covered) {
  $missing = [System.Collections.Generic.List[string]]::new()
  foreach ($rule in @($Inventory.rules)) {
    if (-not (Test-FieldFilled $rule)) { continue }
    if (-not $Covered.Contains(([string]$rule).Trim().ToLowerInvariant())) {
      $missing.Add("Missing validation coverage: $rule")
    }
  }
  return , $missing
}

function Test-TransitionsCoverage($Inventory, $Covered) {
  $missing = [System.Collections.Generic.List[string]]::new()
  foreach ($flow in @($Inventory.flows)) {
    foreach ($trans in @($flow.transiciones_validas)) {
      if (-not (Test-FieldFilled $trans)) { continue }
      if (-not $Covered.Contains(([string]$trans).Trim().ToLowerInvariant())) {
        $missing.Add("Missing flow transition: $trans")
      }
    }
  }
  return , $missing
}

function Test-EvidenceField($Inventory) {
  $ev = [string]$Inventory.evidence
  $norm = if ($ev) { $ev.Trim().ToLowerInvariant() } else { '' }
  if ($script:GenericEvidence -contains $norm) {
    return , [string[]]@("Evidence insufficient: campo evidence vacio o placeholder generico ('$ev')")
  }
  return , [string[]]@()
}

function Split-Transition($Text) {
  $parts = ([string]$Text) -split '->', 2
  if ($parts.Count -eq 2) { return [ordered]@{ de = $parts[0]; a = $parts[1] } }
  return [ordered]@{ de = $Text; a = '' }
}

function Get-CoverageMatrix($Inventory, $Covered) {
  $out = [System.Collections.Generic.List[object]]::new()
  foreach ($flow in @($Inventory.flows)) {
    foreach ($trans in @($flow.transiciones_validas)) {
      if (-not (Test-FieldFilled $trans)) { continue }
      $edge = Split-Transition $trans
      $cubierta = $Covered.Contains(([string]$trans).Trim().ToLowerInvariant())
      $out.Add([ordered]@{ de = $edge.de; a = $edge.a; cubierta = $cubierta })
    }
  }
  return , @($out)
}

function Get-MetodosIncompletos($Inventory, $Covered) {
  $out = [System.Collections.Generic.List[object]]::new()
  foreach ($t in @($Inventory.tests)) {
    if (-not (Test-FieldFilled $t.metodo) -or -not (Test-FieldFilled $t.transicion_relacionada)) { continue }
    $trans = ([string]$t.transicion_relacionada).Trim()
    if ($Covered.Contains($trans.ToLowerInvariant())) { continue }
    $edge = Split-Transition $trans
    $out.Add([ordered]@{ metodo = $t.metodo; mensaje = "tiene prueba unitaria verde, pero el flujo end-to-end $($edge.de)$([char]0x2192)$($edge.a) no est$([char]0xE1) cubierto" })
  }
  return , @($out)
}

if (-not (Test-Path $InventoryPath)) {
  ([ordered]@{ status = 'blocked'; razon = @("test-inventory.json no encontrado en '$InventoryPath'") } | ConvertTo-Json -Compress -Depth 10)
  exit 1
}

$inventory = Get-Content $InventoryPath -Raw | ConvertFrom-Json

$missing = [System.Collections.Generic.List[string]]::new()
$missing.AddRange((Test-RequiredKeys $inventory))
$missing.AddRange((Test-FlowStructure $inventory.flows))

$covered = Get-CoveredSet $inventory.tests
$missing.AddRange((Test-BehaviorCoverage $inventory))
$missing.AddRange((Test-RulesCoverage $inventory $covered))
$missing.AddRange((Test-TransitionsCoverage $inventory $covered))
$missing.AddRange((Test-EvidenceField $inventory))

$coverage = Get-CoverageMatrix $inventory $covered
$cubiertas = @($coverage | Where-Object { $_.cubierta } | ForEach-Object { "$($_.de)->$($_.a)" })
$noCubiertas = @($coverage | Where-Object { -not $_.cubierta } | ForEach-Object { "$($_.de)->$($_.a)" })

$result = [ordered]@{
  status                    = if ($missing.Count -eq 0) { 'pass' } else { 'blocked' }
  transiciones              = $coverage
  transiciones_cubiertas    = $cubiertas
  transiciones_no_cubiertas = $noCubiertas
  metodos_incompletos       = Get-MetodosIncompletos $inventory $covered
}
if ($missing.Count -gt 0) { $result.razon = @($missing) }

($result | ConvertTo-Json -Compress -Depth 10)
if ($result.status -eq 'pass') { exit 0 } else { exit 1 }
