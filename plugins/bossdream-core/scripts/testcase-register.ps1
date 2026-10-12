param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR,
  [Parameter(Mandatory=$true)][string]$ProjectSlug,
  [Parameter(Mandatory=$true)][string]$TcId,
  [Parameter(Mandatory=$true)][string]$UsId,
  [string[]]$AcIds = @()
)
$ErrorActionPreference = 'Stop'

if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
$destDir = Join-Path $ProjectDir "bossdream_projects/$ProjectSlug"
$dotDir = Join-Path $destDir '.bossdream-project'
$tcPath = Join-Path $destDir "tests/cases/$TcId.md"
$tracePath = Join-Path $dotDir 'traceability.json'
$validationPath = Join-Path $dotDir 'validation.json'

if (-not (Test-Path $tcPath)) {
  Write-Output "testcase-register: no existe $TcId.md en tests/cases/ - redactalo primero, luego registra."
  exit 1
}

function Add-TestToUs($node, [string]$UsId, [string]$TcId) {
  if ($null -eq $node) { return $false }
  if ($node -is [PSCustomObject]) {
    foreach ($prop in $node.PSObject.Properties) {
      if ($prop.Name -eq $UsId) {
        $usNode = $prop.Value
        if (-not ($usNode.PSObject.Properties.Name -contains 'tests')) {
          $usNode | Add-Member -NotePropertyName 'tests' -NotePropertyValue @()
        }
        $existing = @($usNode.tests)
        if ($existing -notcontains $TcId) { $usNode.tests = @($existing + $TcId) }
        return $true
      }
      if (Add-TestToUs $prop.Value $UsId $TcId) { return $true }
    }
  }
  return $false
}

# --- 1. Registra el TC bajo su US en traceability.json ---
$trace = if (Test-Path $tracePath) { Get-Content -Encoding utf8 $tracePath -Raw | ConvertFrom-Json } else { [PSCustomObject]@{} }
$found = Add-TestToUs $trace $UsId $TcId
if (-not $found) {
  Write-Output "testcase-register AVISO: no se encontro '$UsId' en traceability.json - el TC se registra en validation.json de todas formas, pero revisa la trazabilidad a mano (o corre /bossdream-update-docs)."
}
$trace | ConvertTo-Json -Depth 10 | Set-Content $tracePath -Encoding utf8

# --- 2. Agrega entrada pending en validation.json y fuerza overallStatus a blocked (decision 2b: solo validation-check.ps1 escribe "ready", este script reabre) ---
$validation = Get-Content -Encoding utf8 $validationPath -Raw | ConvertFrom-Json
$docKey = "tests/cases/$TcId.md"
$newEntry = [PSCustomObject]@{ status = 'pending'; documentFingerprint = ''; checks = @() }
if ($validation.documents.PSObject.Properties.Name -contains $docKey) {
  $validation.documents.$docKey = $newEntry
} else {
  $validation.documents | Add-Member -NotePropertyName $docKey -NotePropertyValue $newEntry
}
$validation.overallStatus = 'blocked'
$validation | ConvertTo-Json -Depth 10 | Set-Content $validationPath -Encoding utf8

# --- 3. Actualiza el contador persistido de TC (bootstrap con rescan si no hay cache, si no, incremental) ---
$cachePath = Join-Path $dotDir 'tc-summary-cache.json'
$casosDir = Join-Path $destDir 'tests/cases'

if (Test-Path $cachePath) {
  $cache = Get-Content -Encoding utf8 $cachePath -Raw | ConvertFrom-Json
  $total = [int]$cache.total + 1
  $pasaron = [int]$cache.pasaron
  $fallaron = [int]$cache.fallaron
  $bloqueados = [int]$cache.bloqueados
  $tcText = [System.IO.File]::ReadAllText($tcPath, [System.Text.Encoding]::UTF8)
  if ($tcText -match '\|\s*\*\*Estado\*\*\s*\|\s*Pas[oó]\s*\|') { $pasaron++ }
  elseif ($tcText -match '\|\s*\*\*Estado\*\*\s*\|\s*Fall[oó]\s*\|') { $fallaron++ }
  elseif ($tcText -match '\|\s*\*\*Estado\*\*\s*\|\s*Bloqueado\s*\|') { $bloqueados++ }
} else {
  $tcFiles = @(Get-ChildItem -Path $casosDir -Filter 'TC-*.md' -File -ErrorAction SilentlyContinue)
  $total = $tcFiles.Count
  $pasaron = 0; $fallaron = 0; $bloqueados = 0
  foreach ($f in $tcFiles) {
    $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    if ($text -match '\|\s*\*\*Estado\*\*\s*\|\s*Pas[oó]\s*\|') { $pasaron++ }
    elseif ($text -match '\|\s*\*\*Estado\*\*\s*\|\s*Fall[oó]\s*\|') { $fallaron++ }
    elseif ($text -match '\|\s*\*\*Estado\*\*\s*\|\s*Bloqueado\s*\|') { $bloqueados++ }
  }
}
@{ total = $total; pasaron = $pasaron; fallaron = $fallaron; bloqueados = $bloqueados } | ConvertTo-Json | Set-Content $cachePath -Encoding utf8

$listoParaUat = if ($total -gt 0 -and $fallaron -eq 0 -and $bloqueados -eq 0) { 'Si' } else { 'No' }

$approachPath = Join-Path $destDir 'tests/test-approach.md'
if (Test-Path $approachPath) {
  $lines = [System.IO.File]::ReadAllLines($approachPath, [System.Text.Encoding]::UTF8)
  $headerIdx = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\|\s*Total de casos\s*\|') { $headerIdx = $i; break }
  }
  if ($headerIdx -ge 0 -and ($headerIdx + 2) -lt $lines.Count) {
    $lines[$headerIdx + 2] = "| $total | $pasaron | $fallaron | $bloqueados | $listoParaUat |"
    [System.IO.File]::WriteAllLines($approachPath, $lines, (New-Object System.Text.UTF8Encoding($false)))
  }
}

# --- 4. Loggea la invocacion (best-effort: el registro del TC ya se completo arriba, esto no debe bloquearlo) ---
try {
  $logPath = Join-Path $dotDir 'operations-log.jsonl'
  $logEntry = [ordered]@{ script = 'testcase-register.ps1'; ProjectSlug = $ProjectSlug; TcId = $TcId; UsId = $UsId; AcIds = @($AcIds); resultado = 'OK' }
  Add-Content -Path $logPath -Value ($logEntry | ConvertTo-Json -Compress) -Encoding utf8
} catch {
  Write-Output "testcase-register AVISO: no se pudo escribir operations-log.jsonl ($($_.Exception.Message)) - el TC ya quedo registrado igual."
}

Write-Output "testcase-register OK: $TcId registrado bajo $UsId. validation.json -> overallStatus=blocked. Resumen: $total casos ($pasaron pasaron, $fallaron fallaron, $bloqueados bloqueados)."
