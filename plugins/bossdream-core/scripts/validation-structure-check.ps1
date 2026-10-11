param(
  [string]$DocumentPath,
  [string]$DocType,
  [string]$PluginRoot = $env:CLAUDE_PLUGIN_ROOT,
  [string]$Classification,
  [string[]]$DocumentPaths,
  [string[]]$DocTypes,
  [string[]]$Classifications,
  [string]$BatchInputFile
)
$ErrorActionPreference = 'Stop'

# Un array PowerShell pasado a un proceso externo (& powershell -File) se trunca al primer elemento — BatchInputFile es el puente para invocacion entre procesos (usa validation-check.ps1); DocumentPaths/DocTypes/Classifications siguen siendo el modo batch in-process (tests standalone).
if ($BatchInputFile) {
  $batchItems = Get-Content -Raw -Path $BatchInputFile | ConvertFrom-Json
  $DocumentPaths = @($batchItems | ForEach-Object { $_.path })
  $DocTypes = @($batchItems | ForEach-Object { $_.docType })
  $Classifications = @($batchItems | ForEach-Object { $_.classification })
}

if (-not $PluginRoot) { $PluginRoot = Split-Path -Parent $PSScriptRoot }
# Get-Content -Raw sin BOM cae al codepage del sistema en PS 5.1 y rompe el match de acentos — se fuerza UTF8.
$script:rules = [System.IO.File]::ReadAllText((Join-Path $PluginRoot 'templates/validation-rules.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json

function Test-OneDocument([string]$Path, [string]$DocTypeArg, [string]$ClassificationArg) {
  $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
  $findings = @()

  if ($DocTypeArg -eq 'TC') {
    foreach ($field in $script:rules.documentTypes.TC.requiredFields) {
      if ($content -notmatch [regex]::Escape($field)) {
        $findings += "falta el campo '$field' en la tabla del caso de prueba"
      }
    }
    if ($content -match '\[qué se está probando\]') { $findings += "campo Escenario sigue con el placeholder de la plantilla, sin llenar" }
    if ($content -match '\[criterio claro, verificable, sin ambiguedad\]') { $findings += "el TC no referencia un AC concreto, sigue con placeholder" }
  }
  else {
    $docRules = $script:rules.documentTypes.$DocTypeArg
    foreach ($section in $docRules.requiredSections) {
      $escaped = [regex]::Escape($section)
      if ($content -notmatch "##+\s*$escaped") {
        $findings += "falta la seccion '$section'"
      }
    }

    if ($DocTypeArg -eq 'requirements.md' -and $ClassificationArg) {
      $hasEpic = $content -match '##\s*Epic\s*—'
      $hasFeature = $content -match '##\s*Feature\s*—'
      switch ($ClassificationArg) {
        'Complejo' {
          if (-not $hasEpic) { $findings += "clasificacion Complejo pero falta el bloque Epic (decision 5)" }
          if (-not $hasFeature) { $findings += "clasificacion Complejo pero falta el bloque Feature (decision 5)" }
        }
        'Medio' {
          if ($hasEpic) { $findings += "clasificacion Medio no debe tener bloque Epic (decision 5) — falta eliminarlo" }
          if (-not $hasFeature) { $findings += "clasificacion Medio pero falta el bloque Feature (decision 5)" }
        }
        'Simple' {
          if ($hasEpic) { $findings += "clasificacion Simple no debe tener bloque Epic (decision 5) — falta eliminarlo" }
          if ($hasFeature) { $findings += "clasificacion Simple no debe tener bloque Feature (decision 5) — falta eliminarlo" }
        }
      }
    }

    if ($content -match '\[Descripción breve, en palabras del negocio') { $findings += "seccion 'problema/necesidad' sigue con el placeholder de la plantilla" }
    if ($content -match '\[Qué se espera lograr con esta solución') { $findings += "seccion 'objetivo' sigue con el placeholder de la plantilla" }
  }

  if ($findings.Count -gt 0) { return @{ status = 'blocked'; findings = $findings } }
  return @{ status = 'pass'; findings = @() }
}

if ($DocumentPaths) {
  $results = @()
  for ($i = 0; $i -lt $DocumentPaths.Count; $i++) {
    $docTypeArg = $DocTypes[$i]
    $classificationArg = if ($Classifications -and $i -lt $Classifications.Count) { $Classifications[$i] } else { $null }
    $r = Test-OneDocument $DocumentPaths[$i] $docTypeArg $classificationArg
    $results += [PSCustomObject]@{ path = $DocumentPaths[$i]; status = $r.status; findings = $r.findings }
  }
  ConvertTo-Json -InputObject $results -Compress -Depth 4
  exit 0
}

if (-not $DocumentPath -or -not $DocType) { throw 'Se requiere -DocumentPath/-DocType o -DocumentPaths/-DocTypes' }
$result = Test-OneDocument $DocumentPath $DocType $Classification
(@{ status = $result.status; findings = $result.findings } | ConvertTo-Json -Compress -Depth 4)
exit 0
