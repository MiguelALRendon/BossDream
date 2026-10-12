param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR,
  [Parameter(Mandatory=$true)][string]$IdTarea
)
$ErrorActionPreference = 'Stop'

if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
$planningDir = Join-Path $ProjectDir '.bossdream-project/artifacts/planning'
$artifactPath = Join-Path $planningDir "$IdTarea.artifact.json"

if (-not (Test-Path $artifactPath)) {
  exit 0
}

$artifact = Get-Content -Encoding utf8 $artifactPath -Raw | ConvertFrom-Json
if ($artifact.PSObject.Properties.Name -contains 'estado') {
  $artifact.estado = 'consumido'
} else {
  $artifact | Add-Member -NotePropertyName 'estado' -NotePropertyValue 'consumido'
}

$consumidosDir = Join-Path $planningDir 'consumidos'
if (-not (Test-Path $consumidosDir)) { New-Item -ItemType Directory -Path $consumidosDir -Force | Out-Null }

$artifact | ConvertTo-Json -Depth 10 | Set-Content $artifactPath -Encoding utf8
Move-Item -Path $artifactPath -Destination (Join-Path $consumidosDir "$IdTarea.artifact.json") -Force

Write-Output "plan-artifact-consume OK: '$IdTarea' marcado consumido y movido a artifacts/planning/consumidos/."
exit 0
