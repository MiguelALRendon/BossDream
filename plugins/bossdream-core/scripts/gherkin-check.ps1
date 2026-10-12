param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'pipeline-helpers.psm1') -Force -WarningAction SilentlyContinue
if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }

# revisa los .feature del repo (excluye la plantilla _TEMPLATE)
$featureFiles = Get-ProjectFiles $ProjectDir '*.feature'
$features = $featureFiles | Where-Object { $_.FullName -notmatch '_TEMPLATE' }
if (-not $features) { Write-Output 'gherkin-check: sin archivos .feature, nada que revisar'; exit 0 }

$problems = @()
foreach ($f in $features) {
  $text = Get-Content -Encoding utf8 $f.FullName -Raw
  $rel = $f.FullName.Substring($ProjectDir.Length).TrimStart('\', '/')
  $happy = ([regex]::Matches($text, '(?im)^\s*@[^\r\n]*\bhappy\b')).Count
  $scenarios = ([regex]::Matches($text, '(?im)^\s*(Scenario|Escenario)\b')).Count
  $cubre = ([regex]::Matches($text, '(?i)@cubre')).Count
  $steps = ([regex]::Matches($text, '(?im)^\s*(Given|When|Then|And|Dado|Cuando|Entonces|Y)\b')).Count
  if ($happy -ne 1) { $problems += "$rel : debe tener exactamente 1 escenario @happy (tiene $happy)" }
  if ($scenarios -gt 0 -and $cubre -lt $scenarios) { $problems += "$rel : $scenarios escenarios pero solo $cubre con @cubre" }
  if ($scenarios -gt 0 -and $steps -eq 0) { $problems += "$rel : escenarios sin pasos Dado/Cuando/Entonces" }
}

if ($problems.Count -gt 0) {
  Write-Output ("GHERKIN-CHECK FAIL:`n" + ($problems -join "`n"))
  exit 1
}
Write-Output "gherkin-check OK ($($features.Count) .feature)"
exit 0
