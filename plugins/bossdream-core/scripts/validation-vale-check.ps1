param(
  [string]$DocumentPath,
  [string[]]$DocumentPaths,
  [string]$DocumentPathsFile,
  [string]$PluginRoot = $env:CLAUDE_PLUGIN_ROOT
)
$ErrorActionPreference = 'Stop'

# Un array PowerShell pasado a un proceso externo (& powershell -File) se trunca al primer elemento — DocumentPathsFile es el puente para invocacion entre procesos (usa validation-check.ps1); DocumentPaths sigue siendo el modo batch in-process (tests standalone).
if ($DocumentPathsFile) {
  $raw = Get-Content -Encoding utf8 -Raw -Path $DocumentPathsFile
  $DocumentPaths = $raw | ConvertFrom-Json
}

if (-not $PluginRoot) { $PluginRoot = Split-Path -Parent $PSScriptRoot }
$script:valeCmd = Get-Command vale -ErrorAction SilentlyContinue
$script:valeConfig = Join-Path $PluginRoot 'templates/vale/.vale.ini'

function Test-OneDocument([string]$Path) {
  if (-not $script:valeCmd) {
    return @{ status = 'skip'; findings = @('vale no esta instalado en PATH - subverificacion de vocabulario omitida, no bloquea (opcional)') }
  }

  $output = & vale --config $script:valeConfig --output=JSON $Path 2>&1
  $raw = $output -join "`n"
  try { $parsed = $raw | ConvertFrom-Json } catch {
    return @{ status = 'skip'; findings = @('vale devolvio un output no parseable, subverificacion omitida') }
  }

  $findings = @()
  foreach ($fileKey in $parsed.PSObject.Properties.Name) {
    foreach ($alert in @($parsed.$fileKey)) {
      $findings += "linea $($alert.Line): $($alert.Message)"
    }
  }

  if ($findings.Count -gt 0) { return @{ status = 'blocked'; findings = $findings } }
  return @{ status = 'pass'; findings = @() }
}

if ($DocumentPaths) {
  $results = @($DocumentPaths | ForEach-Object {
    $r = Test-OneDocument $_
    [PSCustomObject]@{ path = $_; status = $r.status; findings = $r.findings }
  })
  ConvertTo-Json -InputObject $results -Compress -Depth 4
  exit 0
}

if (-not $DocumentPath) { throw 'Se requiere -DocumentPath o -DocumentPaths' }
$result = Test-OneDocument $DocumentPath
(@{ status = $result.status; findings = $result.findings } | ConvertTo-Json -Compress -Depth 4)
exit 0
