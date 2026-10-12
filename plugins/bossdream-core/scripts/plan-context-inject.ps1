$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'prompt-matchers.psm1')
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }

$proj = [string]$j.cwd
if (-not $proj) { $proj = $env:CLAUDE_PROJECT_DIR }
if (-not $proj) { exit 0 }
Import-Module (Join-Path $PSScriptRoot 'plugin-paths.psm1')
$proj = Get-ProjectRoot $proj

$prompt = [string]$j.prompt
if (-not (Test-BossdreamPlanPrompt $prompt)) { exit 0 }

$activeProjectFile = Join-Path $proj '.claude/.active-project'
if (-not (Test-Path $activeProjectFile)) { exit 0 }
$slug = (Get-Content -Encoding utf8 $activeProjectFile -Raw).Trim()
if (-not $slug) { exit 0 }

$destDir = Join-Path $proj "bossdream_projects/$slug"
$dotDir = Join-Path $destDir '.bossdream-project'
$validationPath = Join-Path $dotDir 'validation.json'
if (-not (Test-Path $validationPath)) { exit 0 }
try { $validation = Get-Content -Encoding utf8 $validationPath -Raw | ConvertFrom-Json } catch { exit 0 }

if ($validation.overallStatus -ne 'ready') { exit 0 }

$tracePath = Join-Path $dotDir 'traceability.json'
$trace = if (Test-Path $tracePath) { Get-Content -Encoding utf8 $tracePath -Raw | ConvertFrom-Json } else { [PSCustomObject]@{} }

$epicCount = 0
$featureCount = 0
if ($trace.PSObject.Properties.Name -contains 'epics') {
  $epicNames = @($trace.epics.PSObject.Properties.Name)
  $epicCount = $epicNames.Count
  foreach ($epicName in $epicNames) {
    $epicNode = $trace.epics.$epicName
    if ($epicNode.PSObject.Properties.Name -contains 'features') {
      $featureCount += @($epicNode.features.PSObject.Properties.Name).Count
    }
  }
}
if ($trace.PSObject.Properties.Name -contains 'features') {
  $featureCount += @($trace.features.PSObject.Properties.Name).Count
}

$sizeHint = if ($epicCount -gt 1) { 'monstruo (una sesion por Epic)' }
  elseif ($epicCount -eq 1 -or $featureCount -gt 1) { 'grande (una corrida por Feature)' }
  else { 'pequeno (una sola corrida)' }

$progressPath = Join-Path $dotDir 'plan-progress.json'
$progress = if (Test-Path $progressPath) { Get-Content -Encoding utf8 $progressPath -Raw | ConvertFrom-Json } else { [PSCustomObject]@{ status = 'not-started'; planned = @(); pending = @() } }
$plannedList = ($progress.planned -join ', ')
$pendingList = ($progress.pending -join ', ')

$ctx = "[gobernanza-sdlc] Proyecto activo '$slug', validation.json en ready - toma la documentacion de bossdream_projects/$slug/{requirements.md,tests/test-approach.md} como research-log precargado en vez de partir de una historia suelta. " +
  "Conteo detectado: $epicCount Epic(s), $featureCount Feature(s) -> tamano sugerido: $sizeHint. " +
  "Progreso previo (plan-progress.json): planned=[$plannedList] pending=[$pendingList]. " +
  "Al cerrar cada corrida sobre una Feature/Epic, invoca `${CLAUDE_PLUGIN_ROOT}/scripts/plan-progress-update.ps1 -ProjectSlug $slug -Completed <id>` para mover esa entrada de pending a planned. " +
  "Agrega siempre el QA Increment como ultima Feature del rollup bossdream_projects/$slug/roadmap.md antes de cerrar (plantilla en `${CLAUDE_PLUGIN_ROOT}/templates/_PROJECT_TEMPLATE/roadmap.md`). " +
  "roadmap.md es solo indice/rollup, nunca ejecutable - cada Feature sigue generando su propio plans/<feature>/plan.md exactamente igual que siempre."

(@{ hookSpecificOutput = @{ hookEventName = 'UserPromptSubmit'; additionalContext = $ctx } } | ConvertTo-Json -Compress -Depth 5)
exit 0
