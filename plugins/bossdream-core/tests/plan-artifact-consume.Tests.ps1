BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/plan-artifact-consume.ps1'
  Import-Module (Join-Path $script:PluginRoot 'scripts/pipeline-helpers.psm1') -Force -WarningAction SilentlyContinue

  function New-ProjectDirWithArtifact([string]$IdTarea, [hashtable]$Extra = @{}) {
    $projectDir = Join-Path ([System.IO.Path]::GetTempPath()) ('pac-proj-' + [System.Guid]::NewGuid().ToString('N'))
    $planningDir = Join-Path $projectDir '.bossdream-project/artifacts/planning'
    New-Item -ItemType Directory -Path $planningDir -Force | Out-Null
    $artifact = [ordered]@{ id_tarea = $IdTarea; archivos_tocados = @('scripts/foo.ps1'); estado = 'activo' }
    foreach ($k in $Extra.Keys) { $artifact[$k] = $Extra[$k] }
    $artifact | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $planningDir "$IdTarea.artifact.json") -Encoding utf8
    return $projectDir
  }
}

Describe 'plan-artifact-consume.ps1' {

  AfterEach {
    if ($script:TmpProjectDir -and (Test-Path $script:TmpProjectDir)) {
      Remove-Item -Recurse -Force $script:TmpProjectDir -ErrorAction SilentlyContinue
    }
  }

  It 'marca estado consumido y mueve el artefacto a artifacts/planning/consumidos/' {
    $script:TmpProjectDir = New-ProjectDirWithArtifact 'increment-5-4'
    $planningDir = Join-Path $script:TmpProjectDir '.bossdream-project/artifacts/planning'
    $originalPath = Join-Path $planningDir 'increment-5-4.artifact.json'
    $consumedPath = Join-Path $planningDir 'consumidos/increment-5-4.artifact.json'

    & $script:Script -ProjectDir $script:TmpProjectDir -IdTarea 'increment-5-4' | Out-Null

    Test-Path $originalPath | Should -BeFalse
    Test-Path $consumedPath | Should -BeTrue
    $moved = Get-Content $consumedPath -Raw | ConvertFrom-Json
    $moved.estado | Should -Be 'consumido'
    $moved.id_tarea | Should -Be 'increment-5-4'
  }

  It 'artefacto inexistente sale limpio con exit 0 sin crear nada' {
    $script:TmpProjectDir = Join-Path ([System.IO.Path]::GetTempPath()) ('pac-proj-' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:TmpProjectDir -Force | Out-Null

    & $script:Script -ProjectDir $script:TmpProjectDir -IdTarea 'no-existe' | Out-Null

    $LASTEXITCODE | Should -Be 0
    Test-Path (Join-Path $script:TmpProjectDir '.bossdream-project') | Should -BeFalse
  }

  It 'tras consumir un artefacto, Get-OtherPlanningArtifacts ya no lo devuelve' {
    $script:TmpProjectDir = New-ProjectDirWithArtifact 'increment-otro'
    $antes = Get-OtherPlanningArtifacts -ProjectDir $script:TmpProjectDir -ExcludeIdTarea $null
    $antes.id_tarea | Should -Contain 'increment-otro'

    & $script:Script -ProjectDir $script:TmpProjectDir -IdTarea 'increment-otro' | Out-Null

    $despues = Get-OtherPlanningArtifacts -ProjectDir $script:TmpProjectDir -ExcludeIdTarea $null
    $despues.id_tarea | Should -Not -Contain 'increment-otro'
  }
}
