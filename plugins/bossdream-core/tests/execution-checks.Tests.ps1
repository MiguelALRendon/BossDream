BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/execution-checks.ps1'
  $script:TestPipelineScript = Join-Path $script:PluginRoot 'scripts/test-checks.ps1'

  $script:ThreeFileDiff = @'
diff --git a/scripts/nuevo.ps1 b/scripts/nuevo.ps1
new file mode 100644
--- /dev/null
+++ b/scripts/nuevo.ps1
@@ -0,0 +1,2 @@
+Write-Output 'hola'
+Write-Output 'mundo'
diff --git a/scripts/existente.ps1 b/scripts/existente.ps1
--- a/scripts/existente.ps1
+++ b/scripts/existente.ps1
@@ -1,2 +1,2 @@
-Write-Output 'viejo'
+Write-Output 'nuevo'
 Write-Output 'sin cambios'
diff --git a/scripts/viejo.ps1 b/scripts/viejo.ps1
deleted file mode 100644
--- a/scripts/viejo.ps1
+++ /dev/null
@@ -1,2 +0,0 @@
-Write-Output 'adios'
-Write-Output 'ya no'
'@

  function New-TmpFile([string]$Content, [string]$Extension = '.diff') {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + $Extension)
    Set-Content -Path $path -Value $Content -Encoding utf8
    return $path
  }

  function New-FixtureDir {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ('eg-' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path | Out-Null
    return $path
  }

  function New-ProjectDirWithArtifacts([hashtable[]]$Artifacts) {
    $projectDir = New-FixtureDir
    $planningDir = Join-Path $projectDir '.bossdream-project/artifacts/planning'
    New-Item -ItemType Directory -Path $planningDir -Force | Out-Null
    foreach ($a in $Artifacts) {
      $file = Join-Path $planningDir ($a.id_tarea + '.artifact.json')
      $a | ConvertTo-Json -Depth 10 | Set-Content $file -Encoding utf8
    }
    return $projectDir
  }
}

Describe 'execution-checks.ps1' {

  AfterEach {
    foreach ($p in @($script:TmpDiff, $script:TmpPlan)) {
      if ($p -and (Test-Path $p)) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
    }
    if ($script:TmpDir -and (Test-Path $script:TmpDir)) { Remove-Item $script:TmpDir -Recurse -Force -ErrorAction SilentlyContinue }
  }

  It 'diff-intelligence: clasifica agregado/modificado/eliminado sobre un diff de 3 archivos' {
    $script:TmpDiff = New-TmpFile $script:ThreeFileDiff
    $result = & $script:Script -Diff $script:TmpDiff -Check diff-intelligence | ConvertFrom-Json
    $result.agregado | Should -Be @('scripts/nuevo.ps1')
    $result.modificado | Should -Be @('scripts/existente.ps1')
    $result.eliminado | Should -Be @('scripts/viejo.ps1')
    $result.comportamiento_cambiado | Should -Be ''
  }

  It 'unintended-change-detector: detecta archivo fuera de alcance cuando el plan solo declara 1 de 2' {
    $plan = @{ archivos_tocados = @('scripts/existente.ps1') }
    $script:TmpPlan = New-TmpFile ($plan | ConvertTo-Json) '.json'
    $twoFileDiff = @'
--- a/scripts/existente.ps1
+++ b/scripts/existente.ps1
@@ -1,1 +1,1 @@
-Write-Output 'viejo'
+Write-Output 'nuevo'
--- /dev/null
+++ b/scripts/nuevo.ps1
@@ -0,0 +1,1 @@
+Write-Output 'hola'
'@
    $script:TmpDiff = New-TmpFile $twoFileDiff
    $result = & $script:Script -Plan $script:TmpPlan -Diff $script:TmpDiff -Check unintended-change-detector | ConvertFrom-Json
    $result.fuera_de_alcance | Should -Be @('scripts/nuevo.ps1')
    $result.modificaciones_accidentales | Should -Be @()
    $result.complejidad_innecesaria | Should -Be @()
    $LASTEXITCODE | Should -Be 1
  }

  It 'unintended-change-detector: sin desviaciones cuando todos los archivos del diff estan en el plan - requiere bossdream-scope-enforcer' {
    $plan = @{ archivos_tocados = @('scripts/existente.ps1') }
    $script:TmpPlan = New-TmpFile ($plan | ConvertTo-Json) '.json'
    $oneFileDiff = @'
--- a/scripts/existente.ps1
+++ b/scripts/existente.ps1
@@ -1,1 +1,1 @@
-Write-Output 'viejo'
+Write-Output 'nuevo'
'@
    $script:TmpDiff = New-TmpFile $oneFileDiff
    $result = & $script:Script -Plan $script:TmpPlan -Diff $script:TmpDiff -Check unintended-change-detector | ConvertFrom-Json
    $result.fuera_de_alcance | Should -Be @()
    $result.scope_enforcer.status | Should -Be 'requires-agent'
    $result.scope_enforcer.agente | Should -Be 'bossdream-scope-enforcer'
    $LASTEXITCODE | Should -Be 2
  }

  It 'unintended-change-detector: fuera_de_alcance no vacio sigue exit 1 sin despachar bossdream-scope-enforcer' {
    $plan = @{ archivos_tocados = @('scripts/existente.ps1') }
    $script:TmpPlan = New-TmpFile ($plan | ConvertTo-Json) '.json'
    $twoFileDiff = @'
--- a/scripts/existente.ps1
+++ b/scripts/existente.ps1
@@ -1,1 +1,1 @@
-Write-Output 'viejo'
+Write-Output 'nuevo'
--- /dev/null
+++ b/scripts/nuevo.ps1
@@ -0,0 +1,1 @@
+Write-Output 'hola'
'@
    $script:TmpDiff = New-TmpFile $twoFileDiff
    $result = & $script:Script -Plan $script:TmpPlan -Diff $script:TmpDiff -Check unintended-change-detector | ConvertFrom-Json
    $result.PSObject.Properties.Name | Should -Not -Contain 'scope_enforcer'
    $LASTEXITCODE | Should -Be 1
  }

  It 'plan-to-code-traceability: con filas requiere bossdream-traceability-watcher y exit 2' {
    $plan = @{ pasos = @(@{ action = 'scripts/existente.ps1'; evidence = 'pester en verde' }) }
    $script:TmpPlan = New-TmpFile ($plan | ConvertTo-Json) '.json'
    $oneFileDiff = @'
--- a/scripts/existente.ps1
+++ b/scripts/existente.ps1
@@ -1,1 +1,1 @@
-Write-Output 'viejo'
+Write-Output 'nuevo'
'@
    $script:TmpDiff = New-TmpFile $oneFileDiff
    $result = & $script:Script -Plan $script:TmpPlan -Diff $script:TmpDiff -Check plan-to-code-traceability | ConvertFrom-Json
    $result.trazabilidad.Count | Should -Be 1
    $result.traceability_watcher.status | Should -Be 'requires-agent'
    $result.traceability_watcher.agente | Should -Be 'bossdream-traceability-watcher'
    $LASTEXITCODE | Should -Be 2
  }

  It 'plan-to-code-traceability: sin filas (diff vacio) exit 0 sin despachar bossdream-traceability-watcher' {
    $plan = @{ pasos = @() }
    $script:TmpPlan = New-TmpFile ($plan | ConvertTo-Json) '.json'
    $script:TmpDiff = New-TmpFile ''
    $result = & $script:Script -Plan $script:TmpPlan -Diff $script:TmpDiff -Check plan-to-code-traceability | ConvertFrom-Json
    $result.trazabilidad | Should -Be @()
    $result.PSObject.Properties.Name | Should -Not -Contain 'traceability_watcher'
    $LASTEXITCODE | Should -Be 0
  }

  It 'unintended-change-detector -Scope global: detecta pisada entre planes cuando otro artefacto activo toca un archivo del diff' {
    $plan = @{ id_tarea = 'tarea-actual'; archivos_tocados = @('scripts/existente.ps1', 'scripts/nuevo.ps1') }
    $script:TmpPlan = New-TmpFile ($plan | ConvertTo-Json) '.json'
    $oneFileDiff = @'
--- a/scripts/nuevo.ps1
+++ b/scripts/nuevo.ps1
@@ -0,0 +1,1 @@
+Write-Output 'hola'
'@
    $script:TmpDiff = New-TmpFile $oneFileDiff
    $script:TmpDir = New-ProjectDirWithArtifacts @(
      @{ id_tarea = 'tarea-conflictiva'; archivos_tocados = @('scripts/nuevo.ps1'); estado = 'activo' }
    )
    $result = & $script:Script -Plan $script:TmpPlan -Diff $script:TmpDiff -Check unintended-change-detector -Scope global -ProjectDir $script:TmpDir | ConvertFrom-Json
    $result.pisada_entre_planes.Count | Should -Be 1
    $result.pisada_entre_planes[0].id_tarea_conflictivo | Should -Be 'tarea-conflictiva'
    $result.pisada_entre_planes[0].archivos_compartidos | Should -Be @('scripts/nuevo.ps1')
  }

  It 'unintended-change-detector -Scope local: pisada_entre_planes vacio aunque exista otro artefacto con solape' {
    $plan = @{ id_tarea = 'tarea-actual'; archivos_tocados = @('scripts/nuevo.ps1') }
    $script:TmpPlan = New-TmpFile ($plan | ConvertTo-Json) '.json'
    $oneFileDiff = @'
--- a/scripts/nuevo.ps1
+++ b/scripts/nuevo.ps1
@@ -0,0 +1,1 @@
+Write-Output 'hola'
'@
    $script:TmpDiff = New-TmpFile $oneFileDiff
    $script:TmpDir = New-ProjectDirWithArtifacts @(
      @{ id_tarea = 'tarea-conflictiva'; archivos_tocados = @('scripts/nuevo.ps1'); estado = 'activo' }
    )
    $result = & $script:Script -Plan $script:TmpPlan -Diff $script:TmpDiff -Check unintended-change-detector -Scope local -ProjectDir $script:TmpDir | ConvertFrom-Json
    $result.pisada_entre_planes | Should -Be @()
  }

  It 'unintended-change-detector -Scope global: pisada_entre_planes vacio cuando no hay solape con otros artefactos' {
    $plan = @{ id_tarea = 'tarea-actual'; archivos_tocados = @('scripts/nuevo.ps1') }
    $script:TmpPlan = New-TmpFile ($plan | ConvertTo-Json) '.json'
    $oneFileDiff = @'
--- a/scripts/nuevo.ps1
+++ b/scripts/nuevo.ps1
@@ -0,0 +1,1 @@
+Write-Output 'hola'
'@
    $script:TmpDiff = New-TmpFile $oneFileDiff
    $script:TmpDir = New-ProjectDirWithArtifacts @(
      @{ id_tarea = 'tarea-sin-solape'; archivos_tocados = @('scripts/otro.ps1'); estado = 'activo' }
    )
    $result = & $script:Script -Plan $script:TmpPlan -Diff $script:TmpDiff -Check unintended-change-detector -Scope global -ProjectDir $script:TmpDir | ConvertFrom-Json
    $result.pisada_entre_planes | Should -Be @()
  }

  It 'correctness-chain: reusa test-checks.ps1 - misma salida JSON literal, sin reimplementar las 5 etapas' {
    $script:TmpDir = New-FixtureDir
    $expected = & $script:TestPipelineScript -ProjectDir $script:TmpDir
    $actual = & $script:Script -Check correctness-chain -ProjectDir $script:TmpDir
    $actual | Should -Be $expected
  }

  It 'correctness-chain: exit 1 cuando test-checks.ps1 falla (quality_approval failed)' {
    $script:TmpDir = New-FixtureDir
    @{ stages = @(@{ id = 'fail-stage'; order = 1; cmd = 'exit 1'; tier = 'local'; blocking = 'hard' }) } | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $script:TmpDir 'pipeline.json') -Encoding utf8
    & $script:Script -Check correctness-chain -ProjectDir $script:TmpDir | Out-Null
    $LASTEXITCODE | Should -Be 1
  }

  It 'reporta blocked cuando el diff no existe' {
    $result = & $script:Script -Diff 'no-existe.diff' -Check diff-intelligence | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $LASTEXITCODE | Should -Be 1
  }
}
