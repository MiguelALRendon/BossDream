param(
  [Parameter(Mandatory=$true)][string]$PlanPath,
  [ValidateSet('evidence','change-surface','existing-solution','alternative-pressure','blast-radius','testability','minimality','executability','intent-integrity','contradiction')]
  [string]$Gate,
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'pipeline-helpers.psm1') -Force -WarningAction SilentlyContinue

$script:SemanticGateConfig = @{ gates = @('intent-integrity', 'contradiction'); agent = 'bossdream-planner-auditor' }

function Get-EvidenceEntries($Plan) {
  if (Test-FieldFilled $Plan.evidencia) { return , @($Plan.evidencia) }
  $entries = @()
  foreach ($d in @($Plan.decisiones)) {
    if ($d.evidencia) { $entries += @($d.evidencia) }
  }
  return , $entries
}

function Test-GateEvidence($Plan) {
  $entries = Get-EvidenceEntries $Plan
  $missing = [System.Collections.Generic.List[string]]::new()
  if ($entries.Count -eq 0) { $missing.Add('no hay entradas de evidencia (decisiones[].evidencia[] o evidencia[])') }
  $required = @('claim', 'source', 'confidence', 'impact')
  $evidenceOut = @()
  foreach ($e in $entries) {
    $evidenceOut += [PSCustomObject][ordered]@{ claim = $e.claim; source = $e.source; confidence = $e.confidence; impact = $e.impact }
  }
  $missing.AddRange((Validate-ItemFields $entries $required 'evidencia'))
  $supuestos = @($Plan.supuestos | Where-Object { $_ })
  if ($missing.Count -eq 0 -and $supuestos.Count -gt 0) {
    return [ordered]@{
      evidence           = $evidenceOut
      status             = 'requires-agent'
      assumption_breaker = [ordered]@{
        status      = 'requires-agent'
        agente      = 'bossdream-assumption-breaker'
        instruccion = 'Invocar bossdream-assumption-breaker con supuestos[] y evidencia[] de este plan-draft.json.'
      }
    }
  }
  return New-GateResult @{ evidence = $evidenceOut } $missing
}

function Test-GateChangeSurface($Plan) {
  $fields = @('archivos_primarios', 'simbolos', 'dependencias', 'consumidores', 'tests', 'documentacion', 'contratos_externos')
  $data = [ordered]@{}
  foreach ($f in $fields) { $data[$f] = @($Plan.$f) }
  $missing = Validate-RootFields $Plan $fields
  return New-GateResult $data $missing
}

function Get-ColisionGlobal($Plan, $ProjectDir) {
  $misArchivos = @($Plan.archivos_tocados) | Where-Object { $_ }
  if ($misArchivos.Count -eq 0) { return , @() }
  $otros = Get-OtherPlanningArtifacts $ProjectDir $Plan.id_tarea
  $colisiones = [System.Collections.Generic.List[object]]::new()
  foreach ($otro in $otros) {
    $compartidos = Get-ArchivosCompartidos $misArchivos $otro.archivos_tocados
    if ($compartidos.Count -gt 0) {
      $colisiones.Add([ordered]@{ id_tarea_conflictivo = $otro.id_tarea; archivos_compartidos = $compartidos })
    }
  }
  return , @($colisiones)
}

function Test-GateExistingSolution($Plan, $ProjectDir) {
  $cascada = @($Plan.cascada)
  $missing = [System.Collections.Generic.List[string]]::new()
  if ($cascada.Count -eq 0) { $missing.Add('cascada[] vacio o ausente') }
  $anyIntentado = $false
  foreach ($nivel in $cascada) {
    if ($nivel.intentado -eq $true -and (Test-FieldFilled $nivel.resultado)) { $anyIntentado = $true }
  }
  if (-not $anyIntentado) { $missing.Add('ningun nivel de cascada[] tiene intentado=true con resultado no vacio') }
  $colisionGlobal = Get-ColisionGlobal $Plan $ProjectDir
  return New-GateResult @{ cascada = $cascada; colision_global = $colisionGlobal } $missing
}

function Test-GateAlternativePressure($Plan) {
  $decisiones = @($Plan.decisiones | Where-Object { $_.relevante -eq $true })
  $missing = [System.Collections.Generic.List[string]]::new()
  if ($decisiones.Count -eq 0) { $missing.Add('no hay decisiones con relevante=true') }
  $opciones = @('opcion_minima', 'opcion_reutilizacion', 'opcion_arquitectonica')
  $out = @()
  for ($i = 0; $i -lt $decisiones.Count; $i++) {
    $d = $decisiones[$i]
    $entry = [ordered]@{ decision = $d.decision }
    foreach ($op in $opciones) {
      $opVal = $d.$op
      $entry[$op] = [ordered]@{ costo = $opVal.costo; descartada_por = $opVal.descartada_por }
      if (-not (Test-FieldFilled $opVal.costo)) { $missing.Add("decisiones[$i].$op.costo vacio o ausente") }
      if (-not (Test-FieldFilled $opVal.descartada_por)) { $missing.Add("decisiones[$i].$op.descartada_por vacio o ausente") }
    }
    $out += [PSCustomObject]$entry
  }
  return New-GateResult @{ decisiones = $out } $missing
}

function Test-GateBlastRadius($Plan) {
  $valid = @('local', 'module', 'system', 'cross-system', 'data-contract', 'public-api')
  $missing = [System.Collections.Generic.List[string]]::new()
  $clasificacion = $Plan.clasificacion
  if (-not (Test-FieldFilled $clasificacion)) {
    $missing.Add('clasificacion vacio o ausente')
  } elseif ($valid -notcontains $clasificacion) {
    $missing.Add("clasificacion '$clasificacion' no es uno de: $($valid -join ', ')")
  }
  return New-GateResult @{ clasificacion = $clasificacion } $missing
}

function Test-GateTestability($Plan) {
  $fields = @('comportamiento_observable', 'criterios_aceptacion', 'regresiones_posibles')
  $missing = Validate-RootFields $Plan $fields
  $data = [ordered]@{
    comportamiento_observable = $Plan.comportamiento_observable
    criterios_aceptacion      = @($Plan.criterios_aceptacion)
    regresiones_posibles      = @($Plan.regresiones_posibles)
  }
  return New-GateResult $data $missing
}

function Test-GateMinimality($Plan) {
  $preguntas = @($Plan.preguntas_yagni)
  $missing = [System.Collections.Generic.List[string]]::new()
  if ($preguntas.Count -eq 0) { $missing.Add('preguntas_yagni[] vacio o ausente') }
  $missing.AddRange((Validate-ItemFields $preguntas @('pregunta', 'respuesta') 'preguntas_yagni'))
  return New-GateResult @{ preguntas_yagni = $preguntas } $missing
}

function Test-GateExecutability($Plan) {
  $pasos = @($Plan.pasos)
  $missing = [System.Collections.Generic.List[string]]::new()
  if ($pasos.Count -eq 0) { $missing.Add('pasos[] vacio o ausente') }
  $required = @('input', 'action', 'expected_output', 'validation', 'evidence')
  $missing.AddRange((Validate-ItemFields $pasos $required 'pasos'))
  return New-GateResult @{ pasos = $pasos } $missing
}

function Get-NivelVelocidad($Plan) {
  if (Test-FieldFilled $Plan.dominio_critico) { return 'ENTERPRISE' }
  $count = @($Plan.archivos_tocados).Count
  if ($count -eq 1) { return 'FAST' }
  if ($count -ge 2 -and $count -le 10) { return 'STANDARD' }
  return 'DEEP'
}

function Write-PlanningArtifact($Plan, $NivelVelocidad, $ProjectDir) {
  if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
  $dir = Join-Path $ProjectDir '.bossdream-project/artifacts/planning'
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  $path = Join-Path $dir ($Plan.id_tarea + '.artifact.json')
  $artifact = [ordered]@{
    id_tarea         = $Plan.id_tarea
    archivos_tocados = @($Plan.archivos_tocados)
    dominio_critico  = $Plan.dominio_critico
    nivel_velocidad  = $NivelVelocidad
    estado           = 'borrador'
  }
  ($artifact | ConvertTo-Json -Depth 10) | Set-Content $path -Encoding utf8
}

if (-not (Test-Path $PlanPath)) {
  ([ordered]@{ status = 'blocked'; razon = @("plan-draft.json no encontrado en '$PlanPath'") } | ConvertTo-Json -Compress -Depth 10)
  exit 1
}
$plan = Get-Content -Encoding utf8 $PlanPath -Raw | ConvertFrom-Json

$nivelVelocidad = Get-NivelVelocidad $plan
Write-PlanningArtifact -Plan $plan -NivelVelocidad $nivelVelocidad -ProjectDir $ProjectDir

if (-not $Gate) {
  ([ordered]@{ id_tarea = $plan.id_tarea; nivel_velocidad = $nivelVelocidad } | ConvertTo-Json -Compress -Depth 10)
  exit 0
}

if ($script:SemanticGateConfig.gates -contains $Gate) {
  ([ordered]@{
    status      = 'requires-agent'
    agente      = $script:SemanticGateConfig.agent
    instruccion = "Invocar el agente $($script:SemanticGateConfig.agent) con este plan-draft.json y este gate - este script no evalua juicio semantico."
  } | ConvertTo-Json -Compress -Depth 10)
  exit 2
}

$result = switch ($Gate) {
  'evidence' { Test-GateEvidence $plan }
  'change-surface' { Test-GateChangeSurface $plan }
  'existing-solution' { Test-GateExistingSolution $plan $ProjectDir }
  'alternative-pressure' { Test-GateAlternativePressure $plan }
  'blast-radius' { Test-GateBlastRadius $plan }
  'testability' { Test-GateTestability $plan }
  'minimality' { Test-GateMinimality $plan }
  'executability' { Test-GateExecutability $plan }
}

($result | ConvertTo-Json -Compress -Depth 10)
if ($result.status -eq 'pass') { exit 0 } elseif ($result.status -eq 'requires-agent') { exit 2 } else { exit 1 }
