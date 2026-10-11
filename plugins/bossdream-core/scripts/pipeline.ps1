param(
  [string]$Tier = 'local',
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR
)
$ErrorActionPreference = 'Stop'
if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
$cfgPath = Join-Path $ProjectDir 'pipeline.json'
if (-not (Test-Path $cfgPath)) { Write-Output 'pipeline: sin pipeline.json en el proyecto, nada que correr'; exit 0 }
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json

$testEnabled = $false
$testBdd = $false
$testProject = ''
$styleEnabled = $false
$bossdreamPath = Join-Path $ProjectDir 'bossdream.json'
if (Test-Path $bossdreamPath) {
  try {
    $bd = Get-Content $bossdreamPath -Raw | ConvertFrom-Json
    $t = $bd.testing; if ($t) { $testEnabled = ($t.enabled -eq $true); $testBdd = ($t.bdd -eq $true); $testProject = [string]$t.project }
    if ($bd.style) { $styleEnabled = ($bd.style.enabled -eq $true) }
  } catch {}
}

$tiers = switch ($Tier) {
  'all' { @('local', 'ci', 'nightly') }
  'ci' { @('local', 'ci') }
  default { @($Tier) }
}
$stages = $cfg.stages | Where-Object { $tiers -contains $_.tier -and $_.enabled -ne $false } | Sort-Object order
$ran = 0
foreach ($s in $stages) {
  if ($s.requiresTesting -eq $true) {
    if (-not $testEnabled) { continue }
    if (-not $testProject) {
      Write-Output "PIPELINE FAIL en etapa '$($s.id)': testing.enabled=true pero bossdream.json no define testing.project. Configura el proyecto de pruebas o apaga el switch."
      exit 1
    }
  }
  if ($s.requiresBdd -eq $true) {
    if (-not $testBdd) { continue }
    if (-not $testProject) {
      Write-Output "PIPELINE FAIL en etapa '$($s.id)': testing.bdd=true pero bossdream.json no define testing.project."
      exit 1
    }
  }
  if ($s.requiresStyle -eq $true) {
    if (-not $styleEnabled) { continue }
  }
  $ran++
  if ($s.internal) {
    $stageArgs = if ($s.args) { @($s.args) } else { @() }
    $out = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot ("$($s.internal).ps1")) -ProjectDir $ProjectDir @stageArgs 2>&1
    $code = $LASTEXITCODE
  }
  else {
    $cmd = $s.cmd -replace '\$\{testProject\}', $testProject
    Push-Location $ProjectDir
    $sh = if ([Environment]::OSVersion.Platform -eq 'Win32NT') { @('cmd', '/c') } else { @('sh', '-c') }
    $out = & $sh[0] $sh[1] $cmd 2>&1
    $code = $LASTEXITCODE
    Pop-Location
  }
  if ($code -ne 0) {
    $tail = ($out | Select-Object -Last 25) -join "`n"
    if ($s.blocking -eq 'soft') { Write-Output "pipeline aviso en '$($s.id)' (informativo)"; continue }
    Write-Output "PIPELINE FAIL en etapa '$($s.id)' (orden $($s.order)):`n$tail"
    exit 1
  }
}
Write-Output "pipeline OK ($ran etapas, tier=$Tier)"
exit 0
