BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/test-checks.ps1'
  Import-Module (Join-Path $script:PluginRoot 'scripts/pipeline-helpers.psm1') -Force -WarningAction SilentlyContinue

  function New-FixtureDir {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ('tg-' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path | Out-Null
    return $path
  }

  function Invoke-TestPipeline([string]$ProjectDir, [string]$Diff) {
    $json = & $script:Script -ProjectDir $ProjectDir -Diff $Diff
    return $json | ConvertFrom-Json
  }

  function New-DiffFile([string]$RelativePath) {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ('tg-diff-' + [System.Guid]::NewGuid().ToString('N') + '.diff')
    @"
--- a/$RelativePath
+++ b/$RelativePath
+linea nueva
"@ | Set-Content -Path $path -Encoding utf8
    return $path
  }

  function New-ProjectDirWithArtifacts([hashtable[]]$Artifacts) {
    $projectDir = Join-Path ([System.IO.Path]::GetTempPath()) ('tg-proj-' + [System.Guid]::NewGuid().ToString('N'))
    $planningDir = Join-Path $projectDir '.bossdream-project/artifacts/planning'
    New-Item -ItemType Directory -Path $planningDir -Force | Out-Null
    foreach ($a in $Artifacts) {
      $file = Join-Path $planningDir ($a.id_tarea + '.artifact.json')
      $a | ConvertTo-Json -Depth 10 | Set-Content $file -Encoding utf8
    }
    return $projectDir
  }

  function New-ProjectDirWithInventory([hashtable]$Inventory) {
    $projectDir = Join-Path ([System.IO.Path]::GetTempPath()) ('tg-inv-' + [System.Guid]::NewGuid().ToString('N'))
    $bossdreamDir = Join-Path $projectDir '.bossdream-project'
    New-Item -ItemType Directory -Path $bossdreamDir -Force | Out-Null
    $Inventory | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $bossdreamDir 'test-inventory.json') -Encoding utf8
    return $projectDir
  }

  function Get-MinimalPassingInventory {
    return @{
      behavior       = ''
      rules          = @()
      flows          = @()
      happy_paths    = @()
      negative_paths = @()
      boundaries     = @()
      dependencies   = @()
      tests          = @()
      evidence       = 'inventario minimo de fixture sin reglas ni flujos que cubrir'
    }
  }
}

Describe 'test-checks.ps1' {

  AfterEach {
    if ($script:TmpDir -and (Test-Path $script:TmpDir)) { Remove-Item $script:TmpDir -Recurse -Force -ErrorAction SilentlyContinue }
    if ($script:TmpDiff -and (Test-Path $script:TmpDiff)) { Remove-Item $script:TmpDiff -Force -ErrorAction SilentlyContinue }
  }

  It 'produce las 5 secciones siempre en el orden fijo' {
    $script:TmpDir = New-FixtureDir
    $result = Invoke-TestPipeline $script:TmpDir
    $names = $result.PSObject.Properties.Name
    $names | Should -Be @('code_correctness', 'contract_correctness', 'flow_correctness', 'regression_safety', 'quality_approval')
  }

  It 'flow_correctness: failed via test-inventory-check.ps1 real cuando no existe test-inventory.json' {
    $script:TmpDir = New-FixtureDir
    $result = Invoke-TestPipeline $script:TmpDir
    $result.flow_correctness.status | Should -Be 'failed'
    $result.flow_correctness.condicion_de_bloqueo | Should -Match 'test-inventory.json no encontrado'
  }

  It 'flow_correctness: passed via test-inventory-check.ps1 real cuando el Test Inventory cubre todo' {
    $script:TmpDir = New-ProjectDirWithInventory (Get-MinimalPassingInventory)
    $result = Invoke-TestPipeline $script:TmpDir
    $result.flow_correctness.status | Should -Be 'passed'
  }

  It 'flow_correctness: failed citando la regla concreta sin cobertura cuando el Test Inventory tiene huecos' {
    $inventory = Get-MinimalPassingInventory
    $inventory.rules = @('Un pedido Shipped no puede volver a Pending')
    $script:TmpDir = New-ProjectDirWithInventory $inventory
    $result = Invoke-TestPipeline $script:TmpDir
    $result.flow_correctness.status | Should -Be 'failed'
    $result.flow_correctness.condicion_de_bloqueo | Should -Match 'Missing validation coverage'
  }

  It 'quality_approval: requires-agent (rutea a bossdream-qa-planner, mismo patron que plan-checks) cuando nada previo fallo' {
    $script:TmpDir = New-ProjectDirWithInventory (Get-MinimalPassingInventory)
    $result = Invoke-TestPipeline $script:TmpDir
    $result.quality_approval.status | Should -Be 'requires-agent'
    $result.quality_approval.agente | Should -Be 'bossdream-qa-planner'
    $result.quality_approval.instruccion | Should -Not -BeNullOrEmpty
    $result.quality_approval.PSObject.Properties.Name | Should -Not -Contain 'flow_breaker'
  }

  It 'flow_correctness: agrega flow_breaker cuando pasa Y el inventario trae flows[] no vacio' {
    $inventory = Get-MinimalPassingInventory
    $inventory.flows = @(@{
      estados                 = @('Pending', 'Shipped')
      transiciones_validas    = @()
      transiciones_invalidas  = @()
      dead_ends               = @()
      retries                 = @()
      rollbacks               = @()
    })
    $script:TmpDir = New-ProjectDirWithInventory $inventory
    $result = Invoke-TestPipeline $script:TmpDir
    $result.flow_correctness.status | Should -Be 'passed'
    $result.flow_correctness.flow_breaker.status | Should -Be 'requires-agent'
    $result.flow_correctness.flow_breaker.agente | Should -Be 'bossdream-flow-breaker'
  }

  It 'quality_approval: requires-agent con flow_breaker pendiente ademas de bossdream-qa-planner cuando flow_correctness lo trae' {
    $inventory = Get-MinimalPassingInventory
    $inventory.flows = @(@{
      estados                 = @('Pending', 'Shipped')
      transiciones_validas    = @()
      transiciones_invalidas  = @()
      dead_ends               = @()
      retries                 = @()
      rollbacks               = @()
    })
    $script:TmpDir = New-ProjectDirWithInventory $inventory
    $result = Invoke-TestPipeline $script:TmpDir
    $result.quality_approval.status | Should -Be 'requires-agent'
    $result.quality_approval.agente | Should -Be 'bossdream-qa-planner'
    $result.quality_approval.flow_breaker.status | Should -Be 'requires-agent'
    $result.quality_approval.flow_breaker.agente | Should -Be 'bossdream-flow-breaker'
  }

  It 'quality_approval: failed cuando flow_correctness fallo (sin test-inventory.json)' {
    $script:TmpDir = New-FixtureDir
    $result = Invoke-TestPipeline $script:TmpDir
    $result.quality_approval.status | Should -Be 'failed'
    $result.quality_approval.condicion_de_bloqueo | Should -Match 'previas'
  }

  It 'contract_correctness: passed cuando no hay contratos en el proyecto' {
    $script:TmpDir = New-FixtureDir
    $result = Invoke-TestPipeline $script:TmpDir
    $result.contract_correctness.status | Should -Be 'passed'
  }

  It 'contract_correctness: failed cuando un .schema.json esta roto' {
    $script:TmpDir = New-FixtureDir
    Set-Content -Path (Join-Path $script:TmpDir 'roto.schema.json') -Value '{ "campo": ' -Encoding utf8
    $result = Invoke-TestPipeline $script:TmpDir
    $result.contract_correctness.status | Should -Be 'failed'
    $result.contract_correctness.condicion_de_bloqueo | Should -Match 'roto.schema.json'
    $result.contract_correctness.escape_hatch | Should -BeNullOrEmpty
  }

  It 'contract_correctness: ignora un .schema.json roto dentro de node_modules' {
    $script:TmpDir = New-FixtureDir
    $nodeModules = Join-Path $script:TmpDir 'node_modules/alguna-lib'
    New-Item -ItemType Directory -Path $nodeModules -Force | Out-Null
    Set-Content -Path (Join-Path $nodeModules 'roto.schema.json') -Value '{ "campo": ' -Encoding utf8
    $result = Invoke-TestPipeline $script:TmpDir
    $result.contract_correctness.status | Should -Be 'passed'
  }

  It 'regression_safety: skipped cuando testing.enabled es false en bossdream.json' {
    $script:TmpDir = New-FixtureDir
    @{ testing = @{ enabled = $false; project = '' } } | ConvertTo-Json | Set-Content -Path (Join-Path $script:TmpDir 'bossdream.json') -Encoding utf8
    $result = Invoke-TestPipeline $script:TmpDir
    $result.regression_safety.status | Should -Be 'skipped'
    $result.regression_safety.nota | Should -Not -BeNullOrEmpty
  }

  It 'regression_safety: skipped con nota cuando testing.enabled es true pero no hay herramienta de mutation para el stack' {
    $script:TmpDir = New-FixtureDir
    New-Item -ItemType Directory -Path (Join-Path $script:TmpDir 'MiTesting') | Out-Null
    @{ testing = @{ enabled = $true; project = 'MiTesting' } } | ConvertTo-Json | Set-Content -Path (Join-Path $script:TmpDir 'bossdream.json') -Encoding utf8
    $result = Invoke-TestPipeline $script:TmpDir
    $result.regression_safety.status | Should -Be 'skipped'
    $result.regression_safety.nota | Should -Match 'mutation'
  }

  It 'code_correctness: passed cuando el proyecto no tiene pipeline.json' {
    $script:TmpDir = New-FixtureDir
    $result = Invoke-TestPipeline $script:TmpDir
    $result.code_correctness.status | Should -Be 'passed'
  }

  It 'code_correctness: failed cuando una etapa del pipeline.json falla, con severidad hard y escape_hatch null' {
    $script:TmpDir = New-FixtureDir
    @{ stages = @(@{ id = 'fail-stage'; order = 1; cmd = 'exit 1'; tier = 'local'; blocking = 'hard' }) } | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $script:TmpDir 'pipeline.json') -Encoding utf8
    $result = Invoke-TestPipeline $script:TmpDir
    $result.code_correctness.status | Should -Be 'failed'
    $result.code_correctness.severidad | Should -Be 'hard'
    $result.code_correctness.condicion_de_bloqueo | Should -Not -BeNullOrEmpty
    $result.code_correctness.escape_hatch | Should -BeNullOrEmpty
  }

  It 'quality_approval: failed cuando code_correctness fallo, con condicion de bloqueo por etapas previas' {
    $script:TmpDir = New-FixtureDir
    @{ stages = @(@{ id = 'fail-stage'; order = 1; cmd = 'exit 1'; tier = 'local'; blocking = 'hard' }) } | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $script:TmpDir 'pipeline.json') -Encoding utf8
    $result = Invoke-TestPipeline $script:TmpDir
    $result.quality_approval.status | Should -Be 'failed'
    $result.quality_approval.severidad | Should -Be 'hard'
    $result.quality_approval.condicion_de_bloqueo | Should -Match 'previas'
    $result.quality_approval.escape_hatch | Should -BeNullOrEmpty
  }

  It 'exit code 1 cuando quality_approval queda failed por una etapa previa' {
    $script:TmpDir = New-FixtureDir
    @{ stages = @(@{ id = 'fail-stage'; order = 1; cmd = 'exit 1'; tier = 'local'; blocking = 'hard' }) } | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $script:TmpDir 'pipeline.json') -Encoding utf8
    & $script:Script -ProjectDir $script:TmpDir | Out-Null
    $LASTEXITCODE | Should -Be 1
  }

  It 'exit code 2 cuando quality_approval queda requires-agent (nada previo fallo)' {
    $script:TmpDir = New-ProjectDirWithInventory (Get-MinimalPassingInventory)
    & $script:Script -ProjectDir $script:TmpDir | Out-Null
    $LASTEXITCODE | Should -Be 2
  }

  It 'regression_safety: consumidores_externos_detectados incluye otro plan activo que toca el mismo archivo del diff' {
    $script:TmpDir = New-ProjectDirWithArtifacts @(
      @{ id_tarea = 'tarea-conflictiva'; archivos_tocados = @('scripts/compartido.ps1'); estado = 'activo' }
    )
    $script:TmpDiff = New-DiffFile 'scripts/compartido.ps1'
    $result = Invoke-TestPipeline $script:TmpDir $script:TmpDiff
    $detectados = @($result.regression_safety.consumidores_externos_detectados)
    $detectados.Count | Should -Be 1
    $detectados[0].id_tarea_conflictivo | Should -Be 'tarea-conflictiva'
    $detectados[0].archivos_compartidos | Should -Be @('scripts/compartido.ps1')
  }

  It 'regression_safety: consumidores_externos_detectados ignora planes con estado consumido' {
    $script:TmpDir = New-ProjectDirWithArtifacts @(
      @{ id_tarea = 'tarea-consumida'; archivos_tocados = @('scripts/compartido.ps1'); estado = 'consumido' }
    )
    $script:TmpDiff = New-DiffFile 'scripts/compartido.ps1'
    $result = Invoke-TestPipeline $script:TmpDir $script:TmpDiff
    @($result.regression_safety.consumidores_externos_detectados) | Should -Be @()
  }
}

Describe 'Get-ProjectFiles (pipeline-helpers.psm1)' {

  AfterEach {
    if ($script:TmpDir -and (Test-Path $script:TmpDir)) { Remove-Item $script:TmpDir -Recurse -Force -ErrorAction SilentlyContinue }
  }

  It 'excluye archivos dentro de node_modules y devuelve solo los archivos reales' {
    $script:TmpDir = New-FixtureDir
    New-Item -ItemType File -Path (Join-Path $script:TmpDir 'real.js') -Force | Out-Null
    $nodeModules = Join-Path $script:TmpDir 'node_modules/alguna-lib'
    New-Item -ItemType Directory -Path $nodeModules -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $nodeModules 'vendor.js') -Force | Out-Null
    $files = Get-ProjectFiles $script:TmpDir '*.js'
    @($files).Count | Should -Be 1
    $files.Name | Should -Be 'real.js'
  }

  It 'excluye .git, bin, obj, dist, build, vendor, target, .venv y __pycache__ ademas de node_modules' {
    $script:TmpDir = New-FixtureDir
    New-Item -ItemType File -Path (Join-Path $script:TmpDir 'real.py') -Force | Out-Null
    $excluidos = @('.git', 'bin', 'obj', 'dist', 'build', 'vendor', 'target', '.venv', '__pycache__')
    foreach ($dir in $excluidos) {
      $sub = Join-Path $script:TmpDir $dir
      New-Item -ItemType Directory -Path $sub -Force | Out-Null
      New-Item -ItemType File -Path (Join-Path $sub 'excluido.py') -Force | Out-Null
    }
    $files = Get-ProjectFiles $script:TmpDir '*.py'
    @($files).Count | Should -Be 1
    $files.Name | Should -Be 'real.py'
  }
}
