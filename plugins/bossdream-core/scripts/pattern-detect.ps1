param(
  [Parameter(Mandatory=$true)][string]$LogPath,
  [int]$MinRepeticiones = 3
)
$ErrorActionPreference = 'Stop'

function Get-ParametroNames($Entrada) {
  return @($Entrada.PSObject.Properties.Name | Where-Object { $_ -ne 'script' -and $_ -ne 'resultado' } | Sort-Object)
}

function Get-GrupoKey($Entrada) {
  $parametros = Get-ParametroNames $Entrada
  return "$($Entrada.script)|$($parametros -join ',')|$($Entrada.resultado)"
}

if (-not (Test-Path $LogPath)) {
  ([ordered]@{ status = 'blocked'; razon = @("log no encontrado en '$LogPath'") } | ConvertTo-Json -Compress -Depth 10)
  exit 1
}

$entradas = @(Get-Content -Encoding utf8 $LogPath | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object { $_ | ConvertFrom-Json })
$grupos = [ordered]@{}
for ($i = 0; $i -lt $entradas.Count; $i++) {
  $key = Get-GrupoKey $entradas[$i]
  if (-not $grupos.Contains($key)) { $grupos[$key] = [System.Collections.Generic.List[int]]::new() }
  $grupos[$key].Add($i + 1)
}

$candidatos = [System.Collections.Generic.List[object]]::new()
foreach ($key in $grupos.Keys) {
  if ($grupos[$key].Count -lt $MinRepeticiones) { continue }
  $muestra = $entradas[$grupos[$key][0] - 1]
  $candidatos.Add([ordered]@{
    script       = $muestra.script
    parametros   = Get-ParametroNames $muestra
    resultado    = $muestra.resultado
    repeticiones = $grupos[$key].Count
    lineas       = @($grupos[$key])
  })
}

$result = [ordered]@{
  status = if ($candidatos.Count -gt 0) { 'pass' } else { 'blocked' }
}
if ($candidatos.Count -gt 0) { $result.candidatos = @($candidatos) }
else { $result.razon = @("ningun grupo alcanza $MinRepeticiones repeticiones consistentes (mismo script, mismos nombres de parametro, mismo campo de resultado)") }

($result | ConvertTo-Json -Compress -Depth 10)
if ($result.status -eq 'pass') { exit 0 } else { exit 1 }
