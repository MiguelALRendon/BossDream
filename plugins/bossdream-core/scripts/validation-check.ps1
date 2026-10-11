param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR,
  [Parameter(Mandatory=$true)][string]$ProjectSlug,
  [string]$SemanticVerdictsPath
)
$ErrorActionPreference = 'Stop'
$childHost = if ($env:BOSSDREAM_CHILD_HOST) { $env:BOSSDREAM_CHILD_HOST } else { (Get-Process -Id $PID).Path }

$pluginRoot = Split-Path -Parent $PSScriptRoot
if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }

$destDir = Join-Path $ProjectDir "bossdream_projects/$ProjectSlug"
$dotDir = Join-Path $destDir '.bossdream-project'
$validationPath = Join-Path $dotDir 'validation.json'
$projectPath = Join-Path $dotDir 'project.json'

if (-not (Test-Path $validationPath)) { Write-Output "validation-check: no existe validation.json para '$ProjectSlug' — corre /bossdream-project primero."; exit 1 }

$validation = Get-Content $validationPath -Raw | ConvertFrom-Json
$project = if (Test-Path $projectPath) { Get-Content $projectPath -Raw | ConvertFrom-Json } else { $null }
$classification = if ($project) { $project.classification } else { $null }

$semanticVerdicts = $null
if ($SemanticVerdictsPath -and (Test-Path $SemanticVerdictsPath)) {
  $semanticVerdicts = Get-Content $SemanticVerdictsPath -Raw | ConvertFrom-Json
}

function Get-Fingerprint([string]$Path) {
  return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

# Documentos verified se saltan el loop principal - sin esto quedarian con id viejo para siempre.
if ($validation.PSObject.Properties.Name -contains 'documents') {
  foreach ($docKey in $validation.documents.PSObject.Properties.Name) {
    $docEntry = $validation.documents.$docKey
    if ($docEntry.PSObject.Properties.Name -contains 'checks') {
      foreach ($check in $docEntry.checks) {
        if ($check.id -match '^(vale|structure|semantic)$') { $check.id = $check.id.ToUpper() }
      }
    }
  }
}
if ($validation.PSObject.Properties.Name -contains 'projectChecks') {
  $pc = $validation.projectChecks
  if (($pc.PSObject.Properties.Name -contains 'trace') -and -not ($pc.PSObject.Properties.Name -contains 'TRACE')) {
    $pc | Add-Member -NotePropertyName 'TRACE' -NotePropertyValue $pc.trace
    $pc.PSObject.Properties.Remove('trace')
  }
}

# exemptions nunca opcional: persiste [] en validation.json existentes que no lo tengan, igual que la normalizacion de id/TRACE arriba.
if (-not ($validation.PSObject.Properties.Name -contains 'exemptions')) {
  $validation | Add-Member -NotePropertyName 'exemptions' -NotePropertyValue @()
}
$exemptions = @($validation.exemptions)
function Get-ExemptionMotivo([string]$DocKey, [string]$Code) {
  foreach ($ex in $exemptions) {
    if ($ex.file -ne $DocKey) { continue }
    $exCodes = @($ex.codes | ForEach-Object { $_.ToUpper() })
    if ($exCodes -contains $Code) { return $ex.motivo }
  }
  return $null
}

# --- 1. Trace-check a nivel de proyecto (una sola corrida, no por-documento) ---
$traceResult = & $childHost -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validation-trace-check.ps1') -ProjectDir $ProjectDir -ProjectSlug $ProjectSlug 2>&1 | Select-Object -Last 1
$traceParsed = $traceResult | ConvertFrom-Json
if (-not ($validation.PSObject.Properties.Name -contains 'projectChecks')) {
  $validation | Add-Member -NotePropertyName 'projectChecks' -NotePropertyValue ([PSCustomObject]@{})
}
$validation.projectChecks | Add-Member -NotePropertyName 'TRACE' -NotePropertyValue ([PSCustomObject]@{ status = $traceParsed.status; findings = $traceParsed.findings }) -Force

# --- 2. Descubre documentos a evaluar: los 3 fijos + los TC-*.md que existan ---
$fixedDocs = @('requirements.md', 'tests/test-approach.md')
$casosDir = Join-Path $destDir 'tests/cases'
$tcDocs = @()
if (Test-Path $casosDir) {
  $tcDocs = @(Get-ChildItem -Path $casosDir -Filter 'TC-*.md' -File | ForEach-Object { "tests/cases/$($_.Name)" })
}
$allDocs = $fixedDocs + $tcDocs

if (-not ($validation.PSObject.Properties.Name -contains 'documents')) {
  $validation | Add-Member -NotePropertyName 'documents' -NotePropertyValue ([PSCustomObject]@{})
}

# Cascada barato->caro fail-fast (VALE -> STRUCTURE -> SEMANTIC), batcheada por check: 1 subproceso por check, no 1 por documento.
$docStates = @{}
$pendingDocs = @()
foreach ($docKey in $allDocs) {
  $docPath = Join-Path $destDir $docKey
  if (-not (Test-Path $docPath)) { continue }
  $fingerprint = Get-Fingerprint $docPath

  $existingEntry = $null
  if ($validation.documents.PSObject.Properties.Name -contains $docKey) { $existingEntry = $validation.documents.$docKey }

  $unchanged = ($existingEntry -and $existingEntry.documentFingerprint -eq $fingerprint)
  if ($unchanged -and $existingEntry.status -eq 'verified') {
    continue
  }

  $docType = if ($docKey -match '^tests/cases/TC-') { 'TC' } else { $docKey }
  $docStates[$docKey] = [PSCustomObject]@{
    docPath = $docPath
    fingerprint = $fingerprint
    existingEntry = $existingEntry
    docType = $docType
    checks = @()
    finalStatus = 'needs-semantic-review'
    reason = $null
    blockingCode = $null
    valeBlocked = $false
    structBlocked = $false
  }
  $pendingDocs += $docKey
}

$valeToRun = @()
foreach ($docKey in $pendingDocs) {
  $state = $docStates[$docKey]
  $valeExemptMotivo = Get-ExemptionMotivo $docKey 'VALE'
  if ($valeExemptMotivo) {
    $state.checks += @{ id = 'VALE'; status = 'EXEMPT'; findings = @($valeExemptMotivo) }
  }
  else {
    $valeToRun += $docKey
  }
}
if ($valeToRun.Count -gt 0) {
  $valePaths = @($valeToRun | ForEach-Object { $docStates[$_].docPath })
  # Un array PowerShell pasado a un proceso externo se trunca al primer elemento (verificado) — el batch viaja por archivo temporal, no por argumento de linea de comandos.
  $valeBatchFile = [System.IO.Path]::GetTempFileName()
  try {
    ConvertTo-Json -InputObject $valePaths -Compress -Depth 4 | Set-Content $valeBatchFile -Encoding utf8
    $valeOut = & $childHost -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validation-vale-check.ps1') -DocumentPathsFile $valeBatchFile -PluginRoot $pluginRoot 2>&1 | Select-Object -Last 1
  } finally {
    Remove-Item $valeBatchFile -Force -ErrorAction SilentlyContinue
  }
  $valeResults = $valeOut | ConvertFrom-Json
  for ($i = 0; $i -lt $valeToRun.Count; $i++) {
    $state = $docStates[$valeToRun[$i]]
    $r = $valeResults[$i]
    $state.checks += @{ id = 'VALE'; status = $r.status; findings = $r.findings }
    if ($r.status -eq 'blocked') {
      $state.valeBlocked = $true
      $state.reason = ($r.findings -join '; ')
    }
  }
}
foreach ($docKey in $pendingDocs) {
  if ($docStates[$docKey].valeBlocked) {
    $docStates[$docKey].finalStatus = 'blocked'
    $docStates[$docKey].blockingCode = 'VALE'
  }
}

$structCandidates = @($pendingDocs | Where-Object { -not $docStates[$_].valeBlocked })
$structToRun = @()
foreach ($docKey in $structCandidates) {
  $state = $docStates[$docKey]
  $structureExemptMotivo = Get-ExemptionMotivo $docKey 'STRUCTURE'
  if ($structureExemptMotivo) {
    $state.checks += @{ id = 'STRUCTURE'; status = 'EXEMPT'; findings = @($structureExemptMotivo) }
  }
  else {
    $structToRun += $docKey
  }
}
if ($structToRun.Count -gt 0) {
  $structBatchItems = @($structToRun | ForEach-Object {
    $s = $docStates[$_]
    [PSCustomObject]@{ path = $s.docPath; docType = $s.docType; classification = if ($classification) { $classification } else { '' } }
  })
  $structBatchFile = [System.IO.Path]::GetTempFileName()
  try {
    ConvertTo-Json -InputObject $structBatchItems -Compress -Depth 4 | Set-Content $structBatchFile -Encoding utf8
    $structOut = & $childHost -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validation-structure-check.ps1') -BatchInputFile $structBatchFile -PluginRoot $pluginRoot 2>&1 | Select-Object -Last 1
  } finally {
    Remove-Item $structBatchFile -Force -ErrorAction SilentlyContinue
  }
  $structResults = $structOut | ConvertFrom-Json
  for ($i = 0; $i -lt $structToRun.Count; $i++) {
    $state = $docStates[$structToRun[$i]]
    $r = $structResults[$i]
    $state.checks += @{ id = 'STRUCTURE'; status = $r.status; findings = $r.findings }
    if ($r.status -eq 'blocked') {
      $state.structBlocked = $true
      $state.reason = ($r.findings -join '; ')
    }
  }
}
foreach ($docKey in $structCandidates) {
  if ($docStates[$docKey].structBlocked) {
    $docStates[$docKey].finalStatus = 'blocked'
    $docStates[$docKey].blockingCode = 'STRUCTURE'
  }
}

foreach ($docKey in $pendingDocs) {
  $state = $docStates[$docKey]

  if ($state.finalStatus -ne 'blocked') {
    $semanticExemptMotivo = Get-ExemptionMotivo $docKey 'SEMANTIC'
    if ($semanticExemptMotivo) {
      $state.checks += @{ id = 'SEMANTIC'; status = 'EXEMPT'; findings = @($semanticExemptMotivo) }
      $state.finalStatus = 'verified'
    }
    elseif ($semanticVerdicts -and ($semanticVerdicts.PSObject.Properties.Name -contains $docKey)) {
      $verdict = $semanticVerdicts.$docKey
      $state.checks += @{ id = 'SEMANTIC'; status = $verdict.verdict; findings = @($verdict.reason) }
      if ($verdict.verdict -eq 'pass') { $state.finalStatus = 'verified' }
      else { $state.finalStatus = 'blocked'; $state.reason = $verdict.reason; $state.blockingCode = 'SEMANTIC' }
    }
  }

  $existingEntry = $state.existingEntry
  $prevAttempts = if ($existingEntry -and ($existingEntry.PSObject.Properties.Name -contains 'intentosBloqueado')) { $existingEntry.intentosBloqueado } else { 0 }
  $prevBlockedCode = if ($existingEntry -and ($existingEntry.PSObject.Properties.Name -contains 'ultimoCheckBloqueado')) { $existingEntry.ultimoCheckBloqueado } else { $null }
  if ($state.finalStatus -eq 'blocked') {
    $intentosBloqueado = if ($prevBlockedCode -eq $state.blockingCode) { $prevAttempts + 1 } else { 1 }
    $ultimoCheckBloqueado = $state.blockingCode
  }
  else {
    $intentosBloqueado = 0
    $ultimoCheckBloqueado = $null
  }

  $entry = [PSCustomObject]@{
    status = $state.finalStatus
    documentFingerprint = $state.fingerprint
    checks = $state.checks
    intentosBloqueado = $intentosBloqueado
    ultimoCheckBloqueado = $ultimoCheckBloqueado
  }
  if ($state.reason) { $entry | Add-Member -NotePropertyName 'reason' -NotePropertyValue $state.reason }

  if ($validation.documents.PSObject.Properties.Name -contains $docKey) {
    $validation.documents.$docKey = $entry
  } else {
    $validation.documents | Add-Member -NotePropertyName $docKey -NotePropertyValue $entry
  }
}

# --- 3. overallStatus: solo validation-check.ps1 puede escribir "ready" ---
$allVerified = $true
$summary = @()
foreach ($docKey in $allDocs) {
  if (-not ($validation.documents.PSObject.Properties.Name -contains $docKey)) { continue }
  $status = $validation.documents.$docKey.status
  if ($status -ne 'verified') { $allVerified = $false; $summary += "$docKey -> $status" }
}
$traceOk = ($validation.projectChecks.TRACE.status -eq 'pass')
if (-not $traceOk) { $summary += "trace -> $($validation.projectChecks.TRACE.status)" }

$validation.overallStatus = if ($allVerified -and $traceOk) { 'ready' } else { 'blocked' }
$validation | ConvertTo-Json -Depth 10 | Set-Content $validationPath -Encoding utf8

if ($validation.overallStatus -eq 'ready') {
  Write-Output "validation OK ($ProjectSlug): overallStatus=ready"
} else {
  Write-Output "VALIDATION FAIL ($ProjectSlug): $($summary -join ' | ')"
}
exit 0
