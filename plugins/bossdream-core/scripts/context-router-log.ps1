param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR,
  [Parameter(Mandatory=$true)][string]$Pregunta,
  [Parameter(Mandatory=$true)][ValidateSet('artefacto','resumen','repo-map','simbolo','rango','archivo_completo')][string]$NivelAlcanzado,
  [Parameter(Mandatory=$true)][string]$TareaAsociada,
  [long]$RotateThresholdBytes = 5MB
)
$ErrorActionPreference = 'Stop'

if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
if ([string]::IsNullOrWhiteSpace($Pregunta)) { Write-Output 'context-router-log: -Pregunta vacia'; exit 1 }
if ([string]::IsNullOrWhiteSpace($TareaAsociada)) { Write-Output 'context-router-log: -TareaAsociada vacia (toda entrada del log debe atarse a una tarea)'; exit 1 }

$motivoEscaladaArchivoCompleto = 'ninguna fuente previa alcanzó, se escala a archivo completo'
$motivoEscalada = if ($NivelAlcanzado -eq 'archivo_completo') { $motivoEscaladaArchivoCompleto } else { $null }

$dotDir = Join-Path $ProjectDir '.bossdream-project'
if (-not (Test-Path $dotDir)) { New-Item -ItemType Directory -Path $dotDir -Force | Out-Null }
$logPath = Join-Path $dotDir 'context-router.log'

$entry = [ordered]@{
  pregunta        = $Pregunta
  nivel_alcanzado = $NivelAlcanzado
  motivo_escalada = $motivoEscalada
  tarea_asociada  = $TareaAsociada
}
if ((Test-Path $logPath) -and (Get-Item $logPath).Length -gt $RotateThresholdBytes) {
  Move-Item -Path $logPath -Destination "$logPath.old" -Force
}

$line = $entry | ConvertTo-Json -Compress
$noBomUtf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::AppendAllText($logPath, $line + [Environment]::NewLine, $noBomUtf8)

Write-Output "context-router-log OK: nivel_alcanzado=$NivelAlcanzado registrado en .bossdream-project/context-router.log"
exit 0
