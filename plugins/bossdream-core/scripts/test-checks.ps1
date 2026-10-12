param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR,
  [string]$Diff
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'pipeline-helpers.psm1') -Force -WarningAction SilentlyContinue
if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }

function Get-BossdreamTesting($ProjectDir) {
  $testEnabled = $false
  $testProject = ''
  $bossdreamPath = Join-Path $ProjectDir 'bossdream.json'
  if (Test-Path $bossdreamPath) {
    try {
      $bd = Get-Content -Encoding utf8 $bossdreamPath -Raw | ConvertFrom-Json
      $t = $bd.testing
      if ($t) { $testEnabled = ($t.enabled -eq $true); $testProject = [string]$t.project }
    } catch {}
  }
  return [ordered]@{ enabled = $testEnabled; project = $testProject }
}

function Get-CodeCorrectness($ProjectDir) {
  $pipelineScript = Join-Path $PSScriptRoot 'pipeline.ps1'
  $out = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $pipelineScript -Tier local -ProjectDir $ProjectDir 2>&1
  $code = $LASTEXITCODE
  if ($code -eq 0) { return [ordered]@{ status = 'passed' } }
  $text = ($out | Out-String).Trim()
  $m = [regex]::Match($text, "PIPELINE FAIL en etapa '([^']+)'(.*)", [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if ($m.Success) {
    $text = "etapa '$($m.Groups[1].Value)'$($m.Groups[2].Value)".Trim()
  } else {
    $lines = $text -split "`r?`n"
    if ($lines.Count -gt 10) { $text = ($lines | Select-Object -Last 10) -join "`n" }
    $text = "pipeline.ps1 fallo (exit $code), formato de mensaje no reconocido: $text"
  }
  return New-HardFailure $text
}

function Get-YamlValidationError($Path) {
  $content = Get-Content -Encoding utf8 $Path -Raw
  $yamlModule = Get-Module -ListAvailable -Name powershell-yaml | Select-Object -First 1
  if ($yamlModule) {
    Import-Module powershell-yaml -ErrorAction Stop
    try { ConvertFrom-Yaml $content | Out-Null; return $null } catch { return $_.Exception.Message }
  }
  # ponytail: sin modulo powershell-yaml instalado, solo se detectan tabs (invalidos en YAML); instalar el modulo si se necesita validacion completa de grammar
  if ($content -match "`t") { return 'tabs no permitidos en YAML (indentacion con tab)' }
  return $null
}

function Test-ContractFile($Path) {
  if ($Path -like '*.schema.json') {
    try { Get-Content -Encoding utf8 $Path -Raw | ConvertFrom-Json -ErrorAction Stop | Out-Null; return $null }
    catch { return $_.Exception.Message }
  }
  return Get-YamlValidationError $Path
}

function Get-ContractCorrectness($ProjectDir) {
  $files = Get-ProjectFiles $ProjectDir @('*.openapi.yaml', '*.schema.json')
  if (-not $files -or @($files).Count -eq 0) { return [ordered]@{ status = 'passed' } }
  foreach ($f in @($files)) {
    $err = Test-ContractFile $f.FullName
    if ($err) { return New-HardFailure "$($f.FullName): $err" }
  }
  return [ordered]@{ status = 'passed' }
}

function Find-MutationConfig($TestProjectPath) {
  $candidates = @('stryker.conf.json', 'stryker.config.js', '.stryker.conf.json')
  foreach ($c in $candidates) {
    $p = Join-Path $TestProjectPath $c
    if (Test-Path $p) { return $p }
  }
  return $null
}

function Invoke-MutationRun($TestProjectPath) {
  Push-Location $TestProjectPath
  $sh = if ([Environment]::OSVersion.Platform -eq 'Win32NT') { @('cmd', '/c') } else { @('sh', '-c') }
  $out = & $sh[0] $sh[1] 'npx stryker run' 2>&1
  $code = $LASTEXITCODE
  Pop-Location
  return @{ code = $code; out = $out }
}

function Get-ConsumidoresExternosDetectados($ProjectDir, $DiffPath, $TestProject) {
  if (-not $DiffPath -or -not (Test-Path $DiffPath)) { return , @() }
  $entries = Get-DiffFileEntries $DiffPath
  $tocados = @($entries | ForEach-Object { Get-DiffFilePath $_ } | Where-Object { $_ } | Select-Object -Unique)
  if ($tocados.Count -eq 0) { return , @() }
  $tocadosNombres = @($tocados | ForEach-Object { Split-Path $_ -Leaf } | Select-Object -Unique)
  $tocadosCompletos = @($tocados | ForEach-Object { (Join-Path $ProjectDir $_) })
  $testProjectFull = if ($TestProject) { Join-Path $ProjectDir $TestProject } else { $null }
  $planningDirFull = Join-Path $ProjectDir '.bossdream-project'
  $proyectoArchivos = Get-ProjectFiles $ProjectDir @('*.ps1', '*.ts', '*.js', '*.py', '*.json', '*.yaml', '*.md')
  $candidatos = $proyectoArchivos | Where-Object {
    (-not $testProjectFull -or -not $_.FullName.StartsWith($testProjectFull, [System.StringComparison]::OrdinalIgnoreCase)) -and
    (-not $_.FullName.StartsWith($planningDirFull, [System.StringComparison]::OrdinalIgnoreCase)) -and
    ($tocadosCompletos -notcontains $_.FullName)
  }
  $consumidores = [System.Collections.Generic.List[object]]::new()
  foreach ($c in @($candidatos)) {
    $hallazgo = Select-String -Path $c.FullName -SimpleMatch -Pattern $tocadosNombres -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hallazgo) {
      $consumidores.Add([ordered]@{ archivo = $c.FullName; referencia = $hallazgo.Line.Trim() })
    }
  }
  $otrosPlanes = Get-OtherPlanningArtifacts $ProjectDir $null
  foreach ($otro in $otrosPlanes) {
    $compartidos = Get-ArchivosCompartidos $tocados $otro.archivos_tocados
    if ($compartidos.Count -gt 0) {
      $consumidores.Add([ordered]@{ id_tarea_conflictivo = $otro.id_tarea; archivos_compartidos = $compartidos })
    }
  }
  return , @($consumidores)
}

function Get-RegressionSafety($ProjectDir, $DiffPath) {
  $testing = Get-BossdreamTesting $ProjectDir
  $consumidoresExternos = Get-ConsumidoresExternosDetectados $ProjectDir $DiffPath $testing.project
  if (-not $testing.enabled) { return [ordered]@{ status = 'skipped'; nota = 'testing.enabled=false en bossdream.json'; consumidores_externos_detectados = $consumidoresExternos } }
  if (-not $testing.project) { return [ordered]@{ status = 'skipped'; nota = 'testing.enabled=true pero bossdream.json no define testing.project'; consumidores_externos_detectados = $consumidoresExternos } }
  $testProjectPath = Join-Path $ProjectDir $testing.project
  # ponytail: solo detecta config de Stryker (Node); ampliar cuando exista runner de mutation para otro stack
  $mutationConfig = Find-MutationConfig $testProjectPath
  if (-not $mutationConfig) {
    return [ordered]@{ status = 'skipped'; nota = "no se encontro herramienta de mutation testing para el stack de '$($testing.project)' (ver $($testing.project)/README.md)"; consumidores_externos_detectados = $consumidoresExternos }
  }
  $run = Invoke-MutationRun $testProjectPath
  if ($run.code -eq 0) { return [ordered]@{ status = 'passed'; consumidores_externos_detectados = $consumidoresExternos } }
  $tail = ($run.out | Select-Object -Last 25) -join "`n"
  $failure = New-HardFailure $tail
  $failure.consumidores_externos_detectados = $consumidoresExternos
  return $failure
}

function Get-InventoryFlows($InventoryPath) {
  if (-not (Test-Path $InventoryPath)) { return , @() }
  try { $inventory = Get-Content -Encoding utf8 $InventoryPath -Raw | ConvertFrom-Json } catch { return , @() }
  return , @($inventory.flows)
}

function Get-FlowCorrectness($ProjectDir) {
  $inventoryPath = Join-Path $ProjectDir '.bossdream-project/test-inventory.json'
  $checkScript = Join-Path $PSScriptRoot 'test-inventory-check.ps1'
  $out = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $checkScript -InventoryPath $inventoryPath 2>&1
  $code = $LASTEXITCODE
  $text = ($out | Out-String).Trim()
  try { $check = $text | ConvertFrom-Json } catch { $check = $null }
  if (-not $check) { return New-HardFailure "test-inventory-check.ps1 fallo (exit $code), salida no parseable: $text" }
  if ($check.status -eq 'pass') {
    $result = [ordered]@{ status = 'passed'; transiciones_cubiertas = @($check.transiciones_cubiertas) }
    if ((Get-InventoryFlows $inventoryPath).Count -gt 0) {
      $result.flow_breaker = [ordered]@{
        status      = 'requires-agent'
        agente      = 'bossdream-flow-breaker'
        instruccion = 'Invocar bossdream-flow-breaker con flows[] de este test-inventory.json.'
      }
    }
    return $result
  }
  $failure = New-HardFailure ((@($check.razon)) -join '; ')
  if ($null -ne $check.transiciones_no_cubiertas) { $failure.transiciones_no_cubiertas = @($check.transiciones_no_cubiertas) }
  if ($null -ne $check.metodos_incompletos) { $failure.metodos_incompletos = @($check.metodos_incompletos) }
  return $failure
}

function Test-DependencyBlockage($Sections) {
  $failed = @($Sections) | Where-Object { $_.status -eq 'failed' }
  return $failed.Count -gt 0
}

function Get-QualityApproval($PreviousSections, $FlowCorrectness) {
  if (Test-DependencyBlockage $PreviousSections) {
    return New-HardFailure 'una o mas etapas previas fallaron'
  }
  $approval = [ordered]@{
    status      = 'requires-agent'
    agente      = 'bossdream-qa-planner'
    instruccion = 'Invocar el agente bossdream-qa-planner con .bossdream-project/test-inventory.json, este JSON completo de test-checks.ps1 y, si existen, hallazgos de agents/bossdream-qa-auditor.md - este script no evalua juicio semantico.'
  }
  if ($FlowCorrectness.flow_breaker) { $approval.flow_breaker = $FlowCorrectness.flow_breaker }
  return $approval
}

$codeCorrectness = Get-CodeCorrectness $ProjectDir
$contractCorrectness = Get-ContractCorrectness $ProjectDir
$flowCorrectness = Get-FlowCorrectness $ProjectDir
$regressionSafety = Get-RegressionSafety $ProjectDir $Diff
$qualityApproval = Get-QualityApproval @($codeCorrectness, $contractCorrectness, $flowCorrectness, $regressionSafety) $flowCorrectness

$result = [ordered]@{
  code_correctness     = $codeCorrectness
  contract_correctness = $contractCorrectness
  flow_correctness     = $flowCorrectness
  regression_safety    = $regressionSafety
  quality_approval     = $qualityApproval
}

($result | ConvertTo-Json -Compress -Depth 10)
$exitCode = switch ($qualityApproval.status) {
  'failed'         { 1 }
  'requires-agent' { 2 }
  default          { 0 }
}
exit $exitCode
