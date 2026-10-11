BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/plan-checks.ps1'

  function New-CompletePlan {
    return @{
      id_tarea             = 'epic-002-test'
      necesidad             = 'el plan checks necesita validar plan-draft.json'
      solucion_propuesta    = 'dispatcher determinista con 8 validadores'
      archivos_tocados      = @('scripts/plan-checks.ps1')
      evidencia             = @(
        @{ claim = 'el patron validation-run ya funciona'; source = 'validation-check.ps1'; confidence = 'alta'; impact = 'reduce riesgo de diseno' }
      )
      archivos_primarios    = @('scripts/plan-checks.ps1')
      simbolos              = @('Test-GateEvidence')
      dependencias          = @('ninguna nueva')
      consumidores          = @('skills/plan-checks/SKILL.md')
      tests                 = @('tests/plan-checks.Tests.ps1')
      documentacion         = @('docs/catalog/plan-checks.md')
      contratos_externos    = @('ninguno')
      cascada               = @(
        @{ nivel = 'simbolo'; intentado = $true; resultado = 'no existe validador previo' }
      )
      decisiones            = @(
        @{
          decision              = 'un solo script con 8 funciones'
          relevante             = $true
          opcion_minima         = @{ costo = 'bajo'; descartada_por = 'no cubre los 8 gates' }
          opcion_reutilizacion  = @{ costo = 'medio'; descartada_por = 'no aplica, es codigo nuevo' }
          opcion_arquitectonica = @{ costo = 'alto'; descartada_por = 'sobre-ingenieria para 8 validadores' }
        }
      )
      clasificacion         = 'module'
      comportamiento_observable = 'el gate bloquea si falta un campo requerido'
      criterios_aceptacion  = @('AC-004.2 a AC-004.10')
      regresiones_posibles  = @('ninguna conocida, script nuevo')
      preguntas_yagni       = @(
        @{ pregunta = 'hace falta un motor de gates generico?'; respuesta = 'no, 8 validadores fijos bastan' }
      )
      pasos                 = @(
        @{ input = 'plan-draft.json'; action = 'correr el gate pedido'; expected_output = 'status pass o blocked'; validation = 'exit code 0 o 1'; evidence = 'salida JSON del script' }
      )
    }
  }

  function New-PlanFile([hashtable]$Plan) {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.json')
    $Plan | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding utf8
    return $path
  }

  function New-ProjectDirWithArtifacts([hashtable[]]$Artifacts) {
    $projectDir = Join-Path ([System.IO.Path]::GetTempPath()) ('pg-proj-' + [System.Guid]::NewGuid().ToString('N'))
    $planningDir = Join-Path $projectDir '.bossdream-project/artifacts/planning'
    New-Item -ItemType Directory -Path $planningDir -Force | Out-Null
    foreach ($a in $Artifacts) {
      $file = Join-Path $planningDir ($a.id_tarea + '.artifact.json')
      $a | ConvertTo-Json -Depth 10 | Set-Content $file -Encoding utf8
    }
    return $projectDir
  }
}

Describe 'plan-checks.ps1' {

  AfterEach {
    if ($script:TmpFile -and (Test-Path $script:TmpFile)) { Remove-Item $script:TmpFile -Force -ErrorAction SilentlyContinue }
    if ($script:TmpProjectDir -and (Test-Path $script:TmpProjectDir)) { Remove-Item $script:TmpProjectDir -Recurse -Force -ErrorAction SilentlyContinue }
  }

  It 'gate evidence: aprueba un plan completo con claim/source/confidence/impact' {
    $plan = New-CompletePlan
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate evidence | ConvertFrom-Json
    $result.status | Should -Be 'pass'
    $result.evidence[0].claim | Should -Not -BeNullOrEmpty
  }

  It 'gate evidence: bloquea cuando falta source en una entrada de evidencia' {
    $plan = New-CompletePlan
    $plan.evidencia[0].Remove('source')
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate evidence | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.razon | Should -Not -BeNullOrEmpty
  }

  It 'gate change-surface: aprueba un plan con los 7 arrays presentes y no vacios' {
    $plan = New-CompletePlan
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate change-surface | ConvertFrom-Json
    $result.status | Should -Be 'pass'
    $result.contratos_externos | Should -Not -BeNullOrEmpty
  }

  It 'gate change-surface: bloquea cuando consumidores[] esta vacio' {
    $plan = New-CompletePlan
    $plan.consumidores = @()
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate change-surface | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.razon | Should -Not -BeNullOrEmpty
  }

  It 'gate existing-solution: aprueba un plan con al menos un nivel de cascada intentado y con resultado' {
    $plan = New-CompletePlan
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate existing-solution | ConvertFrom-Json
    $result.status | Should -Be 'pass'
  }

  It 'gate existing-solution: bloquea cuando ningun nivel de cascada fue intentado' {
    $plan = New-CompletePlan
    $plan.cascada[0].intentado = $false
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate existing-solution | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.razon | Should -Not -BeNullOrEmpty
  }

  It 'gate existing-solution: colision_global detecta otro artefacto activo con archivos_tocados solapados' {
    $plan = New-CompletePlan
    $plan.id_tarea = 'tarea-actual'
    $plan.archivos_tocados = @('scripts/plan-checks.ps1', 'scripts/pipeline-helpers.psm1')
    $script:TmpProjectDir = New-ProjectDirWithArtifacts @(
      @{ id_tarea = 'tarea-conflictiva'; archivos_tocados = @('scripts/pipeline-helpers.psm1'); estado = 'activo' }
    )
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate existing-solution -ProjectDir $script:TmpProjectDir | ConvertFrom-Json
    $result.status | Should -Be 'pass'
    $result.colision_global.Count | Should -Be 1
    $result.colision_global[0].id_tarea_conflictivo | Should -Be 'tarea-conflictiva'
    $result.colision_global[0].archivos_compartidos | Should -Be @('scripts/pipeline-helpers.psm1')
  }

  It 'gate existing-solution: ignora artefactos con estado consumido y no reporta colision' {
    $plan = New-CompletePlan
    $plan.id_tarea = 'tarea-actual'
    $plan.archivos_tocados = @('scripts/plan-checks.ps1')
    $script:TmpProjectDir = New-ProjectDirWithArtifacts @(
      @{ id_tarea = 'tarea-consumida'; archivos_tocados = @('scripts/plan-checks.ps1'); estado = 'consumido' }
    )
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate existing-solution -ProjectDir $script:TmpProjectDir | ConvertFrom-Json
    $result.status | Should -Be 'pass'
    $result.colision_global | Should -Be @()
  }

  It 'gate existing-solution: colision_global vacio cuando no hay solape con otros artefactos' {
    $plan = New-CompletePlan
    $plan.id_tarea = 'tarea-actual'
    $plan.archivos_tocados = @('scripts/plan-checks.ps1')
    $script:TmpProjectDir = New-ProjectDirWithArtifacts @(
      @{ id_tarea = 'tarea-sin-solape'; archivos_tocados = @('scripts/test-checks.ps1'); estado = 'activo' }
    )
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate existing-solution -ProjectDir $script:TmpProjectDir | ConvertFrom-Json
    $result.status | Should -Be 'pass'
    $result.colision_global | Should -Be @()
  }

  It 'gate alternative-pressure: aprueba cuando cada decision relevante trae las 3 opciones con costo/descartada_por' {
    $plan = New-CompletePlan
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate alternative-pressure | ConvertFrom-Json
    $result.status | Should -Be 'pass'
  }

  It 'gate alternative-pressure: bloquea cuando falta descartada_por en opcion_arquitectonica' {
    $plan = New-CompletePlan
    $plan.decisiones[0].opcion_arquitectonica.Remove('descartada_por')
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate alternative-pressure | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.razon | Should -Not -BeNullOrEmpty
  }

  It 'gate blast-radius: aprueba una clasificacion valida' {
    $plan = New-CompletePlan
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate blast-radius | ConvertFrom-Json
    $result.status | Should -Be 'pass'
    $result.clasificacion | Should -Be 'module'
  }

  It 'gate blast-radius: bloquea una clasificacion fuera del enum permitido' {
    $plan = New-CompletePlan
    $plan.clasificacion = 'planeta'
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate blast-radius | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.razon | Should -Not -BeNullOrEmpty
  }

  It 'gate testability: aprueba cuando comportamiento/criterios/regresiones estan presentes' {
    $plan = New-CompletePlan
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate testability | ConvertFrom-Json
    $result.status | Should -Be 'pass'
  }

  It 'gate testability: bloquea cuando regresiones_posibles esta vacio' {
    $plan = New-CompletePlan
    $plan.regresiones_posibles = @()
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate testability | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.razon | Should -Not -BeNullOrEmpty
  }

  It 'gate minimality: aprueba cuando preguntas_yagni trae pregunta y respuesta' {
    $plan = New-CompletePlan
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate minimality | ConvertFrom-Json
    $result.status | Should -Be 'pass'
  }

  It 'gate minimality: bloquea cuando falta respuesta en preguntas_yagni' {
    $plan = New-CompletePlan
    $plan.preguntas_yagni[0].Remove('respuesta')
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate minimality | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.razon | Should -Not -BeNullOrEmpty
  }

  It 'gate executability: aprueba cuando cada paso trae input/action/expected_output/validation/evidence' {
    $plan = New-CompletePlan
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate executability | ConvertFrom-Json
    $result.status | Should -Be 'pass'
  }

  It 'gate executability: bloquea cuando falta validation en un paso' {
    $plan = New-CompletePlan
    $plan.pasos[0].Remove('validation')
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate executability | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.razon | Should -Not -BeNullOrEmpty
  }

  It 'exit code 0 cuando el gate pasa' {
    $plan = New-CompletePlan
    $script:TmpFile = New-PlanFile $plan
    & $script:Script -PlanPath $script:TmpFile -Gate blast-radius | Out-Null
    $LASTEXITCODE | Should -Be 0
  }

  It 'exit code 1 cuando el gate bloquea' {
    $plan = New-CompletePlan
    $plan.clasificacion = ''
    $script:TmpFile = New-PlanFile $plan
    & $script:Script -PlanPath $script:TmpFile -Gate blast-radius | Out-Null
    $LASTEXITCODE | Should -Be 1
  }

  It 'reporta blocked cuando el plan-draft.json no existe' {
    $script:TmpFile = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.json')
    $result = & $script:Script -PlanPath $script:TmpFile -Gate evidence | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $script:TmpFile = $null
  }

  It 'gate evidence: supuestos[] ausente no cambia el resultado actual (pass, sin agente)' {
    $plan = New-CompletePlan
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate evidence | ConvertFrom-Json
    $result.status | Should -Be 'pass'
    $result.assumption_breaker | Should -BeNullOrEmpty
    & $script:Script -PlanPath $script:TmpFile -Gate evidence | Out-Null
    $LASTEXITCODE | Should -Be 0
  }

  It 'gate evidence: supuestos[] no vacio con evidencia completa dispara requires-agent' {
    $plan = New-CompletePlan
    $plan.supuestos = @('la API externa soporta paginacion')
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate evidence | ConvertFrom-Json
    $result.status | Should -Be 'requires-agent'
    $result.assumption_breaker.agente | Should -Be 'bossdream-assumption-breaker'
    & $script:Script -PlanPath $script:TmpFile -Gate evidence | Out-Null
    $LASTEXITCODE | Should -Be 2
  }

  It 'gate evidence: supuestos[] no vacio pero evidencia incompleta sigue bloqueando deterministico (sin agente)' {
    $plan = New-CompletePlan
    $plan.supuestos = @('la API externa soporta paginacion')
    $plan.evidencia[0].Remove('source')
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate evidence | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.assumption_breaker | Should -BeNullOrEmpty
    & $script:Script -PlanPath $script:TmpFile -Gate evidence | Out-Null
    $LASTEXITCODE | Should -Be 1
  }

  It 'gate intent-integrity: devuelve requires-agent con exit code 2' {
    $plan = New-CompletePlan
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate intent-integrity | ConvertFrom-Json
    $result.status | Should -Be 'requires-agent'
    $result.agente | Should -Be 'bossdream-planner-auditor'
    $LASTEXITCODE | Should -Be 2
  }

  It 'gate contradiction: devuelve requires-agent con exit code 2' {
    $plan = New-CompletePlan
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -Gate contradiction | ConvertFrom-Json
    $result.status | Should -Be 'requires-agent'
    $result.agente | Should -Be 'bossdream-planner-auditor'
    $LASTEXITCODE | Should -Be 2
  }

  It 'nivel_velocidad: 1 archivo tocado clasifica FAST' {
    $plan = New-CompletePlan
    $plan.id_tarea = 'nivel-fast'
    $plan.archivos_tocados = @('utils/helper.ts')
    $script:TmpProjectDir = Join-Path ([System.IO.Path]::GetTempPath()) ('pg-nivel-' + [System.Guid]::NewGuid().ToString('N'))
    $script:TmpFile = New-PlanFile $plan
    & $script:Script -PlanPath $script:TmpFile -Gate blast-radius -ProjectDir $script:TmpProjectDir | Out-Null
    $artifact = Get-Content (Join-Path $script:TmpProjectDir '.bossdream-project/artifacts/planning/nivel-fast.artifact.json') -Raw | ConvertFrom-Json
    $artifact.nivel_velocidad | Should -Be 'FAST'
  }

  It 'nivel_velocidad: 4 archivos tocados clasifica STANDARD' {
    $plan = New-CompletePlan
    $plan.id_tarea = 'nivel-standard'
    $plan.archivos_tocados = @('a.ts', 'b.ts', 'c.ts', 'd.ts')
    $script:TmpProjectDir = Join-Path ([System.IO.Path]::GetTempPath()) ('pg-nivel-' + [System.Guid]::NewGuid().ToString('N'))
    $script:TmpFile = New-PlanFile $plan
    & $script:Script -PlanPath $script:TmpFile -Gate blast-radius -ProjectDir $script:TmpProjectDir | Out-Null
    $artifact = Get-Content (Join-Path $script:TmpProjectDir '.bossdream-project/artifacts/planning/nivel-standard.artifact.json') -Raw | ConvertFrom-Json
    $artifact.nivel_velocidad | Should -Be 'STANDARD'
  }

  It 'nivel_velocidad: 14 archivos tocados clasifica DEEP' {
    $plan = New-CompletePlan
    $plan.id_tarea = 'nivel-deep'
    $plan.archivos_tocados = @(1..14 | ForEach-Object { "archivo-$_.ts" })
    $script:TmpProjectDir = Join-Path ([System.IO.Path]::GetTempPath()) ('pg-nivel-' + [System.Guid]::NewGuid().ToString('N'))
    $script:TmpFile = New-PlanFile $plan
    & $script:Script -PlanPath $script:TmpFile -Gate blast-radius -ProjectDir $script:TmpProjectDir | Out-Null
    $artifact = Get-Content (Join-Path $script:TmpProjectDir '.bossdream-project/artifacts/planning/nivel-deep.artifact.json') -Raw | ConvertFrom-Json
    $artifact.nivel_velocidad | Should -Be 'DEEP'
  }

  It 'nivel_velocidad: dominio_critico presente clasifica ENTERPRISE' {
    $plan = New-CompletePlan
    $plan.id_tarea = 'nivel-enterprise'
    $plan.archivos_tocados = @('a.ts', 'b.ts', 'c.ts')
    $plan.dominio_critico = 'pagos'
    $script:TmpProjectDir = Join-Path ([System.IO.Path]::GetTempPath()) ('pg-nivel-' + [System.Guid]::NewGuid().ToString('N'))
    $script:TmpFile = New-PlanFile $plan
    & $script:Script -PlanPath $script:TmpFile -Gate blast-radius -ProjectDir $script:TmpProjectDir | Out-Null
    $artifact = Get-Content (Join-Path $script:TmpProjectDir '.bossdream-project/artifacts/planning/nivel-enterprise.artifact.json') -Raw | ConvertFrom-Json
    $artifact.nivel_velocidad | Should -Be 'ENTERPRISE'
  }

  It 'sin -Gate: calcula nivel_velocidad, escribe el artefacto y termina con exit 0 sin correr ningun gate' {
    $plan = New-CompletePlan
    $plan.id_tarea = 'sin-gate-standard'
    $plan.archivos_tocados = @('a.ts', 'b.ts', 'c.ts', 'd.ts')
    $plan.clasificacion = ''
    $script:TmpProjectDir = Join-Path ([System.IO.Path]::GetTempPath()) ('pg-nivel-' + [System.Guid]::NewGuid().ToString('N'))
    $script:TmpFile = New-PlanFile $plan
    $result = & $script:Script -PlanPath $script:TmpFile -ProjectDir $script:TmpProjectDir | ConvertFrom-Json
    $LASTEXITCODE | Should -Be 0
    $result.nivel_velocidad | Should -Be 'STANDARD'
    $result.status | Should -BeNullOrEmpty
    $result.razon | Should -BeNullOrEmpty
    $artifact = Get-Content (Join-Path $script:TmpProjectDir '.bossdream-project/artifacts/planning/sin-gate-standard.artifact.json') -Raw | ConvertFrom-Json
    $artifact.nivel_velocidad | Should -Be 'STANDARD'
  }

  It 'nivel_velocidad: dominio_critico presente fuerza ENTERPRISE incondicionalmente aunque archivos_tocados tenga 1 solo archivo' {
    $plan = New-CompletePlan
    $plan.id_tarea = 'nivel-enterprise-1-archivo'
    $plan.archivos_tocados = @('unico-archivo.ts')
    $plan.dominio_critico = 'seguridad'
    $script:TmpProjectDir = Join-Path ([System.IO.Path]::GetTempPath()) ('pg-nivel-' + [System.Guid]::NewGuid().ToString('N'))
    $script:TmpFile = New-PlanFile $plan
    & $script:Script -PlanPath $script:TmpFile -Gate blast-radius -ProjectDir $script:TmpProjectDir | Out-Null
    $artifact = Get-Content (Join-Path $script:TmpProjectDir '.bossdream-project/artifacts/planning/nivel-enterprise-1-archivo.artifact.json') -Raw | ConvertFrom-Json
    $artifact.nivel_velocidad | Should -Be 'ENTERPRISE'
  }
}
