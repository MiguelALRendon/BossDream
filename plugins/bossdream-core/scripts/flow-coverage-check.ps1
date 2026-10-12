param(
  [Parameter(Mandatory=$true)][string]$FlowDefinitionPath,
  [Parameter(Mandatory=$true)][string]$CatalogPath
)
$ErrorActionPreference = 'Stop'

$flow = Get-Content -Encoding utf8 $FlowDefinitionPath -Raw | ConvertFrom-Json
$catalog = Get-Content -Encoding utf8 $CatalogPath -Raw | ConvertFrom-Json

# Transiciones esperadas (all-transitions coverage, ISTQB): cada paso->siguiente del flujo lineal,
# mas cualquier transicion de rollback/compensacion declarada explicitamente.
$expected = New-Object System.Collections.Generic.HashSet[string]
$steps = @($flow.steps)
for ($i = 0; $i -lt $steps.Count - 1; $i++) {
  [void]$expected.Add("$($steps[$i])->$($steps[$i + 1])")
}
$rollbackEdges = if ($flow.rollbackEdges) { @($flow.rollbackEdges) } else { @() }
foreach ($edge in $rollbackEdges) {
  [void]$expected.Add("$($edge.from)->$($edge.to)")
}

# Transiciones cubiertas: cualquier par consecutivo dentro del "path" de cada caso del catalogo.
$covered = New-Object System.Collections.Generic.HashSet[string]
$cases = if ($catalog.cases) { @($catalog.cases) } else { @() }
foreach ($case in $cases) {
  $path = if ($case.path) { @($case.path) } else { @() }
  for ($i = 0; $i -lt $path.Count - 1; $i++) {
    [void]$covered.Add("$($path[$i])->$($path[$i + 1])")
  }
}

$missing = @($expected | Where-Object { -not $covered.Contains($_) })

$result = @{
  status = if ($missing.Count -gt 0) { 'blocked' } else { 'pass' }
  expectedCount = $expected.Count
  coveredCount = ($expected.Count - $missing.Count)
  missing = $missing
}
$result | ConvertTo-Json -Compress -Depth 6
exit 0
