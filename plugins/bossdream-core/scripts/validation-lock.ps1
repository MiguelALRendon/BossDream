$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'prompt-matchers.psm1')
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }

$proj = $j.cwd
if (-not $proj) { $proj = $env:CLAUDE_PROJECT_DIR }
if (-not $proj) { exit 0 }
Import-Module (Join-Path $PSScriptRoot 'plugin-paths.psm1')
$proj = Get-ProjectRoot $proj

$prompt = [string]$j.prompt
$matchesPlan = Test-BossdreamPlanPrompt $prompt
$matchesImplement = Test-BossdreamImplementPrompt $prompt
if (-not $matchesPlan -and -not $matchesImplement) { exit 0 }

$activeProjectFile = Join-Path $proj '.claude/.active-project'
if (-not (Test-Path $activeProjectFile)) { exit 0 }
$slug = (Get-Content -Encoding utf8 $activeProjectFile -Raw).Trim()
if (-not $slug) { exit 0 }

$validationPath = Join-Path $proj "bossdream_projects/$slug/.bossdream-project/validation.json"
if (-not (Test-Path $validationPath)) { exit 0 }

try { $validation = Get-Content -Encoding utf8 $validationPath -Raw | ConvertFrom-Json } catch { exit 0 }
if ($validation.overallStatus -ne 'blocked') { exit 0 }

$overridesPath = Join-Path $proj "bossdream_projects/$slug/.bossdream-project/emergency-overrides.json"
if (Test-Path $overridesPath) {
  try {
    $overridesRaw = Get-Content -Encoding utf8 $overridesPath -Raw | ConvertFrom-Json
    $overrides = @($overridesRaw)
  } catch { $overrides = @() }
  $pendingOverride = $null
  foreach ($entry in $overrides) {
    if ($entry.consumido -eq $false) { $pendingOverride = $entry; break }
  }
  if ($pendingOverride) {
    $pendingOverride.consumido = $true
    ConvertTo-Json -InputObject $overrides -Depth 6 | Set-Content $overridesPath -Encoding utf8
    exit 0
  }
}

$pending = @()
$stuckNotes = @()
$stuckThreshold = 3
$rulesPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'templates/validation-rules.json'
if (Test-Path $rulesPath) {
  try {
    $rules = Get-Content -Encoding utf8 $rulesPath -Raw | ConvertFrom-Json
    if ($rules.PSObject.Properties.Name -contains 'stuckThreshold') { $stuckThreshold = $rules.stuckThreshold }
  } catch { }
}
if ($validation.documents) {
  foreach ($docName in $validation.documents.PSObject.Properties.Name) {
    $docEntry = $validation.documents.$docName
    if ($docEntry.status -ne 'verified') { $pending += "$docName ($($docEntry.status))" }
    if (($docEntry.PSObject.Properties.Name -contains 'intentosBloqueado') -and $docEntry.intentosBloqueado -ge $stuckThreshold) {
      $stuckNotes += "Nota: '$docName' lleva $($docEntry.intentosBloqueado) intentos bloqueado en $($docEntry.ultimoCheckBloqueado) - considera invocar la skill validation-exemption-advisor."
    }
  }
}
$reason = "Validation bloqueado para el proyecto activo '$slug'. Documentos pendientes:`n" + ($pending -join "`n") + "`nCorre /bossdream-validate antes de continuar."
if ($stuckNotes.Count -gt 0) { $reason += "`n" + ($stuckNotes -join "`n") }
(@{ decision = 'block'; reason = $reason } | ConvertTo-Json -Compress -Depth 6)
exit 0
